<#
    .Description
        This script was used as part of the build system to create nuget packages for an internal feed, when a build completed successfully.
#>
[CmdletBinding()]
param
(
    # We have to pass this boolean flag as string, we cast it before we use it
    [string]$isCI = 'false',
	[string]$projectName = $null,
	[string]$parentFolderName = $null,
	[string]$useProject = 'false',
	[string]$apiKey = $null,
	[string]$config = $null,
    [string]$source = $null,
    [string]$major = $null,
    [string]$minor = $null
)
if(-not $projectName){
	Write-Verbose "Project name cannot be empty" -Verbose
	exit 1
}
if(-not $apiKey){
	Write-Verbose "apiKey cannot be empty" -Verbose
	exit 1
}
if(-not $source){
	Write-Verbose "source cannot be empty" -Verbose
	exit 1
}
if(-not $major){
	Write-Verbose "major cannot be empty" -Verbose
	exit 1
}
if(-not $minor){
	Write-Verbose "minor cannot be empty" -Verbose
	exit 1
}
if(-not $parentFolderName){
	$parentFolderPath = ".\"	
}
else{
	$parentFolderPath = ".\$parentFolderName\"
}
$isCI = [System.Convert]::ToBoolean($isCI)
$useProject = [System.Convert]::ToBoolean($useProject)
$type = "nuspec"
if($useProject -eq $true){
	$type = "csproj"
}
$start = [datetime]"01/01/2000 00:00"
$end = (get-date)
$build = (New-TimeSpan -Start $start -End $end).Days
$today = [datetime]::Today
$now = [datetime]::Now
$revision = ((New-TimeSpan -Start $today -End $now).TotalSeconds / 2).ToString("0")
$version = "$major.$minor.$build.$revision"
$path = "C:\Program Files (x86)\NuGet\"
$exe = $path + "nuget.exe"
if($config -ne $null -and $config.ToLower() -ne "release"){
	 $version = $version+"-$config"
}
$nuspec = $parentFolderPath+"$projectName.$type"
$package = $parentFolderPath+"$projectName.$version.nupkg"
if($isCi -eq $true){
	
	Write-Verbose $nuspec -Verbose
	Write-Verbose $package -Verbose
	Write-Verbose $version -Verbose	
	
}

&$exe pack $nuspec -version $version -outputdirectory $parentFolderPath
&$exe push $package -source $source -apikey $apiKey