param([ValidateNotNullOrEmpty()][string]$RootPath = $env:SYSTEMDRIVE)
Configuration PullServer {
  param([ValidateNotNullOrEmpty()][string]$RootPath = $env:SYSTEMDRIVE)
Import-DscResource -ModuleName xPSDesiredStateConfiguration

        # Load the Windows Server DSC Service feature
        WindowsFeature DSCServiceFeature
        {
          Ensure = 'Present'
          Name = 'DSC-Service'
        }

        # Use the DSC Resource to simplify deployment of the web service
        xDSCWebService PSDSCPullServer
        {
          Ensure = 'Present'
          EndpointName = 'PSDSCPullServer'
          Port = 8080
          PhysicalPath = "$env:SYSTEMDRIVE\inetpub\wwwroot\PSDSCPullServer"
          CertificateThumbPrint = 'AllowUnencryptedTraffic'
          ModulePath = "$RootPath\DSC\WindowsPowerShell\DscService\Modules"
          ConfigurationPath = "$RootPath\DSC\WindowsPowerShell\DscService\Configuration"
          State = 'Started'
          DependsOn = '[WindowsFeature]DSCServiceFeature'
          UseSecurityBestPractices = $false
        }
}
PullServer -OutputPath 'C:\PullServerConfig\' -RootPath $RootPath
Start-DscConfiguration -Wait -Force -Verbose -Path 'C:\PullServerConfig\'