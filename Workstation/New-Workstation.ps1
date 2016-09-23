#Requires -RunAsAdministrator
$ex = Get-ExecutionPolicy
if ($ex -ne "RemoteSigned" -and $ex -ne "Unrestricted") {
    throw [System.InvalidOperationException]"Execution policy must be RemoteSigned or Unrestricted"
}

if (-not $env:ChocolateyInstall) {
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))    
}
#Stopping the bloody annoying beep sound on console
$beep = Get-Service Beep 
$beep | Stop-Service -Force
$beep | Set-Service -StartupType Disabled
cinst notepadplusplus -y --force
cinst googlechrome -y --force
cinst 7zip -y --force
cinst sysinternals -y --force
cinst fiddler4 -y --force
cinst visualstudiocode -y --force
cinst greenshot -y --force
cinst webpi -y --force
cinst sumatrapdf -y --force
cinst firefox-dev -pre -y --force
cinst git -y --force
cinst poshgit -y --force
cinst NuGet.CommandLine -y --force

#refresh environment variables
refreshenv