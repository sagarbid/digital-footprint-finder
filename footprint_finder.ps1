# Digital Footprint Finder: Sherlock + HIBP + baseline diff -> Splunk-ready JSON
# Runs from the folder it lives in; target lists and logs stay next to the script.
$BaseDir      = $PSScriptRoot
$RawDir       = "$BaseDir\raw_scans"
$BaselineFile = "$BaseDir\baseline_urls.txt"
$SplunkLog    = "$BaseDir\splunk_exposures.json"
$TargetsFile  = "$BaseDir\targets.txt"
$EmailsFile   = "$BaseDir\emails.txt"

New-Item -ItemType Directory -Force -Path $RawDir | Out-Null
if (-not (Test-Path $BaselineFile)) { New-Item -ItemType File -Path $BaselineFile | Out-Null }
if (-not (Test-Path $SplunkLog))    { New-Item -ItemType File -Path $SplunkLog | Out-Null }

$Timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$DateStamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$CurrentHits = @()

Write-Host "[*] Starting Windows OSINT & HIBP Breach scan at $Timestamp..." -ForegroundColor Cyan

# 1. Username OSINT (Sherlock)
if (Test-Path $TargetsFile) {
    $Handles = Get-Content $TargetsFile | Where-Object { $_.Trim() -ne "" -and -not $_.StartsWith("#") }
    foreach ($Handle in $Handles) {
        $Handle = $Handle.Trim()
        Write-Host "[*] Scanning username handle: $Handle" -ForegroundColor Yellow
        $RawOut = "$RawDir\${Handle}_${DateStamp}.txt"
        python.exe -m sherlock_project $Handle --print-found --timeout 10 --output $RawOut 2>$null
        if (Test-Path $RawOut) {
            $Urls = Select-String -Path $RawOut -Pattern 'https?://[^\s"<>]+' -AllMatches |
                    ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }
            $CurrentHits += $Urls
        }
    }
}

# 2. HIBP Breach Check (Paid API Key)
$HibpKey = [System.Environment]::GetEnvironmentVariable("HIBP_API_Key", "User")
if (-not $HibpKey) {
    Write-Host "[!] Warning: HIBP_API_Key environment variable not found. Skipping breach check." -ForegroundColor Red
} elseif (Test-Path $EmailsFile) {
    $Emails = Get-Content $EmailsFile | Where-Object { $_.Trim() -ne "" -and -not $_.StartsWith("#") }
    foreach ($Email in $Emails) {
        $Email = $Email.Trim()
        Write-Host "[*] Querying HIBP breach data for: $Email" -ForegroundColor Yellow
        
        $Headers = @{
            "hibp-api-key" = $HibpKey
            "User-Agent"   = "digital-footprint-finder"
        }
        
        try {
            $Uri = "https://haveibeenpwned.com/api/v3/breachedaccount/$([uri]::EscapeDataString($Email))?truncateResponse=false"
            $Breaches = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get -ErrorAction Stop
            
            foreach ($Breach in $Breaches) {
                $BreachName = $Breach.Name
                $BreachDate = $Breach.AddedDate
                $CurrentHits += "hibp://breach/$Email/$BreachName"
            }
        } catch {
            $Code = [int]$_.Exception.Response.StatusCode
            if ($Code -eq 404) {
                Write-Host "    [+] No breaches found for $Email" -ForegroundColor Green
            } elseif ($Code -eq 429) {
                Write-Host "    [!] HIBP rate limit hit for $Email. Wait and re-run." -ForegroundColor Red
            } else {
                Write-Host "    [!] HIBP API Error for $Email : $_" -ForegroundColor Red
            }
        }
        Start-Sleep -Milliseconds 1700   # stay under the HIBP rate limit
    }
}

# 3. Diff engine against baseline
$KnownUrls    = Get-Content $BaselineFile | Where-Object { $_.Trim() -ne "" }
$FoundUrls    = $CurrentHits | Select-Object -Unique
$NewExposures = $FoundUrls | Where-Object { $_ -notin $KnownUrls }

if (-not $NewExposures -or $NewExposures.Count -eq 0) {
    Write-Host "[+] No new exposures or breaches found since last scan." -ForegroundColor Green
} else {
    Write-Host "[!] Found $($NewExposures.Count) NEW exposures/breaches! Logging to $SplunkLog" -ForegroundColor Red
    foreach ($Item in $NewExposures) {
        $EventObj = [ordered]@{
            timestamp       = $Timestamp
            host            = $env:COMPUTERNAME
            event_type      = "new_footprint_exposure"
            status          = "Found"
            source          = $(if ($Item -like "hibp://*") { "HaveIBeenPwned" } else { "Sherlock" })
            indicator       = $Item
            action_required = "Review / Remediate / Opt-Out"
        }
        ($EventObj | ConvertTo-Json -Compress) | Add-Content -Path $SplunkLog -Encoding UTF8
        $Item | Add-Content -Path $BaselineFile -Encoding UTF8
        Write-Host "    -> $Item" -ForegroundColor Gray
    }
}

Write-Host "[*] Scan complete. Log: $SplunkLog" -ForegroundColor Cyan
