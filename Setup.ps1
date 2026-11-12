param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'BODK-AI-Use'
$startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'BODK-AI-Use.lnk'
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'BODK-AI-Use.lnk'
$registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\BODK-AI-Use'
$powershell = Join-Path $PSHOME 'powershell.exe'
$widget = Join-Path $root 'BODK-AI-Use.ps1'
$launch = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $widget + '"'
$stop = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, 'Local\BODK-AI-UseStop')
$mutex = New-Object Threading.Mutex($false, 'Local\BODK-AI-Use')
$locked = $false
$installed = $false
try {
    $null = $stop.Set()
    try { $locked = $mutex.WaitOne(30000) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (!$locked) { throw 'Luk BODK-AI-Use via proceslinjen, og prøv igen.' }
    if ($Uninstall) {
        Remove-Item -LiteralPath $startup,$startMenu -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $registry -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        Write-Host 'BODK-AI-Use er afinstalleret.'
    } else {
        $null = New-Item -Path $root -ItemType Directory -Force
        foreach ($file in 'BODK-AI-Use.ps1','Read-Codex.ps1','ClaudeStatus.ps1','Setup.ps1') {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $root -Force
        }
        $shell = New-Object -ComObject WScript.Shell
        foreach ($path in $startup,$startMenu) {
            $shortcut = $shell.CreateShortcut($path)
            $shortcut.TargetPath = $powershell
            $shortcut.Arguments = $launch
            $shortcut.WorkingDirectory = $root
            $shortcut.Save()
        }
        $null = New-Item -Path $registry -Force
        $properties = @{
            DisplayName = 'BODK-AI-Use'
            DisplayVersion = '2.2.0'
            InstallLocation = $root
            UninstallString = ('"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -Uninstall' -f $powershell,(Join-Path $root 'Setup.ps1'))
        }
        foreach ($key in $properties.Keys) { Set-ItemProperty -Path $registry -Name $key -Value $properties[$key] }
        $installed = $true
    }
} finally {
    $null = $stop.Reset()
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
    $stop.Dispose()
}
if ($installed) {
    Start-Process -FilePath $powershell -ArgumentList $launch -WorkingDirectory $root -WindowStyle Hidden
    Write-Host 'BODK-AI-Use er installeret. Tallene vises direkte oven på proceslinjen. Højreklik for indstillinger.'
}
