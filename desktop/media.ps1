# Gemini-Niang local media controller. No recording devices or loopback capture.
. (Join-Path $PSScriptRoot 'audio.ps1')
. (Join-Path $PSScriptRoot 'system-rhythm.ps1')
function Initialize-GeminiMedia {
  $script:soundOn=($script:prefs.soundOn-eq $true)
  $script:soundVolume=if($null-ne $script:prefs.soundVolume){[double]$script:prefs.soundVolume}else{.35}
  Initialize-WidgetAudio $PSScriptRoot $script:stateDir
  $script:music=@{mode='stopped';player=$null;process=$null;target=$null;metadata=$null;lastError=$null;started=[DateTime]::MinValue}
}
function Set-GeminiSound([bool]$Enabled) {
  $script:prefs.soundOn=$Enabled;$script:soundOn=$Enabled
  if(!$Enabled){Stop-WidgetAudio}
  Save-Preferences
}
function Set-GeminiSoundVolume([double]$Volume) {
  if([double]::IsNaN($Volume)-or [double]::IsInfinity($Volume)-or $Volume-lt 0-or $Volume-gt 1){throw '音量须在 0–100% 之间。'}
  Set-WidgetAudioVolume $Volume;$script:prefs.soundVolume=Get-WidgetAudioVolume;Save-Preferences
}
function Remove-GeminiMusicCache([string]$Target) {
  if(!$Target){return}
  $cache=[IO.Path]::GetFullPath((Join-Path $script:stateDir 'music-cache'))
  $full=[IO.Path]::GetFullPath($Target)
  if(![string]::Equals([IO.Path]::GetDirectoryName($full),$cache,[StringComparison]::OrdinalIgnoreCase)-or [IO.Path]::GetFileName($full)-notmatch '^[a-f0-9]{32}\.wav$'){throw '拒绝清理非本插件缓存文件。'}
  foreach($file in @($full,($full+'.json'))){try{if([IO.File]::Exists($file)){[IO.File]::Delete($file)}}catch{}}
}
function Stop-GeminiMusic {
  if(!$script:music){return}
  if($script:music.process){try{if(!$script:music.process.HasExited){$script:music.process.Kill();$null=$script:music.process.WaitForExit(1000)}}finally{$script:music.process.Dispose();$script:music.process=$null}}
  if($script:music.player){$player=$script:music.player;$script:music.player=$null;$player.Close()}
  Remove-GeminiMusicCache $script:music.target
  $script:music.target=$null;$script:music.metadata=$null;$script:music.mode='stopped'
}
function Start-GeminiMusic([string]$Source) {
  if(!$script:window.IsVisible){throw '请先显示挂件，再选择音乐。'}
  if(!$Source-or $Source.StartsWith('\\')-or ![IO.Path]::IsPathRooted($Source)-or ![IO.File]::Exists($Source)){throw '请选择本机上的 WAV 文件。'}
  Stop-GeminiSystemRhythm;Stop-GeminiMusic;$script:music.lastError=$null
  $cache=Join-Path $script:stateDir 'music-cache';$null=[IO.Directory]::CreateDirectory($cache)
  if((Get-Item -LiteralPath $cache).Attributes-band [IO.FileAttributes]::ReparsePoint){throw '音乐缓存目录不能是链接。'}
  $target=Join-Path $cache ([Guid]::NewGuid().ToString('N')+'.wav')
  $node=(Get-Command node.exe -ErrorAction Stop).Source
  $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$node;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
  $info.Arguments='"'+(Join-Path $PSScriptRoot 'music-import.mjs')+'" "'+$Source+'" "'+$target+'"'
  $p=[Diagnostics.Process]::new();$p.StartInfo=$info
  try{if(!$p.Start()){throw '音乐分析无法启动。'}}catch{$p.Dispose();throw}
  $script:music.target=$target;$script:music.process=$p;$script:music.mode='loading';$script:music.started=[DateTime]::UtcNow
}
function Open-GeminiMusicPlayer {
  $player=[Windows.Media.MediaPlayer]::new();$script:music.player=$player
  $player.Volume=if($TestMode){0}else{[double]$script:prefs.musicVolume}
  $player.Add_MediaOpened({param($sender,$event)
    if(![object]::ReferenceEquals($sender,$script:music.player)){return}
    if($script:window.IsVisible){$sender.Play();$script:music.mode='playing'}else{$script:music.mode='paused-hidden'}
  })
  $player.Add_MediaEnded({param($sender,$event)if([object]::ReferenceEquals($sender,$script:music.player)){$sender.Pause();$sender.Position=[TimeSpan]::Zero;$script:music.mode='ended'}})
  $player.Add_MediaFailed({param($sender,$event)if([object]::ReferenceEquals($sender,$script:music.player)){$script:music.lastError='本机音频设备或解码器无法播放该 WAV。';Stop-GeminiMusic;$script:music.mode='error'}})
  $script:music.mode='opening';$script:music.started=[DateTime]::UtcNow;$player.Open([Uri]$script:music.target)
}
function Update-GeminiMusic {
  if(!$script:music){return}
  if($script:music.process){
    if(!$script:music.process.HasExited){
      if(([DateTime]::UtcNow-$script:music.started).TotalSeconds-gt 30){Stop-GeminiMusic;$script:music.lastError='音乐分析超时。';$script:music.mode='error'}
      return
    }
    $code=$script:music.process.ExitCode;$script:music.process.Dispose();$script:music.process=$null
    $meta=Read-Json ($script:music.target+'.json')
    if($code-ne 0-or !$meta.ok){
      $message=switch($meta.error){'too_large'{'WAV 文件或转换结果超过 100 MiB。'}'too_long'{'音乐超过 20 分钟。'}'unsupported'{'请选择未压缩 PCM 或 Float WAV。'}default{'WAV 文件无效或无法读取。'}}
      Stop-GeminiMusic;$script:music.lastError=$message;$script:music.mode='error';return
    }
    $script:music.metadata=$meta;Open-GeminiMusicPlayer
  }
  if($script:music.mode-eq 'opening'-and ([DateTime]::UtcNow-$script:music.started).TotalSeconds-gt 15){Stop-GeminiMusic;$script:music.lastError='播放器打开超时。';$script:music.mode='error'}
  if($script:music.mode-eq 'playing'-and !$script:window.IsVisible){$script:music.player.Pause();$script:music.mode='paused-hidden'}
}
function Toggle-GeminiMusic {
  if($script:music.mode-eq 'playing'){$script:music.player.Pause();$script:music.mode='paused'}
  elseif($script:music.mode-in @('paused','paused-hidden','ended')-and $script:window.IsVisible){$script:music.player.Play();$script:music.mode='playing'}
}
function Set-GeminiMusicVolume([double]$Volume) {
  if([double]::IsNaN($Volume)-or [double]::IsInfinity($Volume)-or $Volume-lt 0-or $Volume-gt 1){throw '音量须在 0–100% 之间。'}
  $script:prefs.musicVolume=$Volume
  if($script:music.player){$script:music.player.Volume=if($TestMode){0}else{$Volume}}
  Save-Preferences
}
function Get-GeminiMusicLevel([double]$Seconds) {
  if($script:music.mode-ne 'playing'-or !$script:music.metadata-or [double]::IsNaN($Seconds)-or [double]::IsInfinity($Seconds)-or $Seconds-lt 0-or $Seconds-ge $script:music.metadata.duration){return 0.0}
  $index=[int][Math]::Floor($Seconds/$script:music.metadata.stepSeconds)
  if($index-lt 0-or $index-ge $script:music.metadata.levels.Count){return 0.0}
  return [Math]::Max(0.0,[Math]::Min(1.0,[double]$script:music.metadata.levels[$index]))
}
function Get-GeminiMusicMotion([double]$Level) {
  if([double]::IsNaN($Level)-or [double]::IsInfinity($Level)){$Level=0}
  $v=[Math]::Max(0.0,[Math]::Min(1.0,$Level))
  return @{y=-12*$v;scale=1+.05*$v;angle=1.8*$v}
}
function Invoke-GeminiMediaAction([string]$Action) {
  $script:audioDialogOpen=$true
  try{
    switch($Action){
      'music'{
        $dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Title='选择并播放本地 WAV（不监听系统音频）';$dialog.Filter='未压缩 WAV (*.wav)|*.wav';$dialog.Multiselect=$false;$dialog.CheckFileExists=$true
        if($dialog.ShowDialog($script:window)-eq $true){Start-GeminiMusic $dialog.FileName}
      }
      'preview'{if(Get-WidgetAudioEnabled){$audio=$script:geminiNiangAudio;if($audio.Press){$audio.Queue.Play($audio.Press)}}}
    }
  }catch{[Windows.MessageBox]::Show($script:window,$_.Exception.Message,'Gemini 娘 · 本地媒体',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Warning)|Out-Null}
  finally{$script:audioDialogOpen=$false}
}
function Close-GeminiMedia {Stop-GeminiSystemRhythm;Stop-GeminiMusic;Close-WidgetAudio}
