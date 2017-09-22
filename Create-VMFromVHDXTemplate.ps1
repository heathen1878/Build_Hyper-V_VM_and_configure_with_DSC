<# 
Create a virtual machine from the VHDX files available on the server.
Use the master unattend.xml file and replace placeholders with actual values
Inject the unattend.xml into the VHDX file copy.
Inject a DSC pull MOF into the VHDX copy to pull configuration from the pull server

This script is dependent on the PowerShell module DomsFunctions.
#>

### Variables ###
Set-Variable MasterUnattendXML -Value '.\master-unattend-template.xml' -Option Constant
Set-Variable WorkingDirectory -Value '.\VHDXWorkingDirectory' -Option Constant
Set-Variable DSCWorkingDirectory -Value '.\DSCWorkingDirectory' -Option Constant
Set-Variable VHDXDirectory -Value '.\VHDXs' -Option Constant
Set-Variable Guid -Value "6848ecd1-43db-46ad-92ca-0609c47278e4" -Option Constant # This probably needs to be a parameter or variable which is defined by the user.

DomCheck-Directory -sFolderPath $WorkingDirectory

[bool]$Validator = $false

While (!$Validator) {

    ### Populate variables by prompting the end user for information.
    [string]$ComputerName = Read-Host -Prompt "Please enter the computers NETBIOS name"
    $Validator = DomCheck-ComputerName -sComputerName $ComputerName

}

#Reset validator
[bool]$Validator = $false

while (!$Validator) {

    [string]$RegOrg = Read-Host -Prompt "Please enter the organisation name"
    $Validator = DomCheck-String -sString $RegOrg

}

#Reset validator
[bool]$Validator = $false

while (!$Validator) {

    [string]$RegOwner = Read-Host -Prompt "Please enter the owner"
    $Validator = DomCheck-String -sString $RegOwner

}

#Reset validator
[bool]$Validator = $false

while (!$Validator) {

    [System.Collections.ArrayList]$TimesZones = Get-Content 'C:\Image Deployment\AvailableTimeZones.txt'
    [String]$TimeZone = Read-Host -Prompt "Please enter a valid timezone; refer to tzlist /l for valid timezones."
    $TimesZones | % {
    
        If ($TimeZone -match $_){
            
            $validator = $true
            break;

        }
        Else {

            $validator = $false
        
        }
    }
}

#Reset validator
[bool]$Validator = $false

while (!$Validator) {

    $AdminPassword = Read-Host -Prompt "Please assign the administrator password ensuring it is complex" -AsSecureString
    $Validator = DomCheck-Password -ssPassword $AdminPassword   

}

# Prompt for the netBIOS domain name
[string]$NetBIOSDomainName = Read-Host -Prompt "What is the NetBIOS name of the domain?"

# Prompt for the domain FQDN
[string]$FQDN = Read-Host -Prompt "What is the domain FQDN?"

# Prompt for the OU DN
[string]$ouDN = Read-Host "What is the DN of the OU where the computer object should be created?"

# Prompt for the username of the user with privileges to join the domain
[string]$djoinUser = Read-Host -Prompt "Who has the required privilege to join the computer to the domain?"

# Prompt for the password of the user above
$djoinPassword = Read-Host -Prompt "Please enter the password for the user specified above?" -AsSecureString

<#
XML file transformation
Load the master unattend XML template into the unattend XML object.
#>
$xmlUnattendFile=New-Object XML
$xmlUnattendFile.Load($MasterUnattendXML)
$xmlUnattendFile.unattend.settings[1].component[0].computerName=$ComputerName
$xmlUnattendFile.unattend.settings[1].component[0].RegisteredOrganization=$RegOrg
$xmlUnattendFile.unattend.settings[1].component[0].RegisteredOwner=$RegOwner
$xmlUnattendFile.unattend.settings[1].component[0].TimeZone=$TimeZone
$xmlUnattendFile.unattend.settings[0].component[1].UserAccounts.AdministratorPassword.Value=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)) 
$xmlUnattendFile.unattend.settings[1].component[1].Identification.Credentials.Domain=$NetBIOSDomainName
$xmlUnattendFile.unattend.settings[1].component[1].Identification.Credentials.Password=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($djoinPassword))
$xmlUnattendFile.unattend.settings[1].component[1].Identification.Credentials.Username=$djoinUser
$xmlUnattendFile.unattend.settings[1].component[1].Identification.JoinDomain=$FQDN
$xmlUnattendFile.unattend.settings[1].component[1].Identification.MachineObjectOU=$ouDN

<# 
Save the XML file into the working directory. At this point the password are unencrypted but this file
will be deleted once it has been injected into the VHD
#>
$xmlUnattendXML=$WorkingDirectory+"\"+$ComputerName+".xml"
$xmlUnattendFile.save($xmlUnattendXML)

<#
Create a mof file for the virtual machine to utilise the DSC pull server
#>
DomDsc-LCM-HTTPSPULL -ComputerName $ComputerName -Guid $guid -OutputPath $DSCWorkingDirectory

Rename-Item -Path (-join ($DSCWorkingDirectory,"\",$ComputerName,".meta.mof")) -NewName (-join ($DSCWorkingDirectory,"\metaconfig.mof")) -Force -Confirm:$false

<#
Create the virtual machine using a template VHDX.
Import the unattend.xml
#>

# Prompt for the location where the virtual machine will reside
#Reset validator
[bool]$Validator = $false

while (!$Validator) {
    
    $VMLocation = Read-Host -Prompt "which disk will the virtual machine reside on?"
    If (Test-Path $VMLocation){

        $Validator = $true

    }
    Else {

        Write-Host "disk not found!" -ForegroundColor Red

    }

}

# 
$Selection = DomCreate-DynMenu -sDirectory $VHDXDirectory -sMenuName "Microsoft Windows Images" -sMenuQuestion "Please select a Windows edition"

### Get the source data VHDX and create the target data path
$SourceData = (-join ($VHDXDirectory,"\",$Selection))
$TargetData = (-join ($VMLocation,"\",$ComputerName,"\Virtual Hard Disks\",$ComputerName,"-system.vhdx"))
New-Item -Path (-join ($VMLocation,"\",$ComputerName,"\Virtual Hard Disks\")) -ItemType Directory

### Create the virtual machine
New-VM -Name $ComputerName -MemoryStartupBytes 2GB -SwitchName "NAT" -Path (-join ($VMLocation,"\")) -Generation 2

# Set the processor and memory configuration
Set-VM -VMName $ComputerName -ProcessorCount 2 -DynamicMemory -MemoryMinimumBytes 512MB -MemoryMaximumBytes 4096MB -MemoryStartupBytes 2GB

# Setting the access VLAN ID on the network adapter.
#Set-VMNetworkAdapterVlan -VMName $ComputerName -Access -VlanId 200

Add-VMHardDiskDrive -VMName $ComputerName

### Copy the template VHDX to the virtual machine destination folder.

Copy-Item $SourceData -Destination $TargetData -Force

### Inject XML file into Virtual Machine
Mount-DiskImage -ImagePath $TargetData

### Get the drive letter using the out variable from the command above
$DriveLetter = $(Get-DiskImage $TargetData -StorageType VHDX | Get-Disk | Get-Partition | Where-object {$_.Type -eq "Basic"}).DriveLetter

### Get the mounted disk unattend location
$Destination=(-join ($Driveletter,":\Windows\System32\Sysprep\unattend.xml"))

Copy-Item $xmlUnattendXML $Destination
Copy-Item (-join ($DSCWorkingDirectory,"\metaconfig.mof")) (-join ($DriveLetter,":\Windows\System32\Configuration\"))

Dismount-DiskImage -ImagePath $TargetData

### Attach Drive
Set-VMHardDiskDrive -VMName $ComputerName -Path $TargetData -ControllerType SCSI

Set-VMFirmware -VMName $ComputerName -FirstBootDevice $(Get-VMHardDiskDrive -VMName $ComputerName -ControllerNumber 0 -ControllerLocation 0)

Start-VM -Name $ComputerName

### Clean up
Remove-Item $xmlUnattendXML
Remove-Item -Path (-join ($DSCWorkingDirectory,"\*")) -Filter *.mof
