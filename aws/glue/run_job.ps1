<#
  run_job.ps1 - deploy and run the Glue ETL job bdf26-movielens-curate.

  1. Uploads aws/glue/movielens_curate.py to s3://<bucket>/scripts/glue/.
  2. Creates the Glue job if it doesn't exist, otherwise updates it:
     role LabRole, Glue 5.0 (falls back to 4.0 if 5.0 is refused), G.1X x 2
     workers, 30-minute timeout, temp dir s3://<bucket>/glue-temp/.
  3. Starts a run, polls until it finishes, and prints state, execution time,
     DPU-seconds and an estimated cost at $0.44 per DPU-hour.
  4. On failure, prints the run's ErrorMessage.

  Requires valid AWS Learner Lab credentials (they expire with the lab session).
  Run from the repo root:  .\aws\glue\run_job.ps1
#>
param(
    [string]$Bucket = "bdf26-movielens-6339",
    [string]$JobName = "bdf26-movielens-curate",
    [string]$Role = "LabRole",
    [string]$Region = "us-east-1",
    [string]$GlueVersion = "5.0",
    [int]$Workers = 2,
    [string]$WorkerType = "G.1X",
    [int]$TimeoutMinutes = 30,
    [double]$PricePerDpuHour = 0.44
)

$env:AWS_PAGER = ""
$aws = (Get-Command aws -ErrorAction SilentlyContinue).Source
if (-not $aws) { $aws = "C:\Program Files\Amazon\AWSCLIV2\aws.exe" }
$script = Join-Path $PSScriptRoot "movielens_curate.py"
$scriptS3 = "s3://$Bucket/scripts/glue/movielens_curate.py"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Hide-AccountId([string]$s) { [regex]::Replace($s, '(?<!\d)\d{8}(\d{4})(?!\d)', '****$1') }
function Invoke-Aws {
    # Runs aws, returns @{ Code; Out } with stderr merged and PowerShell noise removed.
    $out = & $aws @args 2>&1 | ForEach-Object { "$_" } |
           Where-Object { $_ -and $_ -ne "System.Management.Automation.RemoteException" }
    @{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}
function Write-JsonFile($obj) {
    $f = Join-Path ([IO.Path]::GetTempPath()) ("glue_" + [guid]::NewGuid().ToString("N") + ".json")
    [IO.File]::WriteAllText($f, ($obj | ConvertTo-Json -Depth 5), $utf8NoBom)
    $f
}

# --- 1. Upload the script -------------------------------------------------------
Write-Host "Uploading script to $scriptS3"
$r = Invoke-Aws s3 cp $script $scriptS3 --region $Region --only-show-errors
if ($r.Code -ne 0) { Write-Host (Hide-AccountId $r.Out) -ForegroundColor Red; exit 1 }

# --- 2. Create or update the job -------------------------------------------------
function Get-JobSpec([string]$version) {
    [ordered]@{
        Role              = $Role
        Command           = [ordered]@{ Name = "glueetl"; ScriptLocation = $scriptS3; PythonVersion = "3" }
        DefaultArguments  = [ordered]@{
            "--BUCKET"                  = $Bucket
            "--TempDir"                 = "s3://$Bucket/glue-temp/"
            "--job-language"            = "python"
            "--enable-metrics"          = "true"
            "--enable-continuous-cloudwatch-log" = "true"
        }
        GlueVersion       = $version
        WorkerType        = $WorkerType
        NumberOfWorkers   = $Workers
        Timeout           = $TimeoutMinutes
        MaxRetries        = 0
    }
}

$exists = (Invoke-Aws glue get-job --job-name $JobName --region $Region --query Job.Name --output text).Code -eq 0
$versions = @($GlueVersion)
if ($GlueVersion -ne "4.0") { $versions += "4.0" }
$usedVersion = $null
foreach ($v in $versions) {
    $spec = Get-JobSpec $v
    if ($exists) {
        $f = Write-JsonFile $spec
        $r = Invoke-Aws glue update-job --job-name $JobName --job-update "file://$f" --region $Region
    } else {
        $full = [ordered]@{ Name = $JobName }
        foreach ($k in $spec.Keys) { $full[$k] = $spec[$k] }
        $f = Write-JsonFile $full
        $r = Invoke-Aws glue create-job --cli-input-json "file://$f" --region $Region
    }
    Remove-Item $f -Force
    if ($r.Code -eq 0) { $usedVersion = $v; break }
    Write-Host ("Glue $v refused: " + (Hide-AccountId $r.Out)) -ForegroundColor Yellow
    if ($r.Out -notmatch '(?i)version') { break }   # not a version problem, don't retry
}
if (-not $usedVersion) { Write-Host "Could not create/update job $JobName." -ForegroundColor Red; exit 1 }
Write-Host ("Job {0} {1} (Glue {2}, {3} x {4}, timeout {5} min)" -f $JobName, $(if ($exists) { "updated" } else { "created" }), $usedVersion, $Workers, $WorkerType, $TimeoutMinutes)

# --- 3. Start and poll ---------------------------------------------------------
$r = Invoke-Aws glue start-job-run --job-name $JobName --region $Region --query JobRunId --output text
if ($r.Code -ne 0) { Write-Host (Hide-AccountId $r.Out) -ForegroundColor Red; exit 1 }
$runId = $r.Out.Trim()
Write-Host "Started run $runId"

$t0 = Get-Date
$last = ""
do {
    Start-Sleep -Seconds 15
    $r = Invoke-Aws glue get-job-run --job-name $JobName --run-id $runId --region $Region --output json
    if ($r.Code -ne 0) { Write-Host (Hide-AccountId $r.Out) -ForegroundColor Red; exit 1 }
    $run = ($r.Out | ConvertFrom-Json).JobRun
    $state = $run.JobRunState
    if ($state -ne $last) {
        Write-Host ("  {0,6:N0} s  {1}" -f ((Get-Date) - $t0).TotalSeconds, $state)
        $last = $state
    }
} while ($state -in @("STARTING", "RUNNING", "STOPPING", "WAITING"))

# --- 4. Report -------------------------------------------------------------------
$execS = [int]$run.ExecutionTime
$dpuPerWorker = @{ "G.025X" = 0.25; "G.1X" = 1; "G.2X" = 2; "G.4X" = 4; "G.8X" = 8 }[$WorkerType]
if ($run.DPUSeconds) {
    $dpuS = [double]$run.DPUSeconds; $dpuNote = "reported by Glue"
} else {
    # Standard runs don't report DPUSeconds: workers x DPU per worker x execution time,
    # with Glue's 1-minute minimum.
    $dpuS = [math]::Max($execS, 60) * $Workers * $dpuPerWorker; $dpuNote = "estimated: $Workers workers x $dpuPerWorker DPU x max(ExecutionTime, 60 s)"
}
$cost = $dpuS / 3600 * $PricePerDpuHour
Write-Host ""
Write-Host "State:          $state"
Write-Host "Glue version:   $($run.GlueVersion)"
Write-Host "ExecutionTime:  $execS s"
Write-Host ("DPU-seconds:    {0:N0} ({1})" -f $dpuS, $dpuNote)
Write-Host ("Estimated cost: `${0:N4} at `${1}/DPU-hour" -f $cost, $PricePerDpuHour)
Write-Host "Run id:         $runId"
if ($state -ne "SUCCEEDED") {
    Write-Host ("ErrorMessage:   " + (Hide-AccountId $run.ErrorMessage)) -ForegroundColor Red
    exit 1
}
