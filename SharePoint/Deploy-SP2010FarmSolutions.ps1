<#
    .Description
        This script was used for deploying all farm solutions in a specified folder, or from a Json answer file.
#>
param
(
    [Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string]$webAppUrl = $null,
    [Parameter(Mandatory=$false, Position=1)][ValidateNotNullOrEmpty()][string]$WSP_Folder = $null
)
function log([string]$s){
    Write-Verbose "$s`n" -Verbose
}

function ConvertFrom-Json20([object] $js){ 
    add-type -assembly system.web.extensions 
    $ps_js=new-object system.web.script.serialization.javascriptSerializer
    return $ps_js.DeserializeObject($js) 
}

$items = $null
$installTag = "[INSTALL]"
$uninstallTag = "[UNINSTALL]"
$addTag = "[ADD]"
$removeTag = "[REMOVE]"
$infoTag = "[INFO]"
$errorTag = "[ERROR]"
$snapin = Get-PSSnapin | Where-Object { $_.Name -eq "Microsoft.SharePoint.Powershell" }
if ($snapin -eq $null) {
    log "[INIT] Loading SharePoint Powershell Snapin"
    Add-PSSnapin "Microsoft.SharePoint.Powershell"
}

if(-not $WSP_Folder){
    $WSP_Folder = Split-Path -Parent $MyInvocation.MyCommand.Path
}
cls
if(Test-Path "$WSP_Folder\WspToDeploy.json"){
	log "Found WspToDeploy.json, reading items to deploy"
	$file = Get-Content "$WSP_Folder\WspToDeploy.json"
	$items = ConvertFrom-Json20 $file
}

if(-not $items){
	if(Test-Path ".\WspToDeploy.json"){
	log "Found WspToDeploy.json, reading items to deploy"
	$file = Get-Content ".\WspToDeploy.json"
	$items = ConvertFrom-Json20 $file
	}
}

function WaitForJobToFinish([string]$Identity)
{   
    log "$infoTag Checking for running job $Identity"
	while ((Get-SPSolution $Identity).JobExists) {
        log "$infoTag Waiting for $Identity..."
        sleep 5
	}
    log "$infoTag...Done!"    
}

function RetractSolution([string]$Identity, [string]$web_application)
{
    log "$uninstallTag Uninstalling $Identity"    
    
    $solution = Get-SPSolution | where { $_.Name -match $Identity }
    if($solution.Deployed)
    {
        log "$uninstallTag $Identity deployed retracting"
        if($solution.ContainsWebApplicationResource)
        {    
            log "$uninstallTag Uninstalling $Identity from all web applications"            
            Uninstall-SPSolution -identity $Identity -AllWebApplications -Confirm:$false -ErrorVariable uninstallSolution
        }
        else
        {
            log "$uninstallTag No web application resources Uninstalling $Identity"            
            Uninstall-SPSolution -identity $Identity -Confirm:$false -ErrorVariable uninstallSolution
        }
        if ($uninstallSolution.Count -ne 0)
	    {
		    log "$uninstallTag Retracting $Identity failed. $uninstallSolution"
			$exitCode++
			return
	    }
       
		WaitForJobToFinish $Identity
    }
    
    log $removeTag +"Removing solution:" +$Identity
    Remove-SPSolution -Identity $Identity -Force -Confirm:$false -ErrorVariable removeSolution
    if ($removeSolution.Count -ne 0)
	{
		log "$errorTag $removeTag Removing $Identity failed."
        $exitCode++
	}
    else
    {
        log "$removeTag...Done!"
    }

}

function DeploySolution([string]$Path, [string]$Identity, [string]$web_application)
{
    log "$addTag Adding solution:$Identity" 
    Add-SPSolution $Path -ErrorVariable addSolution
    if ($addSolution.Count -ne 0){
        log "$errorTag $addTag Add $Identity failed."
        $exitCode++
        return
	}
    else
    {
        log "$addTag...Done!"
    }

    log "$installTag Does $Identity contain any web application-specific resources to deploy?"
    $solution = Get-SPSolution | where { $_.Name -match $Identity }

    if($solution.ContainsWebApplicationResource)
    {
        log "$installTag...Yes!"
		if(-not $web_application){
			log "$installTag Installing $Identity for $webAppUrl web application...... Read from farm"    
	        Install-SPSolution -Identity $Identity -WebApplication $webAppUrl -GACDeployment -Force -ErrorVariable installSolution
		}
		else{
	        log "$installTag Installing $Identity for $web_application web application"    
	        Install-SPSolution -Identity $Identity -WebApplication $web_application -GACDeployment -Force -ErrorVariable installSolution
		}
    }
    else
    {
        log "$installTag...No!"        
        log "$installTag Globally deploying $Identity"    
        Install-SPSolution -Identity $Identity -GACDeployment -Force -ErrorVariable installSolution
    }
	if ($installSolution.Count -ne 0)
	{
		log "$errorTag $installTag Installing $Identity failed"
		$exitCode++
		return
	}
    else
    {
        log "$installTag...Done!"
    }

    WaitForJobToFinish $Identity
}

function DeployWsp([string]$WSP_FileName, [string]$WSP_FilePath)
{
	$identity = $WSP_FileName
	$path = $WSP_FilePath
	log "$infoTag ----------------------------------------"
	log "$infoTag Installing $Identity"
	log "$infoTag Determining if $Identity is already installed"

	$isInstalled = Get-SPSolution | where { $_.Name -eq $identity }
	if ($isInstalled)
	{
	    log "$infoTag...Yes!"
	    (RetractSolution $identity $WebApp)
	    (DeploySolution $path $identity $WebApp)
	}
	else
	{
	    log "$infoTag...No!"
	    (DeploySolution $path $identity $WebApp)
	}

	log "$infoTag Installation and deployment of $Identity"
	log "...Done!"
}

if(-not $items){
	foreach($item in Get-ChildItem -Path $WSP_Folder){
		if($item -ne $null -and $item.Extension -eq ".wsp"){
			(DeployWsp $item.Name $item.FullName)
		}
	}
}else{
	$list = @()
	foreach($it in $items){
		$list += $it.FileName
	}
	$wsps = Get-ChildItem -Path $WSP_Folder | where { $list -contains $_.Name } 
	foreach($item in $wsps){
		if($item -ne $null -and $item.Extension -eq ".wsp"){
			(DeployWsp $item.Name $item.FullName)
		}
	}
}

log "Checking for new features"
Install-SPFeature -ScanForFeatures

if ($exitCode -gt 0){
	log "$errorTag Operation failed with error code $exitCode."
}else{
    log "All solutions deployed successfully"
}
	
