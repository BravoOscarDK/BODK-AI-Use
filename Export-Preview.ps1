$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'BODK-AI-Use.ps1'))
$source = $source.Replace('Local\BODK-AI-Use', ('Local\BODK-AI-Use-Preview-' + $PID))
$source = $source.Replace('$root = $PSScriptRoot', ('$root = ''' + $PSScriptRoot.Replace("'","''") + ''''))
$source = $source.Replace('[Windows.Forms.Application]::Run($form)', @'
$directory=Join-Path $root 'docs'
$null=New-Item -ItemType Directory -Path $directory -Force
$config.provider='Begge'
foreach ($theme in 'dark','light') {
    $config.light=($theme -eq 'light')
    $config.remaining=$false
    Update-Icons
    $bitmap=New-Object Drawing.Bitmap(286,40)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $index=0
        foreach ($provider in 'Codex','Claude') {
            $card=$cards[$provider]
            $card.ForeColor=$form.ForeColor
            # A detached panel renders its real controls without showing a window.
            $form.Controls.Remove($card)
            $card.Visible=$true
            $row=New-Object Drawing.Bitmap(286,20)
            try {
                $card.DrawToBitmap($row,[Drawing.Rectangle]::new(0,0,286,20))
                $graphics.DrawImageUnscaled($row,0,20*$index)
            } finally { $row.Dispose() }
            $index++
        }
        $bitmap.Save((Join-Path $directory ("preview-$theme.png")),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
Write-Output 'Exported real widget controls with demo values to docs/preview-*.png'
'@)
& ([scriptblock]::Create($source)) -Demo
