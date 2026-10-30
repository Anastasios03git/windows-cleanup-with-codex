# Compatible with Windows PowerShell 5.1. No installation or cleanup runs automatically.
[CmdletBinding()]
param([switch]$ValidateOnly)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $PSScriptRoot 'Find-Dependencies.ps1')
$script:setupRepo=Split-Path $PSScriptRoot
$reader=[Xml.XmlReader]::Create((Join-Path $script:setupRepo 'app/SetupWindow.xaml'))
try{$script:setup=[Windows.Markup.XamlReader]::Load($reader)}finally{$reader.Dispose()}
$script:setupUi=@{}
foreach($name in @('InstallPowerShell','PowerShellStatus','InstallCodex','CodexStatus','SignIn','AuthStatus','SetupMessage','CheckAgain','OpenApp')){$script:setupUi[$name]=$script:setup.FindName($name)}
$script:probe=$null;$script:login=$null
function Start-SetupCommand([string]$path,[string]$arguments){
 $info=New-Object Diagnostics.ProcessStartInfo
 $info.FileName=$path;$info.Arguments=$arguments;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
 $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
 $process=New-Object Diagnostics.Process;$process.StartInfo=$info
 if(-not $process.Start()){throw 'Could not start Codex.'}
 return @{Process=$process;Out=$process.StandardOutput.ReadToEndAsync();Err=$process.StandardError.ReadToEndAsync();Started=[datetime]::UtcNow}
}
function Close-SetupCommand($job){if($job){try{if(-not $job.Process.HasExited){$job.Process.Kill()}}catch{};$job.Process.Dispose()}}
function Check-Setup {
 if($script:login){return}
 Close-SetupCommand $script:probe;$script:probe=$null
 $script:setupPwsh=Find-CleanupPowerShell;$script:setupCodex=Find-CleanupCodex
 $script:setupUi.PowerShellStatus.Text=if($script:setupPwsh){'Ready - PowerShell 7 or newer found.'}else{'Missing - install PowerShell 7, then check again.'}
 $script:setupUi.CodexStatus.Text=if($script:setupCodex){'Ready - Codex executable found.'}else{'Missing - install Codex CLI, then check again.'}
 $script:setupUi.SignIn.IsEnabled=[bool]$script:setupCodex;$script:setupUi.OpenApp.IsEnabled=$false
 $script:setupUi.AuthStatus.Text='Install Codex CLI first.'
 if($script:setupCodex){try{$script:probe=Start-SetupCommand $script:setupCodex 'login status';$script:setupUi.AuthStatus.Text='Checking sign-in...'}catch{$script:setupUi.AuthStatus.Text='Unable to check Codex: '+$_.Exception.Message}}
}
$script:setupUi.InstallPowerShell.Add_Click({Start-Process 'https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows'})
$script:setupUi.InstallCodex.Add_Click({Start-Process 'https://learn.chatgpt.com/docs/cli'})
$script:setupUi.CheckAgain.Add_Click({Check-Setup})
$script:setupUi.SignIn.Add_Click({
 if($script:login){return}
 try{
  Close-SetupCommand $script:probe;$script:probe=$null
  $script:setupUi.OpenApp.IsEnabled=$false
  $script:login=Start-SetupCommand $script:setupCodex 'login'
  $script:setupUi.SignIn.IsEnabled=$false;$script:setupUi.CheckAgain.IsEnabled=$false
  $script:setupUi.AuthStatus.Text='Complete sign-in in your browser.'
  $script:setupUi.SetupMessage.Text='Codex is opening your browser. Sign in with your own account there. Windows Cleanup does not collect your password.'
 }catch{$script:setupUi.AuthStatus.Text=$_.Exception.Message}
})
$script:setupUi.OpenApp.Add_Click({
 try{
  if(-not $script:setupUi.OpenApp.IsEnabled){return}
  $taskApp=Join-Path $script:setupRepo 'Start-WindowsCleanupApp.ps1'
  Start-Process -FilePath $script:setupPwsh -WindowStyle Hidden -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','RemoteSigned','-File',('"'+$taskApp+'"'),'-CodexPath',('"'+$script:setupCodex+'"')) | Out-Null
  $script:setup.Close()
 }catch{[void][Windows.MessageBox]::Show($script:setup,$_.Exception.Message,'Windows Cleanup')}
})
$script:setupTimer=New-Object Windows.Threading.DispatcherTimer
$script:setupTimer.Interval=[timespan]::FromMilliseconds(250)
$script:setupTimer.Add_Tick({
 foreach($kind in @('login','probe')){
  $job=Get-Variable -Name $kind -Scope Script -ValueOnly
  if(-not $job){continue}
  $timeout=if($kind -eq 'login'){600}else{20}
  if(-not $job.Process.HasExited -and ([datetime]::UtcNow-$job.Started).TotalSeconds -gt $timeout){
   Close-SetupCommand $job;Set-Variable -Name $kind -Scope Script -Value $null
   $script:setupUi.AuthStatus.Text='Sign-in check timed out. Try again.'
   $script:setupUi.SignIn.IsEnabled=[bool]$script:setupCodex;$script:setupUi.CheckAgain.IsEnabled=$true
   continue
  }
  if(-not $job.Process.HasExited -or -not $job.Out.IsCompleted -or -not $job.Err.IsCompleted){continue}
  $success=$job.Process.ExitCode -eq 0
  $output=($job.Out.GetAwaiter().GetResult()+' '+$job.Err.GetAwaiter().GetResult()).Trim()
  $job.Process.Dispose();Set-Variable -Name $kind -Scope Script -Value $null
  if($kind -eq 'login'){
   $script:setupUi.SignIn.IsEnabled=$true;$script:setupUi.CheckAgain.IsEnabled=$true
   $script:setupUi.SetupMessage.Text=if($success){'Sign-in finished. Checking your account...'}else{'Sign-in did not complete. Try Sign in again. '+$output}
   Check-Setup
  }else{
   $script:setupUi.AuthStatus.Text=if($success){'Ready - signed in to Codex.'}else{'Not signed in. Select Sign in to continue.'}
   $script:setupUi.OpenApp.IsEnabled=$success -and [bool]$script:setupPwsh -and [bool]$script:setupCodex
   if($script:setupUi.OpenApp.IsEnabled){$script:setupUi.SetupMessage.Text='All requirements are ready. Open the app to start a read-only inspection.'}
  }
 }
})
if($ValidateOnly){'PASS: setup XAML and handlers loaded; no checks or sign-in started.';return}
Check-Setup;$script:setupTimer.Start()
try{[void]$script:setup.ShowDialog()}finally{$script:setupTimer.Stop();Close-SetupCommand $script:probe;Close-SetupCommand $script:login}
