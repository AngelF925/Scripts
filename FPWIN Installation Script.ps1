Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern IntPtr FindWindowEx(IntPtr hWndParent, IntPtr hWndChildAfter, string lpszClass, string lpszWindow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
}
"@


function Send-Enter {
    $VK_RETURN = 0x0D
    $KEYEVENTF_KEYUP = 0x0002
    [Win32]::keybd_event($VK_RETURN, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 100
    [Win32]::keybd_event($VK_RETURN, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function GetWindowHandleByTitleKeyword($keyword) {
    $windows = Get-Process | Where-Object {
        $_.MainWindowTitle -like "*$keyword*" -and $_.MainWindowHandle -ne 0
    }
    if ($windows.Count -gt 0) {
        return $windows[0].MainWindowHandle
    }
    return $null
}

function Get-WindowState {
    param (
        [Parameter(Mandatory = $true)]
        [IntPtr]$windowHandle
    )

    if (-not [Win32]::IsWindowEnabled($windowHandle)) {
        return "Disabled (Locked)"
    }
    return "Active"
}

function Wait-ForChildWindow {
    param (
        [string]$ParentWindowTitle,
        [string]$ChildWindowTitle,
        [int]$TimeoutInSeconds = 60
    )
    $elapsed = 0
    do {
        $parentHandle = GetWindowHandleByTitleKeyword $ParentWindowTitle
        if ($parentHandle) {
            $popupHandle = [Win32]::FindWindowEx($parentHandle, [IntPtr]::Zero, $null, $ChildWindowTitle)
            if ($popupHandle -ne [IntPtr]::Zero) {
                return $popupHandle
            }
        }
        Start-Sleep -Seconds 1
        $elapsed++
    } while ($elapsed -lt $TimeoutInSeconds)
    return $null
}

# Path to installer
$installerPath = "$env:USERPROFILE\Downloads\FPWIN_GR7_Setup.exe"

if (-Not (Test-Path $installerPath)) {
    Write-Host "❌ Installer not found at: $installerPath"
    exit 1
}

# Launch installer
Write-Host "🚀 Launching installer..."
Start-Process -FilePath $installerPath
Start-Sleep -Seconds 3

# Wait for first setup screen
Write-Host "⏳ Waiting for first setup screen..."
do {
    $firstHandle = GetWindowHandleByTitleKeyword "InstallShield"
    Start-Sleep -Seconds 1
} while (-not $firstHandle)

Write-Host "✅ First setup screen appeared."

# Wait for first setup screen to close
do {
    $firstHandle = GetWindowHandleByTitleKeyword "InstallShield"
    Start-Sleep -Seconds 1
} while ($firstHandle)

Write-Host "✅ First screen closed. Waiting for second screen..."

# Wait for second setup screen
do {
    $secondHandle = GetWindowHandleByTitleKeyword "InstallShield"
    Start-Sleep -Seconds 1
} while (-not $secondHandle)

Write-Host "✅ Second screen detected. Sending Enter..."
[Win32]::SetForegroundWindow($secondHandle)
Start-Sleep -Milliseconds 500
Send-Enter

# License agreement screen interaction
Write-Host "📝 Navigating to accept the license agreement..."
[System.Windows.Forms.SendKeys]::SendWait("{UP}")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 2

# Enter user info
Write-Host "🧑 Entering user information..."
[System.Windows.Forms.SendKeys]::SendWait("")
Start-Sleep -Seconds 3
[System.Windows.Forms.SendKeys]::SendWait("{TAB}")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("{TAB}")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("{TAB}")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 2

# Monitor if the main window gets locked by the popup and wait for it
function Wait-ForMainWindowState {
    param (
        [string]$WindowTitle,
        [string]$TargetState,
        [int]$TimeoutInSeconds = 60
    )
    $elapsed = 0
    do {
        $mainWindowHandle = GetWindowHandleByTitleKeyword $WindowTitle
        if ($mainWindowHandle) {
            $windowState = Get-WindowState -windowHandle $mainWindowHandle
            if ($windowState -eq $TargetState) {
                return $true
            }
        }
        Start-Sleep -Seconds 1
        $elapsed++
    } while ($elapsed -lt $TimeoutInSeconds)
    return $false
}

# Wait for the main window to be "Disabled (Locked)" before proceeding
Write-Host "⏳ Waiting for the main window to become locked or disabled..."
$windowLocked = Wait-ForMainWindowState -WindowTitle "InstallShield" -TargetState "Disabled (Locked)" -TimeoutInSeconds 120

if (-not $windowLocked) {
    Write-Host "❌ Timeout waiting for the main window to be locked or disabled."
    exit 1
}

Write-Host "✅ Main window is locked or disabled. Proceeding with final steps..."

# Final interaction after installation
Write-Host "✅ Completing the installation..."
[System.Windows.Forms.SendKeys]::SendWait("{TAB}")
Start-Sleep -Seconds 1
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 1
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 1

Write-Host "🎉 Installation completed successfully."
