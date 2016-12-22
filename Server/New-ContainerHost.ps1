Configuration New_ContainerHost
{
    param(
        [string[]]$ComputerName="localhost",
        [string]$DockerVersion="1.13.0-dev"
    )
    
    Node $ALLNodes.Where{$true}.NodeName
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $True
        }
        
        WindowsFeature HyperV
        {
            Ensure = "Present" 
            Name = "Hyper-V" # Use the Name property from Get-WindowsFeature
            IncludeAllSubFeature = $true
        }

        WindowsFeature Containers
        {
            Ensure = "Present" 
            Name = "Containers"
            IncludeAllSubFeature = $true
            DependsOn = "[WindowsFeature]HyperV"
        }

        Script InstallDocker
        {
            GetScript = 
            {
         
            }
            TestScript = 
            {
                $pathExists = Test-Path -Path "C:\Program Files\docker"
		if($pathExists)
                {
                    $dockerExists = Test-Path -Path "C:\Program Files\docker\docker.exe"
                    $dockerDemonExists = Test-Path -Path "C:\Program Files\docker\dockerd.exe"
                    $dockerProxyExists = Test-Path -Path "C:\Program Files\docker\docker-proxy.exe"
                }
                
                $exists = ($pathExists -and $dockerExists -and $dockerDemonExists -and $dockerProxyExists)
                return $exists
            }
            SetScript = 
            {
                $url = "https://master.dockerproject.org/windows/amd64/docker-$($using:DockerVersion).zip"
                Write-Verbose $url
                Invoke-WebRequest $url -OutFile "$env:TEMP\docker-$($using:DockerVersion).zip" -UseBasicParsing
                Expand-Archive -Path "$env:TEMP\docker-$($using:DockerVersion).zip" -DestinationPath $env:ProgramFiles
                Start-Process -FilePath "C:\Program Files\docker\dockerd.exe" -ArgumentList "--register-service" -Wait
            }
            DependsOn = "[WindowsFeature]Containers"
        }

        Script InstallDockerCompose
        {
            GetScript = 
            {
                
            }
            TestScript = 
            {
                $dockerComposeExists = Test-Path -Path "C:\Program Files\docker\docker-compose.exe"

                return $dockerComposeExists
            }
            SetScript = 
            {
                Invoke-WebRequest "https://dl.bintray.com/docker-compose/master/docker-compose-Windows-x86_64.exe" -OutFile "$($env:ProgramFiles)\docker\docker-compose.exe" -UseBasicParsing
                
            }
            DependsOn = "[Script]InstallDocker"
        }

        Environment DockerPath
        {
            Ensure = "Present"
            Name = "Path"
            Path = $true
            Value = "C:\Program Files\Docker"
            DependsOn = "[Script]InstallDocker"
        }

        Script CheckForUpdates
        {
            GetScript = 
            {
                
            }
            TestScript = 
            {
                $updatesNeeded = ((Get-WUInstall -WindowsUpdate -ListOnly | Select KB).Count -eq 0)

                return $updatesNeeded
            }
            SetScript = 
            {
                Get-WUInstall -WindowsUpdate -AcceptAll -AutoReboot
            }
            DependsOn = "[Environment]DockerPath"
        }
    }
}

$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = "localhost"                          
            RetryCount = 20              
            RetryIntervalSec = 30            
            PsDscAllowPlainTextPassword = $true            
        }            
    )             
}  

Install-Package -Name PSWindowsUpdate -Confirm:$false -Force

New_ContainerHost -ConfigurationData $ConfigData -ComputerName "localhost" -DockerVersion "1.13.0-dev"

# Make sure that LCM is set to continue configuration after reboot            
Set-DSCLocalConfigurationManager -Path .\New_ContainerHost -Verbose            
            
# Build the domain            
Start-DscConfiguration -Wait -Force -Path .\New_ContainerHost -Verbose       