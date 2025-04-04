# PowerShell Script: docker-transcode-monitor.ps1

# --- CONFIGURATION ---
$containerName = "docker-env-ubuntu"
$logFolder = "$PSScriptRoot\docker-logs"
$logFile = "$logFolder\docker-process.log"
$transcodeScriptPath = "/home/mahtab/CW/transcode-main.sh"

# --- CLEANUP PREVIOUS LOGS ---
if (Test-Path $logFolder) {
    Remove-Item "$logFolder\*" -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# --- LOG FILENAMES (fixed names) ---
$cpuLog   = "$logFolder\cpu.csv"
$memLog   = "$logFolder\mem.csv"
$diskLog  = "$logFolder\disk.csv"
$dockerStartMarker = "$logFolder\process_docker_start.marker"
$dockerStopMarker  = "$logFolder\process_docker_stop.marker"

# --- MONITORING ---
Write-Host "[+] Starting system monitoring on HOST..."

Start-Process -FilePath "typeperf.exe" -ArgumentList '"\Processor(_Total)\% Processor Time"', "-si", "1", "-f", "CSV", "-o", "$cpuLog" -WindowStyle Hidden
Start-Process -FilePath "typeperf.exe" -ArgumentList '"\Memory\Available MBytes"', "-si", "1", "-f", "CSV", "-o", "$memLog" -WindowStyle Hidden
Start-Process -FilePath "typeperf.exe" -ArgumentList '"\LogicalDisk(_Total)\Disk Write Bytes/sec"', "-si", "1", "-f", "CSV", "-o", "$diskLog" -WindowStyle Hidden


Write-Host "[✓] Monitoring started. Waiting 5 seconds for baseline..."
Start-Sleep -Seconds 5

# --- RECORD DOCKER START MARKER ---
(Get-Date).ToString('o') | Out-File $dockerStartMarker
Write-Host "[+] Starting Docker container..."
docker start $containerName | Out-Null
Start-Sleep -Seconds 5

# --- TRANSCODING ---
$bitrates = @(1024, 2048)
$videos = @("complex_kaleidoscope_1080p", "simple_lake_1080p")

foreach ($bitrate in $bitrates) {
    foreach ($video in $videos) {
        $safeVideo = $video.Replace("_1080p", "")
        $startMarker = "$logFolder\${bitrate}_${safeVideo}_start.marker"
        $endMarker   = "$logFolder\${bitrate}_${safeVideo}_end.marker"

        (Get-Date).ToString('o') | Out-File $startMarker
        Write-Host "[+] Transcoding $video at ${bitrate} Mbps..."
        docker exec -u mahtab $containerName bash $transcodeScriptPath $bitrate $video *>> $logFile
        (Get-Date).ToString('o') | Out-File $endMarker

        Start-Sleep -Seconds 5
    }
}

# --- STOP DOCKER ---
Write-Host "[✓] Transcoding complete. Stopping Docker container..."
docker stop $containerName | Out-Null
(Get-Date).ToString('o') | Out-File $dockerStopMarker

Write-Host "[✓] Capturing 5s post-monitoring..."
Start-Sleep -Seconds 5

Write-Host "[✓] Stopping monitoring processes..."
Get-Process typeperf | Stop-Process -Force

Write-Host "✅ Logs and markers saved in $logFolder"

# --- PLOT ---
Write-Host "[+] Generating plots..."
python "$PSScriptRoot\plot.py" --prefix "docker"

Write-Host "📊 Plots saved to $PSScriptRoot\docker-plots"
