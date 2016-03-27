<#
    .Description
        This script was written for an early version of the powershell build system released with TFS 2015. If you are using TFS 2015 Update 1 or later, a copy task is already included and should be used instead.
#>
param([string]$files = $null,
[string]$sourceBranch = $null,
[string]$project = $null,
[string]$build = $env:BUILD_BUILDNUMBER,
[string]$buildPath = $env:AGENT_BUILDDIRECTORY,
[string]$isSolution = $false,
[string]$teamProject = $null,
[string]$destination = $null)
if(-not $sourceBranch){
	Write-Verbose "sourceBranch cannot be null" -Verbose
	exit 1
}
if(-not $project){
	Write-Verbose "project cannot be null" -Verbose
	exit 1
}
if(-not $build){
	Write-Verbose "build cannot be null" -Verbose
	exit 1
}
if(-not $buildPath){
	Write-Verbose "buildPath cannot be null" -Verbose
	exit 1
}
if(-not $teamProject){
	Write-Verbose "teamProject cannot be null" -Verbose
	exit 1
}
if(-not $destination){
	Write-Verbose "destination cannot be null" -Verbose
	exit 1
}
$isSolution =  [System.Convert]::ToBoolean($isSolution)
$searchPath = ".\*\bin\*\"
if($isSolution -ne $true){
	$searchPath = ".\bin\*\"
}
Write-Verbose $destination -Verbose
Write-Verbose $buildPath -Verbose
$exits = Test-Path $destination
if($exits -ne $true){
    mkdir $destination
}
$scriptName = $MyInvocation.MyCommand.Name
if(-not $files){
	Get-ChildItem -Path $searchPath  -Recurse | select Name, FullName | where {$_.Name -ne $scriptName} |% { copy-item -Path $_.FullName -Destination $destination -Force -Container}
	Get-ChildItem -Path  $env:BUILD_STAGINGDIRECTORY -Recurse | select Name, FullName | where {$_.Name -like '*.ps1'} |% { copy-item -Path $_.FullName -Destination $destination -Force -Container}
}
else{
	$f = @()
	$f = $files.Split(',')
	foreach($file in $f){
		$file = $file.Trim('"')
		Get-ChildItem -Path  $searchPath -Recurse | select Name, FullName | where{$_.Name -like $file} |% { copy-item -Path $_.FullName -Destination $destinationdest -Force -Container}	
	}
	Get-ChildItem -Path  $env:BUILD_STAGINGDIRECTORY -Recurse | select Name, FullName | where {$_.Name -like '*.ps1'} |% { copy-item -Path $_.FullName -Destination $destination -Force -Container}
}