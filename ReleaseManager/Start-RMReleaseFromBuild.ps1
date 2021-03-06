<#
    .Description
        Use this example at your own risk.
        This file is inteded to demonstrate, how to intitiate a Release Manager 2015 release, from TFS new powershell build system, targeting SharePoint farm solution deployment.
        The script has not been tested, and likely has errors! I no longer have access to a TFS/RM environment to test it. However it is based off a script I wrote, that is being used to deploy 100+ SharePoint farm solutions to multiple environments.
        Since I wrote this script, more variables have been added that may simplify this. Check out the latest ones here https://msdn.microsoft.com/en-us/library/vs/alm/build/scripts/variables
        It is also worth noting, as of TFS 2015 Update 2, Release Manager will no longer be a seperate product (https://www.visualstudio.com/en-us/news/tfs2015-update2-vs.aspx#newrmtfs) so this script may not be neccessery.
#>
param([string]$teamProject = $env:BUILD_REPOSITORY_NAME,
[string]$buildDefinition = $env:BUILD_BUILDDEFINITIONNAME,
[string]$buildNumber = $env:BUILD_BUILDNUMBER,
[string]$props,
[string]$projectName = $null,
[string]$targetStageName = $null,
[string]$releasePath = $null,
[string]$teamProjectCollectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
[string]$branch = $env:BUILD_SOURCEBRANCHNAME,
[string]$rmServerWithPort = $null,
[string]$teamFoundationServerUrl = $env:TF_BUILD_COLLECTIONURI,
[string]$buildDrop = $env:BUILD_ARTIFACTSTAGINGDIRECTORY)

function Get-StageId(){
    #use the folling query to lookup all release paths, then get the stage id for the item with a matching release path name
    [xml]$releaseDefinitions = Invoke-RestMethod -Credential $cred -Uri $releaseDefinitionService -Method Post
    $element = $releaseDefinitions.SelectNodes('//ApplicationVersion') | select ReleasePathId, Name | where {$_.Name -like $releasePath} 
    $pathId = $element.ReleasePathId
    if(-not $pathId){
        log "could not find release pathId"
        exit 1
    }
    $configurationService = "$RMApi/ConfigurationService/GetReleasePath?id=$pathId&api-version=6.0"
    log $configurationService
    [xml]$stages = Invoke-RestMethod -Credential $cred -Uri $configurationService -Method Post
    $enviromentId = $stages.SelectNodes('//ReleasePath/Stages/Stage') | select Id, EnvironmentName | where {$_.EnvironmentName -like $targetStageName}
    return $enviromentId.Id
}

function log([string]$s){
    Write-Verbose $s -Verbose
}

function ValidateParams(){
	if(-not $teamProject){
		log "Team project cannot be null"
		exit 1
	}
	if(-not $buildDefinition){
		log "build definition cannot be null"
		exit 1
	}
	if(-not $buildNumber){
		log "build number cannot be null"
		exit 1
	}
	if(-not $keyString){
		log "key cannot be null"
		exit 1
	}
	if(-not $targetStageName){
		log "Target stage name cannot be null"
		exit 1
	}
	
	if(-not $teamProjectCollectionUrl){
		log "Team Project Collection Url cannot be null"
		exit 1
	}
	if(-not $branch){
		log "source branch cannot be null"
		exit 1
	}
}

function InitiateRelease() {
    log "Executing with the following parameters:`n"
    log "  RMserver Name: $rmServerWithPort"
    log "  Team Foundation Server URL: $teamFoundationServerUrl"
    log "  Team Project: $teamProject"
    log "  Build Definition: $buildDefinition"
    log "  Build Number: $buildNumber"
    log "  Target Stage Name: $targetStageName`n"

    $exitCode = 0

    trap
    {
        $e = $error[0].Exception
        $e.Message
        $e.StackTrace
        if ($exitCode -eq 0) { $exitCode = 1 }
    }

    $scriptPath = Split-Path -Parent (Get-Variable MyInvocation -Scope Script).Value.MyCommand.Path

    Push-Location $scriptPath    
    $definition = [System.Uri]::EscapeDataString($buildDefinition)
    $build = [System.Uri]::EscapeDataString($buildNumber)
    $RMApi = "http://$rmServerWithPort/account/releaseManagementService/_apis/releaseManagement"
    $orchestratorService = "$RMApi/OrchestratorService"
    $releaseDefinitionService = "$RMApi/ReleaseDefinitionService/ListReleaseDefinitions?api-version=6.0"

    log $orchestratorService
    log $releaseDefinitionService
    $stageId = Get-StageId
    if(-not $stageId){
        log "can't find stage id"
        exit 1
    }

    if(-not $props){
        log "creating properties object"
        $bag = New-PropertyBag
        $props = ConvertTo-Json $bag
    }
    
    log "html encode property bag"
    $propertyBag = [System.Uri]::EscapeDataString($props)
    log "write deploy json"
    New-DeployJson
    $cred = [System.Net.CredentialCache]::DefaultCredentials
    $wc = New-Object System.Net.WebClient
    $wc.Credentials = $cred 
    log "Call API"
    $uri = "$orchestratorService/InitiateRelease?releaseTemplateName=$definition&deploymentPropertyBag=$propertyBag&api-version=6.0"
    log "Executing the following API call:`n`n$uri"
    try
    {
        $releaseId = (Invoke-WebRequest -Uri $uri -Credential $cred -Method Post).Content
        log $releaseId
        $url = "$orchestratorService/ReleaseStatus?releaseId=$releaseId"

        $releaseStatus = $wc.DownloadString($url)


        log " done.`n`nRelease scheduled with "+$releaseStatus+" status." 
    }
    catch [System.Exception]
    {
        if ($exitCode -eq 0) { $exitCode = 1 }
        log  "`n$_`n"
    }
    Pop-Location
}

function New-WspObject([string]$itemTitle, [string]$wspName)
{
	$wspObject = New-Object system.Object
	$wspObject | Add-Member -memberType NoteProperty "Title" -Value $itemTitle
	$wspObject | Add-Member -memberType NoteProperty "FileName" -Value $wspName 
	return $wspObject
}

function New-PropertyBag(){
	$releasePathProp = $projectName+":Build"
	$changeSetRangeProp = $projectName+":BuildChangesetRange"
	$partialPath = $branch+"\"+$projectName+"\"+$build
	$propertyBagObject = New-Object system.Object
	$propertyBagObject | Add-Member -memberType NoteProperty "ReleaseName" -Value $build
	$propertyBagObject | Add-Member -memberType NoteProperty "ReleaseBuild" -Value ""
	$propertyBagObject | Add-Member -memberType NoteProperty "ReleaseBuildChangeset" -Value $null
	$propertyBagObject | Add-Member -memberType NoteProperty "TargetStageId" -Value $stageId
	$propertyBagObject | Add-Member -memberType NoteProperty $releasePathProp  -Value $partialPath
	$propertyBagObject | Add-Member -memberType NoteProperty $changeSetRangeProp  -Value "-1,-1"
	return $propertyBagObject
}

function New-DeployJson(){
	$projectId = $null
	$buildId = $null
	$projectsApiUri = "$teamProjectCollectionUrl/_apis/projects/"
	Invoke-RestMethod -Method Get -Uri $projectsApiUri -Credential $cred -OutVariable projectsResponse
	foreach($proj in $projectsResponse[0].value){
		if($proj.name -eq $teamProject){
			$projectId = $proj.id
		}
	}
	if(-not $projectId){
		log "could not find project id from given name" 
	}

	log "got project ID $projectId"
	
	#get the last successful build
	$buildApi = "$teamProjectCollectionUrl/$projectId/_apis/build/Builds?%24top=10&statusFilter=inProgress&definitions=25"
	Invoke-RestMethod -Method Get -Uri $buildApi -Credential $cred -OutVariable buildResponse
	foreach($build in $buildResponse.value){
		log $build.buildNumber
		log $buildNumber
		if($build.buildNumber -eq $buildNumber){
			$buildId = $build.id
			break
		}
	}
	if(-not $buildId){
		log "could not find the last build" 
	}
	
	log "got build ID $buildId"
	
	#get changesets associated with the last build
	$changeSets = @()
	$changesApi = "$teamProjectCollectionUrl/$projectId/_apis/build/builds/$buildId/changes"
	Invoke-RestMethod -Method Get -Uri $changesApi -Credential $cred -OutVariable changesResponse
	foreach($change in $changesResponse[0].value){
	   $changeSets += $change.id.ToLower().Split('c')
	}
	if($changeSets.Count -gt 0){
		log "got changesets"
	}

	$wspToDeploy = @()
	# get the projects that had changes in the changesets so only those projects get deployed
	if($changeSets.Count -gt 0){
		foreach($changeId in $changeSets){
			if(-not $changeId){
				continue
			}
			$changeSetUri = "$teamProjectCollectionUrl/$teamProject/_apis/tfvc/changesets/$($changeId)?maxChangeCount=All"
			log "checking for changes in $changeId | $changeSetUri"
			$webRequest = Invoke-RestMethod -Method Get -Uri $changeSetUri -Credential $cred
					
			foreach($c in $webRequest.changes){
				$part = $c.item.path
                if($part -like "*.sln"){
                    continue
                }
				$parts = $part.Split('/')
				if($parts[1] -eq $teamProject -and $parts[2] -eq $branch){
					$wsp = $parts[3]+".wsp"
					if($wspToDeploy -notcontains $wsp){
					$wspToDeploy += $wsp
					}
				}
			}
		}
	}
	
	if($wspToDeploy.Count -gt 0){
		log "creating wsp answer file"
		$file = @()
		foreach($w in $wspToDeploy){
			$k = New-WspObject $w $w
			$file += $k
		}
		ConvertTo-Json $file | Out-File -FilePath "$buildDrop\WspToDeploy.json" 
	}
	else{
		log "no wsp changes found, will deploy all"
	}
	
}

# confirm all required parameters have been set
ValidateParams

InitiateRelease

if ($exitCode -eq 0)
{
  log "`nThe script completed successfully.`n"
}
else
{
  $err = "Exiting with error: " + $exitCode + "`n"
  log $err
}

exit $exitCode