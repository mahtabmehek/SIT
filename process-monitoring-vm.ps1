# PowerShell Script: vm-transcode-monitor.ps1

# --- CONFIGURATION ---
$vmName = "vm-env-ubuntu"
$vmIp = "10.128.140.13"
$vmUser = "mahtab"
$sshKeyPath = "$env:USERPROFILE\.ssh\vm-sit"
$remoteScript = "~/SIT/transcode_runner.sh"
$logFolder = "$PSScriptRoot\vm-logs"
$logFile = "$logFolder\vm-process.log"

# --- CLEANUP PREVIOUS LOGS ---
if (Test-Path $logFolder) {
    Remove-Item "$logFolder\*" -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# --- TIMING SETUP ---
$videos = @("complex_kaleidoscope_1080p", "simple_lake_1080p")
$bitrates = @(1024, 2048)

$cpuLog   = "$logFolder\cpu.csv"
$memLog   = "$logFolder\mem.csv"
$diskLog  = "$logFolder\disk.csv"
$vmStartMarker = "$logFolder\process_vm_start.marker"
$vmStopMarker  = "$logFolder\process_vm_stop.marker"

# --- MONITORING ---
Write-Host "[+] Starting system monitoring on HOST..."

Start-Process -FilePath "typeperf.exe" -ArgumentList '"\Processor(_Total)\% Processor Time"', "-si", "1", "-f", "CSV", "-o", "$cpuLog" -WindowStyle Hidden
Start-Process -FilePath "typeperf.exe" -ArgumentList '"\Memory\Available MBytes"', "-si", "1", "-f", "CSV", "-o", "$memLog" -WindowStyle Hidden
Start-Process -FilePath "typeperf.exe" -ArgumentList '"\LogicalDisk(_Total)\Disk Write Bytes/sec"', "-si", "1", "-f", "CSV", "-o", "$diskLog" -WindowStyle Hidden


Write-Host "[✓] Monitoring started. Waiting 5 seconds for baseline..."
Start-Sleep -Seconds 5

# --- START VM ---
(Get-Date).ToString('o') | Out-File $vmStartMarker
Write-Host "[+] Starting VM using VBoxManage..."
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm $vmName --type headless
Start-Sleep -Seconds 20
Start-Sleep -Seconds 5

# --- TRANSCODING ---
foreach ($bitrate in $bitrates) {
    foreach ($video in $videos) {
        $safeVideo = $video.Replace("_1080p", "")
        $startMarker = "$logFolder\${bitrate}_${safeVideo}_start.marker"
        $endMarker   = "$logFolder\${bitrate}_${safeVideo}_end.marker"

        (Get-Date).ToString('o') | Out-File $startMarker
        Write-Host "[+] Transcoding $video at ${bitrate} Mbps..."
        ssh -i $sshKeyPath "$vmUser@$vmIp" "cd CSI_6_SIT && bash $remoteScript $bitrate $video" *>> $logFile
        (Get-Date).ToString('o') | Out-File $endMarker

        Start-Sleep -Seconds 5
    }
}

# --- SHUTDOWN VM ---
Write-Host "[✓] Transcoding complete. Shutting down VM..."
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm $vmName acpipowerbutton
Start-Sleep -Seconds 10
(Get-Date).ToString('o') | Out-File $vmStopMarker

# --- FINALIZE ---
Write-Host "[✓] Capturing 5s post-monitoring..."
Start-Sleep -Seconds 5
Write-Host "[✓] Stopping monitoring processes..."
Get-Process typeperf | Stop-Process -Force

Write-Host "Logs and markers saved in $logFolder"

# --- PLOT ---
Write-Host "[+] Generating plots..."
python "$PSScriptRoot\plot.py" --prefix "vm"
