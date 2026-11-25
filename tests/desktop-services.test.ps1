param([Parameter(Mandatory=$true)][string]$StateDir,[ValidateSet('Pool','Scheduler','Placement')][string]$Case)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$null=New-Item -ItemType Directory -Path $StateDir -Force
$script:stateDir=$StateDir;$script:checks=[Collections.Generic.List[string]]::new()
$script:prefs=@{followHost=$false;collapsed=$true;autoQuoteEnabled=$false;autoQuoteIntervalSeconds=300}
function Save-Preferences {[IO.File]::WriteAllText((Join-Path $StateDir 'preferences.json'),($script:prefs|ConvertTo-Json))}
function Assert-Service($value,$name){if(!$value){throw "Failed: $name"};$script:checks.Add($name)}
function Assert-Rejected([scriptblock]$operation,$name){$rejected=$false;try{& $operation|Out-Null}catch{$rejected=$true};Assert-Service $rejected $name}
function Get-TestSha256([string]$File){$hash=[Security.Cryptography.SHA256]::Create();try{[BitConverter]::ToString($hash.ComputeHash([IO.File]::ReadAllBytes($File)))}finally{$hash.Dispose()}}
. (Join-Path $root 'desktop/quotes.ps1')
. (Join-Path $root 'desktop/scenes.ps1')
. (Join-Path $root 'desktop/placement.ps1')
if($Case-eq 'Pool'){
  $settings=Get-WidgetQuoteSettings $StateDir
  Assert-Service ($settings.source-eq 'built-in' -and $settings.quotes.Count-eq 3) 'original local defaults'
  $rows=@(ConvertFrom-GeminiQuoteLines "3 | 第一条`n第二条`n2 | 第一条")
  $saved=Save-WidgetQuotes $StateDir $rows
  Assert-Service ($saved.source-eq 'custom' -and $saved.quotes.Count-eq 2) 'custom roundtrip with deduplication'
  Assert-Service ($saved.quotes[0].weight-eq 5) 'duplicate weights merged'
  $last='';for($i=0;$i-lt 20;$i++){$next=Get-WidgetQuote $StateDir;Assert-Service ($next-ne $last) 'avoid immediate repetition';$last=$next}
  foreach($inputText in @('','0 | 无效','1001 | 无效','-1 | 无效','错误 | 台词',('x'*201))){Assert-Rejected {ConvertFrom-GeminiQuoteLines $inputText} 'invalid editor input rejected'}
  $before=[IO.File]::ReadAllText((Join-Path $StateDir 'quotes.json'))
  Assert-Rejected {Save-WidgetQuotes $StateDir @()} 'empty save rejected'
  Assert-Service ($before-eq [IO.File]::ReadAllText((Join-Path $StateDir 'quotes.json'))) 'failed save preserves prior file'
  Save-WidgetQuotes $StateDir @('单句')|Out-Null
  Assert-Service ([IO.File]::ReadAllText((Join-Path $StateDir 'quotes.json.bak'))-eq $before) 'replace creates exact backup'
  Assert-Service ((Get-WidgetQuote $StateDir)-eq '单句' -and (Get-WidgetQuote $StateDir)-eq '单句') 'single quote remains usable'
  # Recovery is verified on an additional copy, never by reverting user data.
  [IO.File]::Copy((Join-Path $StateDir 'quotes.json.bak'),(Join-Path $StateDir 'recovery-copy.json'))
  Assert-Service ((Get-TestSha256 (Join-Path $StateDir 'quotes.json.bak'))-eq (Get-TestSha256 (Join-Path $StateDir 'recovery-copy.json'))) 'backup recovery copy SHA256'
  [IO.File]::WriteAllText((Join-Path $StateDir 'quotes.json'),'{broken')
  $fallback=Get-WidgetQuoteSettings $StateDir
  Assert-Service ($fallback.source-eq 'built-in' -and $fallback.error) 'corrupt custom file falls back without rewrite'
  Assert-Service ([IO.File]::ReadAllText((Join-Path $StateDir 'quotes.json'))-eq '{broken') 'fallback leaves corrupt file intact for recovery'
  $reset=Reset-WidgetQuotes $StateDir
  Assert-Service ($reset.source-eq 'built-in' -and [IO.File]::ReadAllText((Join-Path $StateDir 'quotes.json.bak'))-eq '{broken') 'reset backs up custom content'
  $large=@(for($i=0;$i-lt 5001;$i++){@{text="row$i";weight=1}})
  Assert-Rejected {Save-WidgetQuotes $StateDir $large} 'over 5000 unique quotes rejected'
  Assert-Service (![IO.File]::Exists((Join-Path $StateDir 'quotes.json'))) 'oversized rejection leaves reset state unchanged'
}
if($Case-eq 'Scheduler'){
  Initialize-WidgetAutoQuoteSettings $script:prefs
  Assert-Service (!(Test-WidgetAutoQuoteDue 1000 $true $false)) 'off by default'
  Set-GeminiAutoQuotes $true 60
  Assert-Service ((Get-Content (Join-Path $StateDir 'preferences.json') -Raw|ConvertFrom-Json).autoQuoteEnabled) 'enabled preference saved'
  Assert-Rejected {Set-GeminiAutoQuotes $true 5} 'unsupported interval rejected'
  Assert-Service (!(Test-WidgetAutoQuoteDue 1000 $true $false)) 'eligible transition starts new interval'
  $due=0;for($now=1500;$now-le 61000;$now+=500){if(Test-WidgetAutoQuoteDue $now $true $false){$due++}}
  Assert-Service ($due-eq 1) 'one quote after full eligible minute'
  Assert-Service (!(Test-WidgetAutoQuoteDue 61500 $false $false)) 'hidden window suppressed'
  Assert-Service (!(Test-WidgetAutoQuoteDue 120000 $true $false)) 'restoring window does not burst'
  Assert-Service (!(Test-WidgetAutoQuoteDue 120500 $true $true)) 'busy menu or completion suppressed'
  Assert-Service (!(Test-WidgetAutoQuoteDue 181000 $true $false)) 'busy to idle starts fresh interval'
  Assert-Service (!(Test-WidgetAutoQuoteDue 180000 $true $false)) 'clock moving backwards resets interval'
  Assert-Service (!(Test-WidgetAutoQuoteDue 400000 $true $false)) 'sleep resume resets interval'
  # Exercise scene policy with deterministic time and non-UI stand-ins.
  $script:window=[pscustomobject]@{IsVisible=$true};$script:menu=[pscustomobject]@{IsOpen=$false};$script:bubble=[pscustomobject]@{Visibility='Hidden'}
  $script:noticeUntil=[DateTime]::MinValue;$script:noticeRestorePending=$false;$script:autoQuoteUntil=0;$script:dragging=$false;$script:quoteEditor=$null
  $script:shown=0
  function Set-GeminiBubble([bool]$visible,[switch]$Transient){$script:bubble.Visibility=if($visible){'Visible'}else{'Hidden'}}
  function Show-GeminiQuote([switch]$Automatic){$script:shown++;$script:bubbleMode='quote';Set-GeminiBubble $true -Transient}
  Reset-WidgetAutoQuoteSchedule 1000
  for($now=1000;$now-le 61000;$now+=500){Update-GeminiScenes $now}
  Assert-Service ($script:shown-eq 1 -and $script:bubble.Visibility-eq 'Visible') 'scene displays due quote'
  for($now=61500;$now-le 69000;$now+=500){Update-GeminiScenes $now}
  Assert-Service ($script:bubble.Visibility-eq 'Hidden' -and $script:bubbleMode-eq 'quota') 'automatic quote disappears after eight seconds'
  $script:bubble.Visibility='Visible';$script:bubbleMode='quota'
  for($now=69500;$now-le 150000;$now+=500){Update-GeminiScenes $now}
  Assert-Service ($script:shown-eq 1) 'automatic quote does not interrupt quota reading'
  $script:noticeRestorePending=$true;$script:prefs.collapsed=$true;Update-GeminiScenes 150500
  Assert-Service ($script:bubble.Visibility-eq 'Hidden') 'expired completion restores collapsed bubble'
  $script:bubble.Visibility='Hidden';$script:menu.IsOpen=$true
  for($now=151000;$now-le 220000;$now+=500){Update-GeminiScenes $now}
  Assert-Service ($script:shown-eq 1) 'open menu prevents automatic quote'
}
if($Case-eq 'Placement'){
  $bounds=@{left=-1920;top=-200;right=0;bottom=880}
  $p=Get-GeminiPlacement $bounds 400 400 -1800 -100
  Assert-Service ($p.x-eq -1800 -and $p.y-eq -100) 'negative monitor origin preserved'
  $p=Get-GeminiPlacement $bounds 400 400 1000 1000
  Assert-Service ($p.x-eq -400 -and $p.y-eq 480) 'right and bottom clamped'
  $p=Get-GeminiPlacement $bounds 400 400 -5000 -5000
  Assert-Service ($p.x-eq -1920 -and $p.y-eq -200) 'left and top clamped'
  $p=Get-GeminiPlacement $bounds 3000 2000 10 10
  Assert-Service ($p.x-eq -1920 -and $p.y-eq -200) 'oversized canvas anchored inside available bounds'
  $before=@{left=100;top=100;right=500;bottom=500};$after=@{left=-100;top=50;right=300;bottom=450}
  Assert-Service (Save-GeminiPosition $before $after $null) 'desktop drag recognized'
  Assert-Service ($script:prefs.desktopLeft-eq -100 -and $script:prefs.desktopTop-eq 50) 'desktop pixel coordinates persisted'
  Assert-Service (!(Save-GeminiPosition $before $before $null)) 'stationary click not treated as drag'
  $script:prefs.followHost=$true
  $null=Save-GeminiPosition $before $after @{right=1000;bottom=800}
  Assert-Service ($script:prefs.right-eq 700 -and $script:prefs.bottom-eq 350) 'follow offsets saved in native pixels'
  . (Join-Path $root 'desktop/native.ps1')
  $area=[GeminiNiangNative]::WorkArea(100000,100000)
  Assert-Service ($area.right-gt $area.left -and $area.bottom-gt $area.top) 'real nearest-monitor work area available'
}
$result=@{ok=$true;case=$Case;checks=$script:checks.ToArray()}
$result|ConvertTo-Json -Depth 5 | Set-Content (Join-Path $StateDir ($Case+'-result.json')) -Encoding UTF8
"$Case checks passed: $($script:checks.Count)"
