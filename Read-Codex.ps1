$ErrorActionPreference = 'Stop'
$exe = Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$info = New-Object Diagnostics.ProcessStartInfo
if ($exe) {
    $info.FileName = $exe.Source
    $info.Arguments = 'app-server'
} elseif (Get-Command codex.cmd -CommandType Application -ErrorAction SilentlyContinue) {
    $info.FileName = $env:ComSpec
    $info.Arguments = '/d /c codex.cmd app-server'
} else {
    throw 'Codex CLI mangler i PATH.'
}
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardInput = $true
$info.RedirectStandardOutput = $true
$process = [Diagnostics.Process]::Start($info)
$deadline = [DateTime]::UtcNow.AddSeconds(18)
function Receive-Response($id) {
    while ([DateTime]::UtcNow -lt $deadline) {
        $line = $process.StandardOutput.ReadLineAsync()
        $remaining = [Math]::Max(1, [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds)
        if (!$line.Wait($remaining) -or $null -eq $line.Result) { break }
        try { $message = ConvertFrom-Json -InputObject $line.Result } catch { continue }
        if ($message.id -eq $id) {
            if ($message.error) { throw 'Codex kunne ikke hente kvoter. Kontrollér login.' }
            return $message.result
        }
    }
    throw 'Codex svarede ikke i tide.'
}
try {
    $process.StandardInput.WriteLine('{"id":1,"method":"initialize","params":{"clientInfo":{"name":"bodk-ai-use","title":"BODK-AI-Use","version":"1.0.0"}}}')
    $null = Receive-Response 1
    $process.StandardInput.WriteLine('{"method":"initialized"}')
    $process.StandardInput.WriteLine('{"id":2,"method":"account/rateLimits/read"}')
    $result = Receive-Response 2
    $bucket = $result.rateLimitsByLimitId.codex
    if (!$bucket -and (!$result.rateLimits.limitId -or $result.rateLimits.limitId -eq 'codex')) {
        $bucket = $result.rateLimits
    }
    $windows = @{}
    foreach ($item in @($bucket.primary, $bucket.secondary)) {
        if ($item.windowDurationMins -in 300,10080 -and $null -ne $item.usedPercent) {
            $windows[[string]$item.windowDurationMins] = @{ used = $item.usedPercent; reset = $item.resetsAt }
        }
    }
    if (!$windows.Count) { throw 'Kontoen returnerede ingen 5t- eller ugekvote.' }
    $windows
} finally {
    $process.StandardInput.Close()
    if (!$process.WaitForExit(1000)) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>$null | Out-Null
    }
    $process.Dispose()
}
