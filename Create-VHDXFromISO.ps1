#### Build a menu system ###
#### Looks in c:\Windows Images for ISOs and builds an object array###
Set-Variable SourcePath 'C:\WindowsImages\ISOs' -Option Constant
Set-Variable ImageToolsPath 'C:\Image Deployment' -Option Constant
Set-Variable DestinationPath 'C:\WindowsImages\VHDXs' -Option Constant
Set-Variable WimFile '\sources\install.wim' -Option Constant

### Dot source
. .\Convert-WindowsImage.ps1

$MenuItems = $(Get-ChildItem $SourcePath).Name
### Build a hashtable to hold the menu items ###
$Menu = @{}

### Creates VHDX templates from Windows ISOs ###
Write-Host "My Menu" -ForegroundColor Cyan

### Loop through each item and assign a index.
[Int]$IndexNo = 1
$MenuItems | % {
    
    Write-Host "$IndexNo. $_" 
    $Menu.Add($IndexNo,$_)
    $IndexNo ++

}

### Ask the user to make a choice
[Int]$IndexSelection = Read-Host "Choose an ISO to build a virtual hard disk"
$Selection = $Menu.Item($IndexSelection)

### Output the chosen ISO.
Write-Output "Using $Selection to build a virtual hard disk image"

### Mount the disk image locally
Mount-DiskImage -ImagePath (-join ($SourcePath,"\",$Selection)) -PassThru -OutVariable MountedImage

### Get the drive letter using the out variable from the command above
$DriveLetter = $($MountedImage | Get-Volume).DriveLetter

Write-Output "$Selection mounted as drive letter: $DriveLetter"

### Get the image list from the install wim
Get-WindowsImage -ImagePath (-join ($DriveLetter,":\",$WimFile)) | % {

    Convert-WindowsImage -SourcePath (-join ($DriveLetter,":",$WimFile)) -VHDPath (-join ($DestinationPath,"\",($_.ImageName.Replace(" ","")),".vhdx")) -Edition $_.ImageName -VHDPartitionStyle MBR -BCDinVHD VirtualMachine

    #-SizeBytes 64424509440

}

### Finally dismount the disk image as we have finished.
Dismount-DiskImage -ImagePath (-join ($SourcePath,"\",$Selection))










