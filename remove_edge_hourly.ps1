# Edge Removal Scheduled Task Script
# Requires Administrator privileges

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please run as Administrator."
    exit
}

$taskName = "RemoveEdgeHourly"

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "Scheduled task '$taskName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Do you want to remove it? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Task '$taskName' has been removed." -ForegroundColor Green
        exit
    } else {
        Write-Host "Operation cancelled. The existing task will remain." -ForegroundColor Cyan
        exit
    }
}

# The command that will run every hour
$command = @'
# Kill parent processes that spawn WebView2
Get-Process -Name "SearchHost" -ErrorAction SilentlyContinue | Stop-Process -Force

# Kill Edge and WebView2 processes
Get-Process -Name "msedge","msedgewebview2","MicrosoftEdge*" -ErrorAction SilentlyContinue | Stop-Process -Force

# Wait for processes to terminate
Start-Sleep -Seconds 2

# Delete Edge directories
$paths = @(
    "C:\Program Files (x86)\Microsoft\Edge",
    "C:\Program Files (x86)\Microsoft\EdgeCore",
    "C:\Program Files (x86)\Microsoft\EdgeUpdate",
    "C:\Program Files (x86)\Microsoft\EdgeWebView",
    "C:\Program Files (x86)\Microsoft\EdgeWebView\Application",
    "C:\Program Files\Microsoft\Edge",
    "C:\Program Files\Microsoft\EdgeCore",
    "C:\Program Files\Microsoft\EdgeUpdate",
    "C:\Program Files\Microsoft\EdgeWebView",
    "C:\Program Files\Microsoft\EdgeWebView\Application"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
'@

$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

# Create the scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encodedCommand"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# Register the task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Removes Microsoft Edge and WebView2 every hour"

Write-Host "Scheduled task '$taskName' created successfully!" -ForegroundColor Green
Write-Host "The task will run every hour starting immediately." -ForegroundColor Cyan
Write-Host ""
Write-Host "To trigger it now for testing:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
Write-Host ""
Write-Host "To remove this task later:" -ForegroundColor Yellow
Write-Host "  Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false" -ForegroundColor White
