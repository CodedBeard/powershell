<#
    .Author
        Stephen Croxford > https://github.com/codedbeard/powershell/TFS-Build/Copy-FilesOverPSSession/Copy-FilesOverPSSession.ps1
    .Description
        TFS task for copying files using WMF 5 remote session copy. Both SSLCA and SSLCN checks are skipped
#>
param([string]$computer,
[string]$port,
[string]$user,
[string]$password,
[string]$path,
[string]$include,
[string]$dropName)

if(-not $password){
    Write-Output "no password provided! Cannot continue"
    exit 1
}
[string[]]$inc
if($include -like "*;*"){
    $inc = $include -split ";"
}

Write-Output "Computer: $computer"
Write-Output "Port: $port"
Write-Output "User: $user"
Write-Output "Password: $password"
Write-Output "Path: $path"
Write-Output "Include: $include"
Write-Output "DropName: $dropName"

$sec = ConvertTo-SecureString $password -AsPlainText -Force
if(-not $sec){
    Write-Output "SecureString conversion failed! Cannot continue"
    exit 1
}
$creds = New-Object System.Management.Automation.PSCredential ($user, $sec)
if(-not $creds){
    Write-Output "could not create credential object! Cannot continue"
    exit 1
}
$items = Get-ChildItem -Path $path -Recurse -Force -Include $inc
if((-not $items) -or ($items.Count -lt 1)){
    Write-Output "No items found! Cannot continue"
    exit 1
}
$o = New-PSSessionOption -SkipCACheck -SkipCNCheck
$s = New-PSSession -ComputerName $computer -Credential $creds -Port $port -UseSSL -SessionOption $o
if(-not $s){
    Write-Output "could not create pssession object! Cannot continue"
    exit 1
}
$items | Copy-Item -ToSession $s -Destination "F:\Releases\$dropName" -Force -Confirm:$false