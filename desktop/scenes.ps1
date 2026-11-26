# Gemini-Niang scene policy. Upstream weighted quote pool/scheduler lives in quotes.ps1.
function ConvertFrom-GeminiQuoteLines([string]$Lines) {
  if($Lines.Length-gt 1MB){throw '输入超过 1 MB，请精简后重试。'}
  $rows=[Collections.Generic.List[object]]::new();$lineNumber=0
  foreach($line in ($Lines -split '\r?\n')){
    $lineNumber++;$text=$line.Trim();if(!$text){continue};$weight=1.0
    if($text.Contains('|')){
      if($text-notmatch '^\s*(\d+(?:\.\d+)?)\s*\|\s*(.+)$'){throw "第 $lineNumber 行格式不正确，请使用：3 | 台词"}
      $weight=[double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture);$text=$Matches[2].Trim()
    }
    if(!$text-or $text.Length-gt 200-or $text-match '[\x00-\x1F]' -or $weight-le 0-or $weight-gt 1000){throw "第 $lineNumber 行无效：每句 1–200 字，权重须大于 0 且不超过 1000。"}
    $rows.Add([pscustomobject]@{text=$text;weight=$weight})
    if($rows.Count-gt 5000){throw '语录条数超过 5000。'}
  }
  if(!$rows.Count){throw '请至少填写一条语录。'}
  $rows.ToArray()
}
function Set-GeminiAutoQuotes([bool]$Enabled,[int]$Seconds) {
  if($Seconds-notin @(60,300,900)){throw '请选择 1、5 或 15 分钟。'}
  $script:prefs.autoQuoteEnabled=$Enabled;$script:prefs.autoQuoteIntervalSeconds=$Seconds
  Set-WidgetAutoQuoteSettings $Enabled $Seconds
}
function Set-GeminiMessage([string]$Message) {
  # Fit long user quotes to the upstream 184x115 text area instead of clipping.
  for($font=20;$font-ge 8;$font-=.5){
    $face=[Windows.Media.Typeface]::new($script:text.FontFamily,$script:text.FontStyle,$script:text.FontWeight,$script:text.FontStretch)
    $formatted=[Windows.Media.FormattedText]::new($Message,[Globalization.CultureInfo]::CurrentUICulture,[Windows.FlowDirection]::LeftToRight,$face,$font,[Windows.Media.Brushes]::Black)
    $formatted.MaxTextWidth=184;$formatted.LineHeight=$font*1.3
    if($formatted.Height-le 112){break}
  }
  $script:text.FontSize=[Math]::Max(8,$font);$script:text.LineHeight=$script:text.FontSize*1.3;$script:text.Text=$Message
}
function Update-GeminiScenes([long]$Now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) {
  $noticeActive=[DateTime]::UtcNow-lt $script:noticeUntil
  if($script:noticeRestorePending-and !$noticeActive){
    $script:noticeRestorePending=$false;Set-GeminiBubble (!$script:prefs.collapsed) -Transient
  }
  if($script:autoQuoteUntil-gt 0-and $Now-ge $script:autoQuoteUntil){
    $script:autoQuoteUntil=0;$script:bubbleMode='quota';Set-GeminiBubble (!$script:prefs.collapsed) -Transient
  }
  $editing=$script:quoteEditor-and $script:quoteEditor.IsVisible
  # Never interrupt quota reading, a menu, a drag or a completion notification.
  $busy=$noticeActive-or $script:dragging-or $script:menu.IsOpen-or $editing-or $script:audioDialogOpen-or ($script:music-and $script:music.mode-in @('loading','opening','playing'))-or ($script:systemRhythm-and $script:systemRhythm.Enabled)-or ($script:bubble.Visibility-eq 'Visible')
  if(Test-WidgetAutoQuoteDue $Now ([bool]$script:window.IsVisible) ([bool]$busy)){
    Show-GeminiQuote -Automatic
    $script:autoQuoteUntil=$Now+8000
  }
}
