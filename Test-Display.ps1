$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'BODK-AI-Use.ps1'
$source = [IO.File]::ReadAllText($path)
$source = $source.Replace('Local\BODK-AI-Use', ('Local\BODK-AI-Use-Test-' + $PID))
$source = $source.Replace('$root = $PSScriptRoot', ('$root = ''' + $PSScriptRoot.Replace("'","''") + ''''))
$source = $source.Replace('[Windows.Forms.Application]::Run($form)', @'
if ($form.ShowInTaskbar -or $form.FormBorderStyle -ne 'None') { throw 'Not a borderless overlay' }
if ($form.Width -ne 286 -or $form.Height -ne 40) { throw 'Wrong compact size' }
if ($script:icons['Codex-300'].label.Text -ne '84%') { throw 'Codex demo mismatch' }
if ($script:icons['Claude-10080'].label.Text -ne '58%') { throw 'Claude demo mismatch' }
$config.remaining=$true; Update-Icons
if ($script:icons['Claude-300'].label.Text -ne '3%') { throw 'Remaining mismatch' }
$config.provider='Claude'; Update-Icons
if ($cards['Claude'].Top -ne 0) { throw 'Provider placement mismatch' }
$config.light=$true; Update-Icons
if ($form.ForeColor.R -ne 30) { throw 'Theme mismatch' }
foreach ($card in $cards.Values) {
    foreach ($child in $card.Controls) {
        if ($child.Right -gt 286 -or $child.Bottom -gt 20) { throw 'Content outside row' }
    }
}
Write-Output 'PASS: compact geometry, demo values, remaining quota, provider switch, light theme'
'@)
# No window is shown and no settings or installation files are changed.
& ([scriptblock]::Create($source)) -Demo
