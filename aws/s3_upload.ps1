<#
  s3_upload.ps1 — Step 2: S3 storage layout (raw zone)

  Creates the project bucket in us-east-1 if it does not exist (Block Public
  Access stays on, the default), then uploads the MovieLens CSV and Parquet
  files, each into its own folder, because Athena tables point at folders:

    data/csv/<table>.csv         -> s3://<bucket>/raw/csv/<table>/<table>.csv
    data/parquet/<table>.parquet -> s3://<bucket>/raw/parquet/<table>/<table>.parquet

  Each upload is timed separately and printed as: table, format, local MB, seconds.

  Requires valid AWS Learner Lab credentials (they expire with the lab session).
  Run from the repo root:  .\aws\s3_upload.ps1
#>

param(
    [string]$Bucket = "bdf26-movielens-6339",
    [string]$Region = "us-east-1"
)

# No global "Stop": in Windows PowerShell 5.1 it turns harmless aws stderr
# (e.g. head-bucket's 404) into terminating errors. Exit codes are checked instead.
$env:AWS_PAGER = ""
$tables  = @("ratings", "movies", "tags", "links", "wilhelmscreamdb-2026-11-06")
$repo    = Split-Path -Parent $PSScriptRoot

# 1. Bucket: create only if it does not exist yet.
& aws s3api head-bucket --bucket $Bucket --region $Region 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Bucket $Bucket already exists, reusing it."
} else {
    Write-Host "Creating bucket $Bucket in $Region ..."
    & aws s3api create-bucket --bucket $Bucket --region $Region --output text --query Location | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "create-bucket failed for $Bucket" }
}

# 2. Uploads, one timed call per file.
$results = @()
foreach ($format in @("csv", "parquet")) {
    foreach ($t in $tables) {
        $local = Join-Path $repo "data\$format\$t.$format"
        if (-not (Test-Path $local)) { throw "Missing local file: $local" }
        $mb  = (Get-Item $local).Length / 1MB
        $dst = "s3://$Bucket/raw/$format/$t/$t.$format"

        $script:code = 0
        $elapsed = Measure-Command {
            & aws s3 cp $local $dst --region $Region --only-show-errors
            $script:code = $LASTEXITCODE
        }
        if ($script:code -ne 0) { throw "Upload failed: $local -> $dst" }

        $row = [pscustomobject]@{
            Table   = $t
            Format  = $format
            LocalMB = [math]::Round($mb, 2)
            Seconds = [math]::Round($elapsed.TotalSeconds, 1)
        }
        $results += $row
        Write-Host ("{0,-8} {1,-8} {2,9:N2} MB {3,8:N1} s" -f $row.Table, $row.Format, $row.LocalMB, $row.Seconds)
    }
}

$total = ($results | Measure-Object Seconds -Sum).Sum
Write-Host ("Total upload time: {0:N1} s" -f $total)
