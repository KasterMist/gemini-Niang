param([string]$OutputDirectory=(Join-Path $env:LOCALAPPDATA 'GeminiNiang\bin'))
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition-ne 'Desktop'){throw 'Build with Windows PowerShell 5.1 (powershell.exe).'}
$root=Split-Path $PSScriptRoot -Parent
function Hash-Bytes([byte[]]$Bytes){$h=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}}
$source=Join-Path $root 'desktop/Host.cs';$manifest=Join-Path $root 'desktop/Host.manifest'
$config='<configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup><runtime><AppContextSwitchOverrides value="Switch.System.Windows.DoNotScaleForDpiChanges=false"/></runtime></configuration>'
$hash=Hash-Bytes ([Text.Encoding]::UTF8.GetBytes(([IO.File]::ReadAllText($source)+[IO.File]::ReadAllText($manifest)+$config)))
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory);$null=[IO.Directory]::CreateDirectory($OutputDirectory)
$exe=Join-Path $OutputDirectory ('GeminiNiang-'+$hash.Substring(0,12)+'.exe');$record=$exe+'.build.json'
if([IO.File]::Exists($exe)){
  if(![IO.File]::Exists($record)){throw 'GUI host cache has no integrity record.'}
  $old=[IO.File]::ReadAllText($record)|ConvertFrom-Json
  if($old.sourceHash-ne $hash-or $old.binaryHash-ne (Hash-Bytes ([IO.File]::ReadAllBytes($exe)))-or [IO.File]::ReadAllText($exe+'.config')-ne $config){throw 'GUI host cache integrity check failed.'}
}else{
  $parameters=[CodeDom.Compiler.CompilerParameters]::new();$parameters.GenerateExecutable=$true;$parameters.GenerateInMemory=$false;$parameters.OutputAssembly=$exe
  $parameters.CompilerOptions='/target:winexe /win32manifest:"'+$manifest+'"'
  $parameters.ReferencedAssemblies.AddRange([string[]]@([PSObject].Assembly.Location,'System.dll','System.Core.dll','System.Windows.Forms.dll'))
  Add-Type -Path $source -CompilerParameters $parameters
  [IO.File]::WriteAllText($exe+'.config',$config,[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($record,(@{sourceHash=$hash;binaryHash=(Hash-Bytes ([IO.File]::ReadAllBytes($exe)))}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
}
@{executable=$exe;sourceHash=$hash}|ConvertTo-Json
