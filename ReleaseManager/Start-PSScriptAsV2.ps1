<#
    .Description
        This script is for use with release manager 2015 powershell deployment and SharePoint 2010 solutions.
        It is used to launch another powershell script in PowerShell V2, as SharePoint 2010 requires it.
        the $fileName var is set as a configuration on the component within release manager, as such this script cannot be run manually
#>
function log([string]$s){
    Write-Verbose $s -Verbose
}
function LaunchV2([string] $fileName){
	$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo 
	$ProcessInfo.FileName = "powershell.exe" 
	$ProcessInfo.RedirectStandardError = $true 
	$ProcessInfo.RedirectStandardOutput = $true 
	$ProcessInfo.UseShellExecute = $false 
	$ProcessInfo.Arguments = "-Version 2 $fileName"
	$ProcessInfo.Verb = "runas"
	$ProcessInfo.CreateNoWindow = $true;
	$ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
	$Process = New-Object System.Diagnostics.Process 
	$Process.StartInfo = $ProcessInfo 
	$Process.Start() | Out-Null 
	$output = $Process.StandardOutput.ReadToEnd()
	$error = $Process.StandardError.ReadToEnd() 
	$Process.WaitForExit() 
	log $output
	log $error
}
if(-not $fileName){
    log "filename was null"
}else{
    log "Starting $fileName as powershell V2..."
    $fileName = (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)+"\"+$fileName
    LaunchV2 $fileName
}
