# Claude Code sends JSON on stdin. Persist only quota fields and their observation time.
$data = [Console]::In.ReadToEnd() | ConvertFrom-Json
$windows = @{}
foreach ($mapping in @(@{field='five_hour'; key='300'}, @{field='seven_day'; key='10080'})) {
    $item = $data.rate_limits.($mapping.field)
    if ($null -ne $item.used_percentage) {
        $windows[$mapping.key] = @{ used = $item.used_percentage; reset = $item.resets_at }
    }
}
if ($windows.Count) {
    $directory = Join-Path $env:LOCALAPPDATA 'BODK-AI-Use'
    if (Test-Path (Join-Path $directory 'BODK-AI-Use.ps1')) {
        $target = Join-Path $directory 'claude.json'
        $temporary = Join-Path $directory ([Guid]::NewGuid().ToString() + '.tmp')
        try {
            @{ observed = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); windows = $windows } |
                ConvertTo-Json -Depth 5 -Compress | Set-Content -LiteralPath $temporary -Encoding UTF8
            for ($attempt=0; $attempt -lt 4; $attempt++) {
                try {
                    if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary, $target, $null) }
                    else { [IO.File]::Move($temporary, $target) }
                    break
                } catch [IO.IOException] { Start-Sleep -Milliseconds 40 }
            }
        } finally { Remove-Item -LiteralPath $temporary -ErrorAction SilentlyContinue }
    }
    $labels = @()
    if ($windows['300']) { $labels += ('5h {0:0}%' -f $windows['300'].used) }
    if ($windows['10080']) { $labels += ('7d {0:0}%' -f $windows['10080'].used) }
    'Claude | ' + ($labels -join '  ')
}
