function Add-BoxstarterModules{
    <#
        .SYNOPSIS 
            Prevents the need to reload powershell session after installing boxstarter
    #>
    $loc = Get-Location
    Invoke-Expression "$env:USERPROFILE\AppData\Roaming\Boxstarter\BoxstarterShell.ps1"
    Set-Location $loc
}

function Add-RequiredTools{
    <#
        .SYNOPSIS 
            Downloads chocolatey and various required packages
        .DESCRIPTION
            Downloads chocolatey and various required packages
        .EXAMPLE
            Add-RequiredTools
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$false, Position=0)][ValidateNotNullOrEmpty()] [string[]]$Tools = ("webpi","webpicmd","webdeploy","dotnet4.6","boxstarter"))
    Log "Confirm chocolatey is installed"
    $ChocolateyExists = (Test-Path "C:\ProgramData\chocolatey\choco.exe")
    if(!($ChocolateyExists)){
        Log "chocolatey is not installed, downloading..."
        (Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')))>$null 2>&1
    }
    foreach($tool in $Tools){
        Log "Confirm $tool is installed"
        cinst $tool -y -f
    }
}

function Confirm-Commit {
    <#
        .SYNOPSIS 
            Simple confirmation dialog
    #>
	if ($script:WhatIf) {
		Log "(Not committing this operation)"
		return $false;
	}
	elseif ($script:Confirm) {
		Log "Are you sure you want to perform this action?"
		while ($true) {
			$answer = Read-Host "[Y] Yes [A] Yes to All [N] No [L] No to all"
			switch ($answer) {
				"Y" { return $true; }
				"A" { $script:Confirm = $false; return $true; }
				"N" { return $false; }
				"L" { $script:WhatIf = $true; return $false; }
			}
		}
	}
	else {
		Log "(Committing this operation)"
		return $true;
	}
}

function ConvertFrom-Json20{
    <#
        .SYNOPSIS 
            Convert from json that works with .net 2
        .EXAMPLE
             ConvertFrom-Json20 $someJsonObject
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [object] $jsonObject)
    add-type -assembly system.web.extensions 
    $ps_js=new-object system.web.script.serialization.javascriptSerializer
    return $ps_js.DeserializeObject($jsonObject) 
}

function Disable-AutoDetectProxy{
    <#
        .SYNOPSIS 
            Disables proxy autodetect
    #>
    # Read connection settings from Internet Explorer.
    $regKeyPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\"
    $conSet = $(Get-ItemProperty $regKeyPath).DefaultConnectionSettings

    # Index into DefaultConnectionSettings where the relevant flag resides.
    $flagIndex = 8

    # Bit inside the relevant flag which indicates whether or not to enable automatically detect proxy settings.
    $autoProxyFlag = 8

    if ($($conSet[$flagIndex] -band $autoProxyFlag) -eq $autoProxyFlag)
    {
        # 'Automatically detect proxy settings' was enabled, adding one disables it.
        Log "Disabling 'Automatically detect proxy settings'."
        $mask = -bnot $autoProxyFlag
        $conSet[$flagIndex] = $conSet[$flagIndex] -band $mask
        $conSet[4]++
        Set-ItemProperty -Path $regKeyPath -Name DefaultConnectionSettings -Value $conSet
    }
    
    $conSet = $(Get-ItemProperty $regKeyPath).DefaultConnectionSettings
    if ($($conSet[$flagIndex] -band $autoProxyFlag) -ne $autoProxyFlag)
    {
    	Log "'Automatically detect proxy settings' is already disabled."
    }
}

function Disable-LoopbackCheck{
    <#
        .SYNOPSIS 
            Disables windows loopback check
        .DESCRIPTION
            Disables windows loopback check. This should only be used on development servers experiancing issues with local site authentication
        .EXAMPLE
            Disable-LoopbackCheck
    #>
    $reg = Get-ItemProperty -Name "DisableLoopbackCheck" -Path "HKLM:\System\CurrentControlSet\Control\Lsa"
    if(-not $reg){
        New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name "DisableLoopbackCheck" -Value "1" -PropertyType dword
    }
}

function Enable-IISKernalModeAuthentication{
    <#
        .SYNOPSIS 
            Enable Kernal mode auth on CA, required for Kerberos
        .DESCRIPTION
            Enable Kernal mode auth on CA, required for Kerberos
        .EXAMPLE
            Enable-IISKernalModeAuthentication
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$SiteName)
    $inet = "$($env:windir)\system32\inetsrv"
    & "$($inet)\appcmd.exe" set config "$($SiteName)" -section:system.webServer/security/authentication/windowsAuthentication /useKernelMode:"True"  /commit:apphost
}

function Get-WebExists (){
    <#
        .SYNOPSIS 
            Returns true if a website or webapplication exists with the same name
        .DESCRIPTION
            Returns true if a website or webapplication exists with the same name
        .EXAMPLE
            Get-WebExists "Default Web Site"
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$false, Position=0)][ValidateNotNullOrEmpty()] [string]$SiteName)
    Import-Module WebAdministration -ErrorAction Stop
    $webSites = Get-Website | Where-Object { $_.name -like $SiteName}
    if(!(-not $webSites)){
        return $true
    }
     
    $list = @()
    foreach ($webapp in get-childitem IIS:\AppPools\)
    {
        $name = "IIS:\AppPools\" + $webapp.name
        $item = @{}
 
        $item.WebAppName = $webapp.name
        $item.Version = (Get-ItemProperty $name managedRuntimeVersion).Value
        $item.State = (Get-WebAppPoolState -Name $webapp.name).Value
        $item.UserIdentityType = $webapp.processModel.identityType
        $item.Username = $webapp.processModel.userName
        $item.Password = $webapp.processModel.password
 
        $obj = New-Object PSObject -Property $item
        $list += $obj
    }
    $exists = $list | Where-Object {$_.WebAppName -like $SiteName}
    return !(-not $exists) 
}

function Get-IsServerCore{
    <#
        .SYNOPSIS 
            Check if running on server core. intended for Server 2008
        .EXAMPLE
            Get-IsServerCore            
    #>
    [cmdletbinding()]
    [OutputType([bool])]
    param()
    return ((Test-Path "$env:windir\explorer.exe") -eq $false)
}

function Get-ObjectFromJsonFile{
    <#
        .SYNOPSIS 
            Get a json object from a file
        .DESCRIPTION
            Get a json object from a file
        .EXAMPLE
            $settings = Get-ObjectFromJsonFile -FilePath "c:\temp\example-answerfile.json"
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)][ValidateNotNullOrEmpty()][string]$FilePath)
    if(!(Test-Path -Path $FilePath)){
        throw [System.IO.FileNotFoundException] "Cannot find the Answer File: $FilePath"
    }
    return (Get-Content $FilePath | Out-String | ConvertFrom-Json)
}

function Get-UserName() {
    <#
        .SYNOPSIS 
            Gets the SAMAccountName from A fully qualififed login name
        .EXAMPLE
             Get-UserName "NT_DEV\john.smith"
             "john.smith"
        .EXAMPLE
             Get-UserName "i:0?.t|saml provider|john.smith"
             "john.smith"
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$LoginName)
	if ($LoginName.Contains('\')) {
		return $LoginName.SubString($LoginName.LastIndexOf('\') + 1);
	} else {
		return $LoginName.SubString($LoginName.LastIndexOf('|') + 1);
	}
}

function Get-PowershellModule{
    <#
        .SYNOPSIS 
            Downloads a Zip file from on-prem TFS which contains a set of powershel modules, and imports to current session.
    #>
    param([parameter(Mandatory=$false, Position=0)][ValidateNotNullOrEmpty()] [string] $Url,
    [parameter(Mandatory=$false, Position=1)][ValidateNotNullOrEmpty()] [string] $ZipExe = "C:\Program Files\7-Zip\7z.exe")
    
    $templatePath = Get-ZipFileFromTFS -Url $Url -ZipExe $ZipExe
    Get-ChildItem -Path $templatePath -Recurse -Force -Include *.psm1 |ForEach-Object {Import-Module $_.FullName -ErrorAction SilentlyContinue}
}

function Get-ZipFileFromTFS{
    <#
    .SYNOPSIS 
        Downloads and extracts files from source control
    .DESCRIPTION
        Downloads and extracts files from source control
    .EXAMPLE
        Get-ZipFileFromTFS
    #>
    param([parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string] $Url,
    [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()] [string] $ZipExe,
    [parameter(Mandatory=$false, Position=2)][ValidateNotNullOrEmpty()] [pscredential] $Credentials = (Get-Credential),
    [parameter(Mandatory=$false, Position=3)][ValidateNotNullOrEmpty()] [string] $ProxyAddress)
    $tempDir = Join-Path $env:TEMP "TFS"
    if (![System.IO.Directory]::Exists($tempDir)) {[System.IO.Directory]::CreateDirectory($tempDir)}
    $file = Join-Path $tempDir "TFS-$(get-date -Format yyyy-MM-dd-hh-mm-ss).zip"
    $downloader = new-object System.Net.WebClient
    $downloader.Credentials = $Credentials
    if (!(-not $ProxyAddress)) {
        $proxy = New-Object System.Net.WebProxy($proxyAddress)
        $proxy.Credentials = $ProxyAddress
        $downloader.Proxy = $proxy
    }
    $downloader.DownloadFile($Url, $file)
    # unzip the package
    Log "Extracting $file to $tempDir..."
    $currentDir = Get-Location
    Set-Location $tempDir
    $result = & $ZipPath x $file -o* 
    Set-Location $currentDir
    return "$tempDir"

}

function Install-CertificateFromCA(){
    <#
        .SYNOPSIS 
            Request a new certificate from the Active Directory Certificate Authority. Returns the thumbprint of the new certificate
        .DESCRIPTION
            Request a new certificate from the Active Directory Certificate Authority
        .EXAMPLE
            Install-CertificateFromCA
    #>
    [cmdletbinding()]
    [OutputType([string])]
    param([Parameter(Mandatory=$false, Position=0)][ValidateNotNullOrEmpty()] [string[]]$DnsNames = ("LocalHost","localhost.$($DomainName)","$($env:COMPUTERNAME)","$($env:COMPUTERNAME).$($DomainName)"),
    [Parameter(Mandatory=$false, Position=1)][ValidateNotNullOrEmpty()] [string]$Template = "WebServer2008",
    [Parameter(Mandatory=$false, Position=2)][ValidateNotNullOrEmpty()] [string]$Store = "cert:\LocalMachine\My",
    [Parameter(Mandatory=$false, Position=3)][ValidateNotNullOrEmpty()] [string]$DomainName = "dev.local")
    $c = Get-Certificate -Template $Template -DnsName $DnsNames -CertStoreLocation $Store
    $certs = Get-ChildItem cert:\localmachine\my
    if(-not $certs){
        throw [system.argumentexception] "Could not find any local certificates"
    }
        
    foreach($cert in $certs){
        $as = $false
        $bs = $false
        foreach($dns in $cert.DnsNameList){
            if($dns.Punycode -like "$ServerName*"){
                $as = $true
            }

            if($dns.Punycode -like "localhost*"){
                $bs = $true
            }
        }

        if($as -and $bs){
            return $($cert.Thumbprint)
        }
    }
}

function New-RebootTask{
    <#
        .SYNOPSIS 
            Creates a task to relaunch the script after a reboot
        .DESCRIPTION
            Creates a task to relaunch the script after a reboot
        .EXAMPLE
            New-RebootTask
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$ScriptLocation,
    [Parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()] [string]$AnswerFileLocation,
    [Parameter(Mandatory=$false, Position=2)][ValidateNotNullOrEmpty()] [string]$TaskName = "Continue-AfterReboot")
    
    $userName = "$([Environment]::UserDomainName)\$([Environment]::UserName)"
    $principal =  New-ScheduledTaskPrincipal -UserId "$userName" -RunLevel Highest -LogonType Interactive
    $trigger = New-ScheduledTaskTrigger -User $userName -AtLogOn
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-executionPolicy bypass -noexit -file `"$($ScriptLocation)`" `"$($AnswerFileLocation)`""
    $settings = New-ScheduledTaskSettingsSet
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
    Register-ScheduledTask $TaskName -InputObject $task
}

function Remove-RebootTask{
    <#
        .SYNOPSIS 
            Creates a task to relaunch the script after a reboot
        .DESCRIPTION
            Creates a task to relaunch the script after a reboot
        .EXAMPLE
            New-RebootTask
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$false, Position=0)][ValidateNotNullOrEmpty()] [string]$TaskName = "Continue-AfterReboot")
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if(!(-not $t)){
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
}

function Set-AzureStorageEmulatorConfig{
    <#
        .SYNOPSIS 
            Configured the old Azure storage emulator, doesn't work with latest version.
    #>
    $storage = "C:\Program Files (x86)\Microsoft SDKs\Azure\Storage Emulator"
    Start-Process -FilePath "$storage\AzureStorageEmulator.exe" -ArgumentList "stop"
    $storageConfig = "C:\Program Files (x86)\Microsoft SDKs\Azure\Storage Emulator\AzureStorageEmulator.exe.config"
    $xml = [xml](Get-Content $storageConfig)
    $ipAddress = ((Get-NetIPAddress).IPv4Address | Where-Object {$_ -notlike "127.*"} | Select-Object -first 1 )
    foreach($nd in $xml.configuration.StorageEmulatorConfig.services.ChildNodes.GetEnumerator()){
    
        switch($nd.name){
            "Blob"{ $nd.url = "http://$($ipAddress):81/"}
            "Queue"{$nd.url = "http://$($ipAddress):82/"}
            "Table"{$nd.url = "http://$($ipAddress):83/"}
        }
        Write-Host $nd.name $nd.url
    }
    $xml.Save($storageConfig)
    Start-Process -FilePath "$storage\AzureStorageEmulator.exe" -ArgumentList "start"
}

function Set-AzureStorageEmualtorFirewallRules{
    <#
        .SYNOPSIS 
            Configured the old Azure storage emulator, doesn't work with latest version.
    #>
    netsh advfirewall firewall add rule name="Open Port 81" dir=in action=allow protocol=TCP localport=81
    netsh advfirewall firewall add rule name="Open Port 82" dir=in action=allow protocol=TCP localport=82
    netsh advfirewall firewall add rule name="Open Port 83" dir=in action=allow protocol=TCP localport=83
}

function Set-HostFileEntries{
    <#
        .SYNOPSIS 
            Updates the host file with required Host Entries
        .DESCRIPTION
            Updates the host file with required Host Entries
        .EXAMPLE
            Set-HostFileEntries
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$false, Position=0)][ValidateNotNullOrEmpty()] [string]$ServerName = "$($env:COMPUTERNAME)",
    [Parameter(Mandatory=$false, Position=1)][ValidateNotNullOrEmpty()] [hashtable]$HostFileEntries)
    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    
    [regex]$r="\S"
    [regex]$validHostName = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$"
    #strip out any lines beginning with # and blank lines
    $HostsData = Get-Content $hostsPath | Where-Object {
        (($r.Match($_)).value -ne "#") -and ($_ -notmatch "^\s+$") -and ($_.Length -gt 0)
        }
    $entries = @{}
    
    foreach($entry in $HostFileEntries.GetEnumerator()){
        if(($($entry.Value) -as [ipaddress]) -and ($entry.Name -match $validHostName)){
            $entries.Add($entry.Name,$entry.Value)
        }
        else{
            throw [system.argumentexception] "Invalid host name or ip address specified"
        }
    }
        
    
    $missingEntries = @{}
    $missingEntries.Clear()
    foreach($entry in $entries.GetEnumerator()){
        $found = $false
        foreach($h in $HostsData){
            if(($h -match "$($entry.Value)[\s\t]$($entry.Name)")){
             $found = $true
            }
        }
        if($found -ne $true){
            $missingEntries.Add($entry.Name, $entry.Value)
        }
    }
    if($missingEntries.Count -gt 0){
    #ensure new entries are on a new row
        "`n`r" | Out-File -encoding ASCII -append $hostsPath
        foreach($m in $missingEntries.GetEnumerator()){
            Log "Could not find required host file entry $($m.Name)! Creating" 
            "$($m.Value)`t$($m.Name)`n" | Out-File -encoding ASCII -append $hostsPath
        }
    }
    else{
        Log "All host entries are already present!"
    }
}

function Test-RebootNeeded{
    <#
        .SYNOPSIS 
            Returns true if this server needs rebooting
        .DESCRIPTION
            Returns true if this server needs rebooting
        .EXAMPLE
             Test-RebootNeeded
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    Param()
        Process
        {
        $NeedsReboot = $false

        #Windows Update
        $WURegKey = get-item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
        if ($WURegKey.Property -contains "RebootRequired") {$NeedsReboot = $true}
        #Component Based Servicing
        $CBSRegkey = get-item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing"
        if ($CBSRegkey.Property -contains "RebootRequired") {$NeedsReboot = $true}
        #Pending File Rename Operations
        $PFRORegkey = get-item "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\FileRenameOperations"
        if ($PFRORegkey.Property) {$NeedsReboot = $true}
        return $NeedsReboot
        }
}

function Write-ToLogFile{
    <#
        .SYNOPSIS 
            Simple file logging
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$Message,
    [Parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()] [string]$LogFileName,
    [Parameter(Mandatory=$false, Position=2)][ValidateNotNullOrEmpty()] [ValidateSet('INFO', 'INSTALL', 'UNINSTALL', 'ADD', 'REMOVE', 'ERROR', 'COPY')] [string]$Level = "INFO")
    $path = [System.IO.Path]::GetDirectoryName($LogFileName)
    if(!(Test-Path -Path $path)){
        mkdir $path
    }
    $Date = [string](Get-Date -format "yyyy-MM-dd HH:mm:ss")
    $Message = "[$($Date)][$($Level)] $Message"
    Write-Verbose $Message -Verbose
    Write-Output $Message | Out-File $LogFileName -append
}

function Write-ToHost{
    <#
        .SYNOPSIS 
            Simple console logging with timestamps and colours
    #>
    [cmdletbinding()]
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$Message,
    [Parameter(Mandatory=$false, Position=1)][ValidateNotNullOrEmpty()] [ValidateSet('INFO', 'INSTALL', 'UNINSTALL', 'ADD', 'REMOVE', 'ERROR', 'COPY', 'SUCCESS', 'WARNING', 'OTHER')] [string]$Level = "INFO")
    $Date = [string](Get-Date -format "yyyy-MM-dd HH:mm:ss")
    $Message = "[$($Date)][$($Level)] $Message"
    switch($Level){
        "INFO" {
            Write-Host $Message -ForegroundColor DarkGray
        }
        "INSTALL" {
            Write-Host $Message -ForegroundColor Green
        }
        "ADD" {
            Write-Host $Message -ForegroundColor Green
        }
        "UNINSTALL" {
            Write-Host $Message -ForegroundColor Yellow
        }
        "REMOVE" {
            Write-Host $Message -ForegroundColor Yellow
        }
        "ERROR" {
            Write-Host $Message -ForegroundColor Red
        }
        "COPY" {
            Write-Host $Message -ForegroundColor Green
        }
        "SUCCESS" {
            Write-Host $Message -ForegroundColor Green
        }
        "WARNING" {
            Write-Host $Message -ForegroundColor Yellow
        }
        "OTHER" {
            Write-Host $Message -ForegroundColor DarkMagenta
        }
    }
    
    
}

function Log{
    param ([string]$msg,[ValidateSet('INFO', 'INSTALL', 'UNINSTALL', 'ADD', 'REMOVE', 'ERROR', 'COPY', 'SUCCESS', 'WARNING', 'OTHER')] [string]$level = "INFO")
    Write-ToHost $msg $level
}