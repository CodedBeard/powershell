function Start-DotNetPublish(){
    <#
    .SYNOPSIS 
        Publish a DotNet App
    .DESCRIPTION
        Uses the new DotNet CLI to publish the specified app as a nuget package
    .EXAMPLE
        Import-QSPFarmProperties
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$Source,
    [Parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()] [string]$OutPutDirectory,
    [Parameter(Mandatory=$false, Position=2)][ValidateNotNullOrEmpty()] [string]$Configuration = "Release",
    [Parameter(Mandatory=$false, Position=3)][ValidateNotNullOrEmpty()] [string]$Runtime = "dnx-clr-win-x64.1.0.0-rc1-update1",
    [Parameter(Mandatory=$false, Position=4)][ValidateNotNullOrEmpty()] [string]$WorkingDirectory = "$($env:TEMP)\appcode-$(Get-Random)-$([DateTime]::Now.ToString('dd-MM-yyyy-HH-mm-ss'))",
    [Parameter(Mandatory=$false, Position=5)][ValidateNotNullOrEmpty()] [string]$DotNetEXE = "$($env:LOCALAPPDATA)\Microsoft\dotnet\cli\dotnet.exe",
    [Parameter(Mandatory=$false, Position=6)][ValidateNotNullOrEmpty()] [string]$WebDeployEXE = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe")
    & $DotNetEXE publish $Source --configuration $Configuration -b $WorkingDirectory #--runtime $Runtime --framework netstandard
    & $WebDeployEXE -source:contentPath=$WorkingDirectory -dest:contentPath=$OutPutDirectory -verb:sync -retryAttempts:2 -disablerule:BackupRule    
}

