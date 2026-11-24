<#
  athena_run.ps1 — run a .sql file in Amazon Athena, one statement at a time.

  - Splits the file into statements on ';' (full-line "--" comments are removed
    first; don't put ';' inside string literals or inline comments).
  - Runs each statement with `aws athena start-query-execution` in the given
    workgroup, always passing the result location explicitly, so the
    workgroup's own settings are never changed.
  - Polls until each statement finishes and prints: state, engine runtime (ms),
    data scanned (bytes and MB), and the first rows of the result for SELECTs.
  - Appends one line per statement to scratch/athena_log.csv.
  - Stops on the first failed statement and shows the error.

  Requires valid AWS Learner Lab credentials (they expire with the lab session).
  Example (from the repo root):
    .\aws\athena_run.ps1 aws\athena\ddl\01_raw_csv.sql
#>
param(
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [string]$Workgroup = "primary",
    [string]$OutputLocation = "s3://bdf26-movielens-6339/athena-results/",
    [string]$Database = "",          # optional query context; the SQL files use qualified names
    [string]$Region = "us-east-1",
    [int]$MaxRows = 10,
    [string]$LogFile = ""
)

$env:AWS_PAGER = ""
$repo = Split-Path -Parent $PSScriptRoot
if (-not $LogFile) { $LogFile = Join-Path $repo "scratch\athena_log.csv" }

# Use `aws` from PATH, or the default install location if PATH isn't refreshed yet.
$aws = (Get-Command aws -ErrorAction SilentlyContinue).Source
if (-not $aws) { $aws = "C:\Program Files\Amazon\AWSCLIV2\aws.exe" }

function Hide-AccountId([string]$s) { [regex]::Replace($s, '(?<!\d)\d{8}(\d{4})(?!\d)', '****$1') }

# --- Read and split the file -------------------------------------------------
$sqlPath = (Resolve-Path $SqlFile).Path
$text = (Get-Content $sqlPath -Raw -Encoding UTF8)
$text = ($text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*--' }) -join "`n"
$statements = @($text -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$fileLabel = $sqlPath.Substring($repo.Length + 1) -replace '\\', '/'
Write-Host "$fileLabel : $($statements.Count) statement(s)"

# --- Log file ------------------------------------------------------------------
$logDir = Split-Path -Parent $LogFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
if (-not (Test-Path $LogFile)) {
    "timestamp,file,statement,sql_start,state,runtime_ms,bytes_scanned" | Out-File $LogFile -Encoding utf8
}
function Add-LogLine($n, $sql, $state, $ms, $bytes) {
    $snippet = (($sql -replace '\s+', ' ').Trim())
    if ($snippet.Length -gt 60) { $snippet = $snippet.Substring(0, 60) }
    $snippet = '"' + ($snippet -replace '"', '""') + '"'
    $ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    "$ts,$fileLabel,$n,$snippet,$state,$ms,$bytes" | Out-File $LogFile -Append -Encoding utf8
}

# The query text goes through a temp file (file://), so quotes in the SQL survive
# Windows PowerShell's argument passing to native programs.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("athena_" + [guid]::NewGuid().ToString("N") + ".sql")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    for ($i = 0; $i -lt $statements.Count; $i++) {
        $n = $i + 1
        $sql = $statements[$i]
        $first = ($sql -split "`n")[0]
        Write-Host ""
        Write-Host "[$n/$($statements.Count)] $first"

        [IO.File]::WriteAllText($tmp, $sql, $utf8NoBom)
        $startArgs = @("athena", "start-query-execution", "--region", $Region,
                       "--work-group", $Workgroup,
                       "--query-string", "file://$tmp",
                       "--result-configuration", "OutputLocation=$OutputLocation",
                       "--query", "QueryExecutionId", "--output", "text")
        if ($Database) { $startArgs += @("--query-execution-context", "Database=$Database") }
        $qid = & $aws @startArgs 2>&1 | ForEach-Object { "$_" } |
               Where-Object { $_ -and $_ -ne "System.Management.Automation.RemoteException" }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  start-query-execution failed:" -ForegroundColor Red
            Write-Host ("  " + (Hide-AccountId ($qid -join "`n")))
            Add-LogLine $n $sql "START_FAILED" "" ""
            exit 1
        }
        $qid = ($qid -join "").Trim()

        # Poll until the query leaves QUEUED / RUNNING.
        $delay = 0.5
        do {
            Start-Sleep -Milliseconds ([int]($delay * 1000))
            if ($delay -lt 3) { $delay = $delay * 1.5 }
            $json = & $aws athena get-query-execution --region $Region --query-execution-id $qid --output json
            $qe = ($json | Out-String | ConvertFrom-Json).QueryExecution
            $state = $qe.Status.State
        } while ($state -eq "QUEUED" -or $state -eq "RUNNING")

        $ms = $qe.Statistics.EngineExecutionTimeInMillis
        $bytes = $qe.Statistics.DataScannedInBytes
        if ($null -eq $bytes) { $bytes = 0 }
        $mb = [math]::Round($bytes / 1MB, 2)
        Write-Host ("  {0}  runtime {1} ms  scanned {2:N0} bytes ({3} MB)" -f $state, $ms, $bytes, $mb)
        Add-LogLine $n $sql $state $ms $bytes

        if ($state -ne "SUCCEEDED") {
            Write-Host ("  Error: " + (Hide-AccountId $qe.Status.StateChangeReason)) -ForegroundColor Red
            exit 1
        }

        # First rows for SELECT / WITH queries.
        if ($sql -match '^\s*(SELECT|WITH)\b') {
            $res = & $aws athena get-query-results --region $Region --query-execution-id $qid `
                     --max-items ($MaxRows + 1) --output json | Out-String | ConvertFrom-Json
            $rows = @($res.ResultSet.Rows)
            if ($rows.Count -lt 2) {
                Write-Host "  (no rows)"
            } else {
                $cols = @($rows[0].Data | ForEach-Object { $_.VarCharValue })
                $table = foreach ($r in $rows[1..($rows.Count - 1)]) {
                    $vals = @($r.Data | ForEach-Object { $_.VarCharValue })
                    $o = [ordered]@{}
                    for ($c = 0; $c -lt $cols.Count; $c++) { $o[$cols[$c]] = $vals[$c] }
                    [pscustomobject]$o
                }
                $table | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
            }
        }
    }
}
finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
}
Write-Host ""
Write-Host "Done: $($statements.Count) statement(s) succeeded. Log: $LogFile"
