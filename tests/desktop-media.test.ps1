param([Parameter(Mandatory=$true)][string]$StateDir)
$ErrorActionPreference='Stop';Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root=Split-Path $PSScriptRoot -Parent;$script:stateDir=$StateDir;$TestMode=$true
$script:prefs=@{soundOn=$false;soundVolume=.35;musicVolume=.35};$script:checks=[Collections.Generic.List[string]]::new()
function Save-Preferences {[IO.File]::WriteAllText((Join-Path $StateDir 'preferences.json'),($script:prefs|ConvertTo-Json))}
function Read-Json($file){try{Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json}catch{$null}}
function Assert-Media($v,$name){if(!$v){throw "Media assertion: $name"};$script:checks.Add($name)}
function Pump {
  $frame=[Windows.Threading.DispatcherFrame]::new();$t=[Windows.Threading.DispatcherTimer]::new();$t.Interval=[TimeSpan]::FromMilliseconds(20)
  $t.Add_Tick({param($sender,$event)$sender.Stop();$frame.Continue=$false}.GetNewClosure());$t.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
}
. (Join-Path $root 'desktop/media.ps1')
$script:window=[Windows.Window]::new();$script:window.Width=120;$script:window.Height=100;$script:window.Show()
Initialize-GeminiMedia
try{
  Assert-Media ([bool]$script:geminiNiangAudio) 'built-in sounds preloaded'
  Assert-Media (!(Get-WidgetAudioEnabled)) 'sound defaults off and test mode silent'
  $clip=Read-WidgetPcmWave (Join-Path $root 'desktop/assets/press.wav')
  Assert-Media ($clip.Duration-gt 0-and $clip.Duration-lt .2) 'original short tone is valid PCM'
  $zero=[GeminiNiangPcm]::Scale($clip.Bytes,$clip.Offset,$clip.Length,0)
  $nonzero=0;for($i=$clip.Offset;$i-lt $clip.Offset+$clip.Length;$i++){if($zero[$i]-ne 0){$nonzero++}}
  Assert-Media ($nonzero-eq 0) 'zero volume silences every PCM sample'
  Assert-Media ($clip.Bytes[0]-eq $zero[0]) 'scaling preserves WAV header'
  Set-GeminiSound $true;Set-GeminiSoundVolume .5
  Assert-Media ($script:prefs.soundOn-and $script:prefs.soundVolume-eq .5) 'sound settings persist'
  Assert-Media (!(Get-WidgetAudioEnabled)) 'test mode suppresses playback even when enabled'
  $import=Import-WidgetAudio 'press' (Join-Path $root 'desktop/assets/release.wav')
  Assert-Media $import 'custom click importer accepts valid PCM'
  Assert-Media ($script:geminiNiangAudio.Preferences.mode-eq 'custom') 'custom mode committed after preload'
  $before=[IO.File]::ReadAllText((Join-Path $StateDir 'audio-preferences.json'))
  [IO.File]::WriteAllText((Join-Path $StateDir 'invalid.wav'),'not wave')
  $rejected=$false;try{Import-WidgetAudio 'press' (Join-Path $StateDir 'invalid.wav')|Out-Null}catch{$rejected=$true}
  Assert-Media $rejected 'invalid click file rejected'
  Assert-Media ($before-eq [IO.File]::ReadAllText((Join-Path $StateDir 'audio-preferences.json'))) 'failed click import preserves prior preferences'
  # A native-call stand-in tests queue ownership without producing sound.
  Add-Type -TypeDefinition @'
using System;using System.Threading;
public static class GeminiAudioProbe {public static int Calls;public static bool Play(IntPtr data,uint flags){Interlocked.Increment(ref Calls);return true;}}
'@
  $delegate=[Delegate]::CreateDelegate([System.Func[System.IntPtr,System.UInt32,System.Boolean]],[GeminiAudioProbe].GetMethod('Play'))
  $queue=[GeminiClickAudioQueue]::new($delegate);$queue.Play($clip.Bytes);[Threading.Thread]::Sleep(100);$queue.Stop();$queue.Dispose();$queue.Wait(1000)
  Assert-Media ([GeminiAudioProbe]::Calls-ge 2) 'worker performs play and stop through injected backend'
  Assert-Media (!$queue.IsRunning) 'audio queue shuts down cleanly'
  $silent=Get-GeminiMusicMotion 0;$loud=Get-GeminiMusicMotion 1
  Assert-Media ($silent.y-eq 0-and $silent.scale-eq 1) 'zero energy creates no music motion'
  Assert-Media ($loud.y-eq -12-and $loud.scale-le 1.05) 'energy motion bounded'
  Assert-Media ([Math]::Abs((Get-GeminiMusicMotion .25).y+3)-lt .001) 'fractional RMS energy not rounded to integer'
  $source=Join-Path $StateDir 'track.wav';$original=[IO.File]::ReadAllBytes($source)
  Start-GeminiMusic $source
  $end=[DateTime]::UtcNow.AddSeconds(12)
  while($script:music.mode-in @('loading','opening')-and [DateTime]::UtcNow-lt $end){Update-GeminiMusic;Pump}
  $backendAvailable=$script:music.mode-eq 'playing'
  Assert-Media ($backendAvailable-or ($script:music.mode-eq 'error'-and $script:music.lastError)) 'actual WPF backend opens or reports clean unavailability'
  if($backendAvailable){
    Assert-Media ($script:music.player.Volume-eq 0) 'actual WPF playback is muted in tests'
    $end=[DateTime]::UtcNow.AddSeconds(2)
    while($script:music.player.Position.TotalSeconds-le .02-and [DateTime]::UtcNow-lt $end){Pump}
    Assert-Media ($script:music.player.Position.TotalSeconds-gt .02) 'actual media clock advances'
    Assert-Media ((Get-GeminiMusicLevel .1)-gt 0) 'playback timeline reads analyzed energy'
    $script:window.Hide();Update-GeminiMusic
    Assert-Media ($script:music.mode-eq 'paused-hidden') 'hidden host pauses music'
    $script:window.Show();Update-GeminiMusic
    Assert-Media ($script:music.mode-eq 'paused-hidden') 'restoring host never auto resumes audio'
    Toggle-GeminiMusic;Assert-Media ($script:music.mode-eq 'playing') 'explicit resume works'
    Toggle-GeminiMusic;Assert-Media ($script:music.mode-eq 'paused') 'explicit pause works'
    Assert-Media ((Get-GeminiMusicLevel .1)-eq 0) 'paused music has no motion'
  }
  Set-GeminiMusicVolume .75
  Assert-Media ($script:prefs.musicVolume-eq .75) 'music volume preference independent'
  $guarded=$false;try{Remove-GeminiMusicCache $source}catch{$guarded=$true}
  Assert-Media $guarded 'cache cleanup refuses original selected file'
  Stop-GeminiMusic
  Assert-Media ($script:music.mode-eq 'stopped'-and !$script:music.player-and !$script:music.process) 'stop releases process and player'
  Assert-Media ([Convert]::ToBase64String([IO.File]::ReadAllBytes($source))-eq [Convert]::ToBase64String($original)) 'selected music file never changed'
  Start-GeminiMusic (Join-Path $StateDir 'invalid.wav')
  $end=[DateTime]::UtcNow.AddSeconds(5);while($script:music.mode-eq 'loading'-and [DateTime]::UtcNow-lt $end){Update-GeminiMusic;Pump}
  Assert-Media ($script:music.mode-eq 'error') 'invalid music is a nonfatal UI error'
  Assert-Media (!$script:music.lastError.Contains($StateDir)) 'music error does not leak private source paths'
  @{ok=$true;mutedPlaybackBackendAvailable=$backendAvailable;checks=$script:checks.ToArray()}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $StateDir 'media-checks.json') -Encoding UTF8
  "Media checks passed: $($script:checks.Count); muted WPF backend=$backendAvailable"
}finally{Close-GeminiMedia;$script:window.Close()}
