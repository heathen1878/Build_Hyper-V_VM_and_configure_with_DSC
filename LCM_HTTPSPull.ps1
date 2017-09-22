[DSCLocalConfigurationManager()]
Configuration LCM_HTTPSPULL {
    
    Param
        (
            [Parameter(Mandatory=$true)]
            [string[]]$ComputerName,

            [Parameter(Mandatory=$true)]
            [string]$guid

    )  
                	
	Node $ComputerName {
	
		Settings {
		
			AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyAndAutoCorrect'
			RefreshMode = 'Pull'
			ConfigurationID = $guid
            }

            ConfigurationRepositoryWeb DSCHTTPS {
                ServerURL = 'https://dscpull.dsc.local/PSDSCPullServer.svc'
                CertificateID = '8591865AE66C235E0D50166C8003DC547ED0831D'
                AllowUnsecureConnection = $False
            }
	}
}

# Computer list 
$ComputerName='Computer01.dsc.local'

# Create Guid for the computers
$guid=[guid]::NewGuid()

# Create the Computer.Meta.Mof in folder
LCM_HTTPSPULL -ComputerName $ComputerName -Guid $guid -OutputPath 'C:\Users\DominicClayton\onedrive\documents\Scripting\Powershell\Desired State Configuration\'
