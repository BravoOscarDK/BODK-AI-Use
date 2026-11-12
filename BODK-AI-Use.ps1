param([switch]$Demo, [switch]$Preview)
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
# Non-activating overlay; Explorer and its layout remain untouched.
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class BodkTaskbarForm : Form {
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get { var p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x80; return p; }
    }
}
public static class BodkTaskbar {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr w, System.Text.StringBuilder name, int length);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr w, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
'@
$mutex = New-Object Threading.Mutex($false, 'Local\BODK-AI-Use')
$locked = $false
try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
if (!$locked) { $mutex.Dispose(); return }
$stop = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, 'Local\BODK-AI-UseStop')
$root = $PSScriptRoot
$settingsFile = Join-Path $root 'settings.json'
$intervals = @(30,60,120,300,600,900,1800)
$config = [pscustomobject]@{ seconds=60; remaining=$false; light=$false; provider='Begge'; offset=0; language=$(if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'da') { 'da' } else { 'en' }) }
try {
    $saved = Get-Content -LiteralPath $settingsFile -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($saved.language -in 'da','en') { $config.language = $saved.language }
    if ($saved.seconds -in $intervals) { $config.seconds = [int]$saved.seconds }
    if ($saved.provider -in 'Codex','Claude','Begge') { $config.provider = $saved.provider }
    if ($null -ne $saved.offset) { $config.offset = [Math]::Max(0,[Math]::Min(10000,[int]$saved.offset)) }
    $config.remaining = $saved.remaining -eq $true
    $config.light = $saved.light -eq $true
} catch {}
$english = @{
    'Opdatér nu' = 'Refresh now'
    'Vis resterende' = 'Show remaining'
    'Lyst tema' = 'Light theme'
    'Demotilstand' = 'Demo mode'
    'Udbyder' = 'Provider'
    'Begge' = 'Both'
    'Opdateringsinterval' = 'Refresh interval'
    'Afslut' = 'Exit'
    'Nulstil placering' = 'Reset position'
    'Sprog' = 'Language'
    'Venter på Codex' = 'Waiting for Codex'
    'Venter på Claude Code' = 'Waiting for Claude Code'
    'Kvotedata utilgængelige' = 'Quota data unavailable'
    'Afventer ny måling' = 'Waiting for a new reading'
    'Codex CLI mangler i PATH.' = 'Codex CLI is missing from PATH.'
    'Codex kunne ikke hente kvoter. Kontrollér login.' = 'Could not read Codex quotas. Check login.'
    'Codex svarede ikke i tide.' = 'Codex timed out.'
    'Kontoen returnerede ingen 5t- eller ugekvote.' = 'Account returned no 5h or weekly quota.'
    'Indstillingerne kunne ikke gemmes.' = 'Could not save settings.'
    '5t' = '5h'
    'Uge' = 'Week'
    'Målt' = 'Observed'
    'Sidst' = 'Last reading'
    'tilbage' = 'remaining'
    'brugt' = 'used'
    'Nul' = 'Reset'
    'sek.' = 'sec.'
 }
function T([string]$text) {
    if ($config.language -eq 'en' -and $english.ContainsKey($text)) { return $english[$text] }
    return $text
}
$script:demoMode = [bool]$Demo
$script:codexData = @{}
$script:claudeData = $null
$script:codexStatus = 'Venter på Codex'
$script:codexJob = $null
$script:nextRefresh = [DateTime]::MinValue
$script:icons = @{}
$script:lastError = ''
$menu = New-Object Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add('Opdatér nu')
$modeItem = $menu.Items.Add('Vis resterende')
$themeItem = $menu.Items.Add('Lyst tema')
$demoItem = $menu.Items.Add('Demotilstand')
$providerMenu = $menu.Items.Add('Udbyder')
foreach ($name in 'Codex','Claude','Begge') {
    $item = $providerMenu.DropDownItems.Add($name)
    $item.Tag = $name
    $item.Add_Click({ param($sender,$eventArgs) $config.provider=[string]$sender.Tag; Save-Settings })
}
$intervalMenu = $menu.Items.Add('Opdateringsinterval')
foreach ($seconds in $intervals) {
    $label = if ($seconds -lt 60) { "$seconds sek." } else { "$($seconds / 60) min." }
    $item = $intervalMenu.DropDownItems.Add($label)
    $item.Tag = $seconds
    $item.Add_Click({ param($sender,$eventArgs) $config.seconds=[int]$sender.Tag; Save-Settings })
}
$languageMenu = $menu.Items.Add('Sprog')
foreach ($entry in @(@{code='da'; label='Dansk'},@{code='en'; label='English'})) {
    $item=$languageMenu.DropDownItems.Add($entry.label)
    $item.Tag=$entry.code
    $item.Add_Click({ param($sender,$eventArgs) $config.language=[string]$sender.Tag; Save-Settings })
}
$null = $menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$exitItem = $menu.Items.Add('Afslut')
function Update-Language {
    $refreshItem.Text=T 'Opdatér nu'
    $modeItem.Text=T 'Vis resterende'
    $themeItem.Text=T 'Lyst tema'
    $demoItem.Text=T 'Demotilstand'
    $providerMenu.Text=T 'Udbyder'
    $intervalMenu.Text=T 'Opdateringsinterval'
    $exitItem.Text=T 'Afslut'
    $positionItem.Text=T 'Nulstil placering'
    $languageMenu.Text=T 'Sprog'
    foreach ($item in $providerMenu.DropDownItems) { $item.Text=T ([string]$item.Tag) }
    foreach ($item in $languageMenu.DropDownItems) { $item.Checked=$item.Tag -eq $config.language }
    foreach ($item in $intervalMenu.DropDownItems) {
        $seconds=[int]$item.Tag
        $item.Text=if ($seconds -lt 60) { "$seconds $(T 'sek.')" } else { "$($seconds / 60) min." }
    }
}


function Save-Settings {
    try {
        $config | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8 -ErrorAction Stop
    } catch { [Windows.Forms.MessageBox]::Show((T 'Indstillingerne kunne ikke gemmes.'), 'BODK-AI-Use') | Out-Null }
    $script:nextRefresh = [DateTime]::MinValue
    Update-Icons
}
$form = New-Object BodkTaskbarForm
$form.Text = 'BODK-AI-Use'
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.StartPosition = 'Manual'
$form.AutoScaleMode = 'None'
$form.Font = New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
$form.ContextMenuStrip = $menu
$form.ClientSize = New-Object Drawing.Size(286,40)
$tips = New-Object Windows.Forms.ToolTip
$cards = @{}
foreach ($provider in 'Codex','Claude') {
    $row = New-Object Windows.Forms.Panel
    $row.SetBounds(0,0,286,20)

    $logo = New-Object Windows.Forms.PictureBox
    $logo.SetBounds(2,0,20,20)
    $logo.Tag = $provider
    $logo.Add_Paint({
        param($sender,$e)
        $g=$e.Graphics
        $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.ScaleTransform([single](20.0/38),[single](20.0/38))
        $color=if ($sender.Tag -eq 'Claude') { [Drawing.Color]::FromArgb(232,164,132) } else { [Drawing.Color]::FromArgb(113,224,191) }
        $pen=New-Object Drawing.Pen($color,2.8)
        try {
            if ($sender.Tag -eq 'Claude') {
                for ($i=0; $i -lt 12; $i++) {
                    $angle=$i*[Math]::PI/6
                    $g.DrawLine($pen,[single](19+7*[Math]::Cos($angle)),[single](19+7*[Math]::Sin($angle)),[single](19+16*[Math]::Cos($angle)),[single](19+16*[Math]::Sin($angle)))
                }
            } else {
                $g.DrawLines($pen,[Drawing.Point[]]@([Drawing.Point]::new(6,10),[Drawing.Point]::new(15,19),[Drawing.Point]::new(6,28)))
                $g.DrawLine($pen,20,28,32,28)
            }
        } finally { $pen.Dispose() }
    })
    $row.Controls.Add($logo)
    $name=New-Object Windows.Forms.Label
    $name.Text=$provider
    $name.Font=New-Object Drawing.Font('Segoe UI',8,[Drawing.FontStyle]::Bold)
    $name.SetBounds(27,3,54,17)
    $row.Controls.Add($name)
    foreach ($window in '300','10080') {
        $x=if ($window -eq '300') { 84 } else { 183 }
        $label=New-Object Windows.Forms.Label
        $label.SetBounds($x,1,34,19)
        $label.Text=if ($window -eq '300') { '5t' } else { 'Uge' }
        $row.Controls.Add($label)
        $value=New-Object Windows.Forms.Label
        $value.SetBounds(($x+34),0,68,20)
        $value.Font=New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
        $row.Controls.Add($value)
        $script:icons["$provider-$window"]=@{ label=$value }
    }
    $cards[$provider]=$row
    $form.Controls.Add($row)
}
$positionItem = New-Object Windows.Forms.ToolStripMenuItem('Nulstil placering')
$menu.Items.Insert(0,$positionItem)
$positionItem.Add_Click({ $config.offset=0; Save-Settings })
$script:dragStart = $null
$script:dragOffset = 0
$dragDown = {
    param($sender,$e)
    if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $script:dragStart = [Windows.Forms.Cursor]::Position.X
        $script:dragOffset = $config.offset
        $sender.Capture=$true
    }
}
$dragMove = {
    param($sender,$e)
    if ($null -ne $script:dragStart) {
        $config.offset=[Math]::Max(0,$script:dragOffset + $script:dragStart - [Windows.Forms.Cursor]::Position.X)
        Place-Taskbar
    }
}
$dragUp = {
    param($sender,$e)
    if ($null -ne $script:dragStart) {
        $script:dragStart=$null
        $sender.Capture=$false
        Save-Settings
    }
}
function Enable-Dragging($control) {
    $control.ContextMenuStrip=$menu
    $control.Add_MouseDown($dragDown)
    $control.Add_MouseMove($dragMove)
    $control.Add_MouseUp($dragUp)
    foreach ($child in $control.Controls) { Enable-Dragging $child }
}
Enable-Dragging $form
function Place-Taskbar {
    if ($Preview) { return }
    $taskbar=[BodkTaskbar]::FindWindow('Shell_TrayWnd',$null)
    $rect=New-Object BodkTaskbar+Rect
    if ($taskbar -eq [IntPtr]::Zero -or ![BodkTaskbar]::IsWindowVisible($taskbar) -or ![BodkTaskbar]::GetWindowRect($taskbar,[ref]$rect)) {
        $form.Visible=$false; return
    }
    $screen=[Windows.Forms.Screen]::FromHandle($taskbar).Bounds
    $visibleHeight=[Math]::Min($rect.Bottom,$screen.Bottom)-[Math]::Max($rect.Top,$screen.Top)
    $foreground=[BodkTaskbar]::GetForegroundWindow()
    $front=New-Object BodkTaskbar+Rect
    $fullScreen=$false
    $className=New-Object Text.StringBuilder(256)
    [BodkTaskbar]::GetClassName($foreground,$className,256) | Out-Null
    if ($className.ToString() -notin 'Progman','WorkerW' -and $foreground -ne $taskbar -and $foreground -ne $form.Handle -and [BodkTaskbar]::GetWindowRect($foreground,[ref]$front)) {
        $fullScreen=($front.Left -le $screen.Left -and $front.Top -le $screen.Top -and $front.Right -ge $screen.Right -and $front.Bottom -ge $screen.Bottom)
    }
    if ($visibleHeight -lt 20 -or $fullScreen -or ($rect.Right-$rect.Left) -lt ($rect.Bottom-$rect.Top)) {
        $form.Visible=$false; return
    }
    $width=286
    $height=if ($config.provider -eq 'Begge') { 40 } else { 20 }
    $height=[Math]::Min($height,$rect.Bottom-$rect.Top)
    $tray=[BodkTaskbar]::FindWindowEx($taskbar,[IntPtr]::Zero,'TrayNotifyWnd',$null)
    $trayRect=New-Object BodkTaskbar+Rect
    $right=$rect.Right-240
    if ($tray -ne [IntPtr]::Zero -and [BodkTaskbar]::GetWindowRect($tray,[ref]$trayRect)) { $right=$trayRect.Left }
    $x=[Math]::Max($rect.Left,[Math]::Min($rect.Right-$width,$right-$width-$config.offset-4))
    $y=$rect.Top+[int](($rect.Bottom-$rect.Top-$height)/2)
    $form.Visible=$true
    [BodkTaskbar]::SetWindowPos($form.Handle,[IntPtr](-1),$x,$y,$width,$height,0x10) | Out-Null
}
function Update-Icons {
    Update-Language
    $form.BackColor = if ($config.light) { [Drawing.Color]::FromArgb(231,239,245) } else { [Drawing.Color]::FromArgb(24,24,24) }
    $form.ForeColor = if ($config.light) { [Drawing.Color]::FromArgb(30,37,48) } else { [Drawing.Color]::White }
    $rowIndex=0
    foreach ($name in 'Codex','Claude') {
        $card=$cards[$name]
        $card.Controls[1].Text = if ($script:demoMode) { if ($name -eq 'Codex') { 'Demo CX' } else { 'Demo CL' } } else { $name }
        $enabled=($config.provider -eq 'Begge' -or $config.provider -eq $name)
        $card.Visible=$enabled
        $card.BackColor=$form.BackColor
        if ($enabled) { $card.Top=20*$rowIndex; $rowIndex++ }
    }
    $providers = if ($config.provider -eq 'Begge') { 'Codex','Claude' } else { $config.provider }
    $now = [DateTimeOffset]::Now
    foreach ($provider in $providers) {
        $short = if ($provider -eq 'Codex') { 'CX' } else { 'CL' }
        $data = if ($provider -eq 'Codex') { $script:codexData } else { $script:claudeData.windows }
        foreach ($window in '300','10080') {
            $period = if ($window -eq '300') { T '5t' } else { T 'Uge' }
            $cards[$provider].Controls[$(if ($window -eq '300') { 2 } else { 4 })].Text=$period
            $key = "$provider-$window"

            $usage = if ($data -is [Collections.IDictionary]) { $data[$window] } elseif ($data) { $data.$window }
            $reset = $null
            if ($usage.reset -gt 0) {
                try { $reset = [DateTimeOffset]::FromUnixTimeSeconds([long]$usage.reset).ToLocalTime() } catch {}
            }
            $status = if ($provider -eq 'Codex') { T $script:codexStatus } else { T 'Venter på Claude Code' }
            if ($provider -eq 'Codex' -and $script:codexStatus -eq 'Sidst') { $status = (T 'Sidst') + ' ' + $script:lastGood.ToString('dd/MM HH:mm') }
            if ($provider -eq 'Claude' -and $script:claudeData.observed) {
                $observed = [DateTimeOffset]::FromUnixTimeSeconds([long]$script:claudeData.observed).ToLocalTime()
                $status = (T 'Målt') + ' ' + $observed.ToString('dd/MM HH:mm')
            }
            if ($script:demoMode) {
                $usage = @{ used = $(if ($provider -eq 'Codex') { if ($window -eq '300') { 84 } else { 41 } } else { if ($window -eq '300') { 97 } else { 58 } }) }
                $reset = if ($window -eq '300') { $now.AddHours(2) } else { $now.AddDays(3) }
                $status = 'Demo'
            }
            $color = if ($config.light) { [Drawing.Color]::FromArgb(30,37,48) } else { [Drawing.Color]::White }
            $value = '–'
            $meaning = $status
            if ($null -ne $usage.used -and (!$reset -or $reset -gt $now)) {
                $used = [Math]::Max(0,[Math]::Min(100,[double]$usage.used))
                if ($used -gt 95) { $color = [Drawing.Color]::FromArgb(245,68,86) }
                elseif ($used -gt 80) { $color = [Drawing.Color]::FromArgb(245,146,40) }
                if ($config.light -and $used -gt 95) { $color = [Drawing.Color]::FromArgb(173,21,42) }
                elseif ($config.light -and $used -gt 80) { $color = [Drawing.Color]::FromArgb(157,72,0) }
                $shown = if ($config.remaining) { 100-$used } else { $used }
                $value = '{0:0}' -f $shown
                $meaning = if ($config.remaining) { "$value% $(T 'tilbage')" } else { "$value% $(T 'brugt')" }
                if ($script:demoMode) { $meaning += ' (demo)' }
                elseif ($provider -eq 'Claude' -or $script:codexStatus -like 'Sidst*') { $meaning += " | $status" }
            } elseif ($reset -and $reset -le $now) { $meaning = T 'Afventer ny måling' }
            $tip = "$provider $period | $meaning"
            if ($reset) {
                $resetText = ' | ' + (T 'Nul') + ' ' + $reset.ToString('dd/MM HH:mm')
                if (($tip.Length + $resetText.Length) -gt 63) { $tip = $tip.Substring(0, 63-$resetText.Length) }
                $tip += $resetText
            }
            $entry = $script:icons[$key]
            $entry.label.Text = if ($value -eq '–') { '—' } else { "$value%" }
            $entry.label.ForeColor = $color
            if ($script:demoMode) { $tip = 'DEMO | ' + $tip }
            $tips.SetToolTip($entry.label,$tip)
        }
    }
}
$menu.Add_Opening({
    $modeItem.Checked = $config.remaining
    $themeItem.Checked = $config.light
    $demoItem.Checked = $script:demoMode
    foreach ($item in $providerMenu.DropDownItems) { $item.Checked = $item.Tag -eq $config.provider }
    foreach ($item in $intervalMenu.DropDownItems) { $item.Checked = $item.Tag -eq $config.seconds }
})
$refreshItem.Add_Click({ $script:nextRefresh = [DateTime]::MinValue })
$modeItem.Add_Click({ $config.remaining = !$config.remaining; Save-Settings })
$themeItem.Add_Click({ $config.light = !$config.light; Save-Settings })
$demoItem.Add_Click({ $script:demoMode = !$script:demoMode; $script:nextRefresh=[DateTime]::MinValue; Update-Icons })
$exitItem.Add_Click({ [Windows.Forms.Application]::ExitThread() })
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    if ($stop.WaitOne(0)) { [Windows.Forms.Application]::ExitThread(); return }
    Place-Taskbar
    $now = [DateTime]::UtcNow
    if ($script:codexJob -and $script:codexJob.State -in 'Completed','Failed','Stopped') {
        $jobErrors = @()
        $result = Receive-Job $script:codexJob -ErrorAction SilentlyContinue -ErrorVariable jobErrors
        if ($result -is [Collections.IDictionary] -and $result.Count) {
            $script:codexData = $result
            $script:codexStatus = ''
            $script:lastGood = Get-Date
        } elseif ($script:codexData.Count) {
            $script:codexStatus = 'Sidst'
        } else {
            $script:codexStatus = if ($jobErrors.Count) { $jobErrors[0].Exception.Message } else { 'Kvotedata utilgængelige' }
        }
        Remove-Job $script:codexJob
        $script:codexJob = $null
    }
    if ($now -ge $script:nextRefresh) {
        $script:nextRefresh = $now.AddSeconds($config.seconds)
        if (!$script:demoMode) {
            if ($config.provider -ne 'Codex') {
                try {
                    $script:claudeData = Get-Content -LiteralPath (Join-Path $root 'claude.json') -Raw -ErrorAction Stop | ConvertFrom-Json
                } catch {}
            }
            if ($config.provider -ne 'Claude' -and !$script:codexJob) {
                $script:codexJob = Start-Job -FilePath (Join-Path $root 'Read-Codex.ps1')
            }
        }
    }
    Update-Icons
})
try {
    Update-Icons
    if ($Preview) { $form.StartPosition='CenterScreen'; $form.ShowInTaskbar=$true; $form.FormBorderStyle='FixedToolWindow' }
    $form.Add_Shown({ Place-Taskbar })
    $timer.Start()
    [Windows.Forms.Application]::Run($form)
} finally {
    $timer.Dispose()
    if ($script:codexJob) {
        Wait-Job $script:codexJob -Timeout 22 | Out-Null
        Remove-Job $script:codexJob -Force
    }
    $tips.Dispose()
    $form.Dispose()
    $menu.Dispose()
    $stop.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
