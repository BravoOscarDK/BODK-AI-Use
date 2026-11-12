$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'BODK-AI-Use.ps1'
$source = [IO.File]::ReadAllText($path)
$source = $source.Replace('Local\BODK-AI-Use', ('Local\BODK-AI-Use-Test-' + $PID))
$source = $source.Replace('$root = $PSScriptRoot', ('$root = ''' + $PSScriptRoot.Replace("'","''") + ''''))
$source = $source.Replace('[Windows.Forms.Application]::Run($form)', @'
if ($form.ShowInTaskbar -or $form.FormBorderStyle -ne 'None') { throw 'Not a borderless overlay' }
if ($menu.Items[$menu.Items.Count-1] -ne $exitItem -or $menu.Items.IndexOf($languageMenu) -ge $menu.Items.IndexOf($exitItem)) { throw 'Exit must be last, below language settings' }
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
$config.language='en'; Update-Icons
if ($providerMenu.Text -ne 'Provider' -or $exitItem.Text -ne 'Exit') { throw 'English menu mismatch' }
if ($cards['Claude'].Controls[2].Text -ne '5h' -or $cards['Claude'].Controls[4].Text -ne 'Week') { throw 'English period mismatch' }
if ($providerMenu.DropDownItems[2].Text -ne 'Both' -or $providerMenu.DropDownItems[2].Tag -ne 'Begge') { throw 'Provider identity was translated' }
$testSettings=Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString()+'.json')
$settingsFile=$testSettings
try {
    $providerMenu.DropDownItems[2].PerformClick()
    if ($config.provider -ne 'Begge') { throw 'English provider selection failed' }
    $savedSettings=Get-Content -LiteralPath $testSettings -Raw | ConvertFrom-Json
    if ($savedSettings.language -ne 'en' -or $savedSettings.provider -ne 'Begge') { throw 'Language persistence failed' }
    $languageMenu.DropDownItems[0].PerformClick()
    if ($providerMenu.Text -ne 'Udbyder' -or $cards['Claude'].Controls[4].Text -ne 'Uge') { throw 'Danish switch failed' }
} finally { Remove-Item -LiteralPath $testSettings -ErrorAction SilentlyContinue }
Write-Output 'PASS: layout, values, theme, Danish/English menus and periods, provider selection, saved language'
'@)
# No window is shown and no settings or installation files are changed.
& ([scriptblock]::Create($source)) -Demo
