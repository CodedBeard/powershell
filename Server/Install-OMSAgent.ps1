<#
    .Synopsis
        Install the OMS agent and run EnableRules.ps1 script that allows network monitoring, and if required installs the root Certificates and .net 4 Framework
    .DESCRIPTION
        Installs the required components and the OMS agent itself. Checks to ensure that the .Net Framework 4 is installed (on servers that don't have it by default) checks that the server OS is 2008 R2 or greater, and checks/installs the required root certificates for the agent to function. Finally it runs Microsofts EnableRules.ps1 script, that opens the required ports for network monitoring to function correctly.
    .PARAMETER Key
        The API key for your OMS workspace, which can be found in the OMS portal
    .PARAMETER WorkSpace
        The Guid for your OMS workspace, which can be found in the OMS portal
    .PARAMETER ComponentsPath
        Path to a network share that the executing machine can access to get the required components. This should contain the following files:
        bc2025.crt - Baltimore CyberTrust Root - Thumbprint: D4DE20D05E66FC53FE1A50882C78DB2852CAE474
        dotNetFx40_Full_x86_x64.exe - .net 4 full installer
        EnableRules.ps1 - Microsoft Script for enabling network monitoring
        MMASetup-AMD64.exe - The OMS agent installer
        msitwww2.crt - Microsoft IT SSL SHA2 - Thumbprint:97EFF3028677894BDD4F9AC53F789BEE5DF4AD86
    .EXAMPLE
        .\Install-OMSAgent.ps1 -Key "dfuhwhoijwh52834u510350423tjjwgogh9w34thg2ui" -WorkSpace "20d4dd92-53cf-41ff-99b0-7acb6c84be2d" -ComponentsPath "\\a-server\share\oms_agent"
#>
param([parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$Key,
      [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()] [string]$WorkSpace,
      [parameter(Mandatory=$true, Position=2)][ValidateNotNullOrEmpty()] [string]$ComponentsPath,
	  [parameter(Mandatory=$false, Position=3)] [bool]$EnableNetworkMonitorRules = $true)
BEGIN{
    #FUNCTIONS START#
    function Import-509Certificate {
        param([String]$certPath,[String]$certRootStore,[String]$certStore)
        $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
        $pfx.import($certPath)
        $store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)
        $store.open("MaxAllowed")
        $store.add($pfx)
        $store.close()
    }

    function Test-Key([string]$path, [string]$key)
    {
        if(!(Test-Path $path)) { return $false }
        if ((Get-ItemProperty $path).$key -eq $null) { return $false }
        return $true
    }

    function Test-Cert([string]$path)
    {
        if(!(Test-Path $path)) { return $false }
        return $true
    }

    function Get-Framework4Installed()
    {
        return Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" "Install"   
    }

    function Get-OMSAgentInstalled()
    {
        return Test-Key "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\APMAgent" "InstallPath"
    }

    function Get-RootCert1(){
        return Test-Cert "cert:\LocalMachine\Root\D4DE20D05E66FC53FE1A50882C78DB2852CAE474"
    }

    function Get-RootCert2(){
        return Test-Cert "cert:\LocalMachine\Root\97EFF3028677894BDD4F9AC53F789BEE5DF4AD86"
    }
    ##FUNCTIONS END##

    if (!(test-path $ComponentsPath)) {
        throw [System.IO.DirectoryNotFoundException] "Could not find the ComponentPath specified: $($ComponentsPath)"
    }
    $tempDir = "$($env:TEMP)\OMS_Agent"
    if (!(Test-Path $tempDir)) {
        $null = New-Item -Path $tempDir -ItemType Directory
    }
    $msCA1 = "bc2025.crt"
    $msCA2 = "msitwww2.crt"
    $agent = "MMASetup-AMD64.exe"
    $net4 = "dotNetFx40_Full_x86_x64.exe"
    $enableScript = "EnableRules.ps1"
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion -lt [version]"6.0.6001.18000") {
        throw [System.Exception] "The agent requires Server 2008 SP1 or greater"
    }
    $cert1Path = Join-Path -Path $tempDir -ChildPath $msCA1
    $cert2Path = Join-Path -Path $tempDir -ChildPath $msCA2
    $agentPath = Join-Path -Path $tempDir -ChildPath $agent
    $netPath = Join-Path -Path $tempDir -ChildPath $net4
    $scriptPath = Join-Path -Path $tempDir -ChildPath $enableScript
}
PROCESS{
    Write-Output "Copying required installation files to: $($tempDir)"
    $null = Copy-Item -Path $ComponentsPath -Destination $env:TEMP -Recurse -Force
    if (!(Get-RootCert1)) {
        Write-Output "Importing Certificate 'Baltimore CyberTrust Root'"
        Import-509Certificate -certPath $cert1Path -certRootStore "LocalMachine" -certStore "Root"
    }else{
        Write-Output "Certificate 'Baltimore CyberTrust Root' already installed"
    }
    if (!(Get-RootCert2)) {
        Write-Output "Importing Certificate 'Microsoft IT SSL SHA2'"
        Import-509Certificate -certPath $cert2Path -certRootStore "LocalMachine" -certStore "Root"    
    }else{
        Write-Output "Certificate 'Microsoft IT SSL SHA2' already installed"
    }
    if (!(Get-Framework4Installed)) {
        if ($osVersion -lt [version]"6.2.9200") {
            Write-Output "Installing .net 4"
            Start-Process -FilePath $netPath -ArgumentList "/Q" -Wait
        }else{
            Write-Output "Server 2012 or greater detected, skipping .net 4 install"
        }
    }else{
        Write-Output ".net 4 already installed"
    }
	if($EnableNetworkMonitorRules -eq $true){
		Write-Output "Enable FireWall rules"
		Invoke-Expression $scriptPath
	}
    if (!(Get-OMSAgentInstalled)) {
        Write-Output "Installing Agent"
        $arguments = "/Q:A /R:N /C:`"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID=$($WorkSpace) OPINSIGHTS_WORKSPACE_KEY=$($Key) AcceptEndUserLicenseAgreement=1`""
        Start-Process -FilePath $agentPath -ArgumentList $arguments -Wait    
    }else{
        Write-Output "OMS agent already installed"
    }
}
END{
    Write-Output "Done! if everything worked 'Microsoft Monitoring Agent' should now appear in control panel."
}