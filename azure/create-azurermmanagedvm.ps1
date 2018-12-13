#Requires -Module AzureRM

<#PSScriptInfo

.VERSION 2.0

.AUTHOR steve jennings

.RELEASENOTES
1.0 Initial script.
2.0 Major rewrite

TODO: Splat parameters and reduce size of the script...compartmentalize.

#>

<#

.SYNOPSIS
Creates an Azure VM with Managed Disks. Optionally, add it to an Availability Set. This script is only designed to handle VHD deployment!

.DESCRIPTION
Creates an Azure VM with Managed Disks by also creating the necessary resource group, virtual network, network card, and diagnostic storage account. This script can also handle adding virtual machines to an existing Availability Set which is a form of clustering providing high-availability in the Azure fabric. The existing Availability Set must already be in a 'Managed' state or else the script will prompt for replacement.

IMPORTANT: This script is only designed to handle VHD deployment!

.PARAMETER RgName
The Resource Group name to place the virtual machine.

.PARAMETER VMName
The name of the Virtual Machine.

.PARAMETER Location
The Azure Region Location in which the resource must be placed.
For a list of Locations, run the command: Get-AzureRmLocation | Select Location,displayname

.PARAMETER SubscriptionId
The Azure Subscription ID for the commands. For a list of Subscription IDs, run the command: Get-AzureRMContext -ListAvailable

.PARAMETER VMNetworkName
Specifies the Virtual Network to add the Virtual Machine to.

.PARAMETER VMSize
SKU size for the Virtual Machine.
For a list of available SKUs in a region, run the command: Get-AzureRMVMSize -Location LocationSKU

.PARAMETER VMOsDiskSize
Specify the disk size to qualify for managed disk speed tiers. Disk sizes round up to the nearest value to match the qualified tiers. See related links for details and further disk quota sizes.

.PARAMETER VMManagedDiskType
The associated disktype to be used for the Virtual Machine. This parameter requires understanding of the various managed disk types that Azure uses. Choices include Standard_LRS or Premium_LRS. Standard_LRS uses mechanical disk drives. Premium_LRS uses solid state drives.

If you use Standard_LRS as the disk type, you must use VM SKUs which qualify for Standard Storage.
If you use Premium_LRS as the disk type, you must use VM SKUs which qualify for Premium Storage.

More information can be found in related links.

.PARAMETER VMSubnet
Specifies the subnet to which the VM resides. This also places the VM in the subnet which applies Network Security Group firewall rules to the machine.

.PARAMETER EnableVMCluster
Enables the ability for the script to create an Availability Set.

.PARAMETER VMAvailsetName
Only used with the 'EnableVMCluster' switch. Looks for, or assigns, a name for the Availability Set.

.PARAMETER AvailSetUpdateDomainCount
Only used with the 'EnableVMCluster' switch. Assigns Update Domain count for Availability Set. See related links for more details.

.PARAMETER AvailSetFaultDomainCount
Only used with the 'EnableVMCluster' switch. Assigns Fault Domain count for Availability Set. See related links for more details.

.PARAMETER VMVhdSourceURI
Specifies a VHD source to create virtual machines off of. This is a URI pointing to an Azure Blob URI, e.g.,'https://organizationimages.blob.core.windows.net/vhds/azurebaseimage.vhd'

.PARAMETER VMEnhancedNetworking
Specifies whether the virtual machine has Enhanced Networking enabled. See related links for details.

.EXAMPLE
Creating a virtual machine with Standard_LRS 
.\create-azurermmanagedvm.ps1 -RgName AzureRG -Location eastus2 -subscriptionID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -VirtualNetworkName stdVnet -VMName testvm1 -VMSize Standard_F1 -VMOsDiskSize 128 -VMManagedDiskType Standard_LRS -VMVhdSourceURI https://organizationimages.blob.core.windows.net/vhds/azurebaseimage.vhd -verbose

.EXAMPLE
Creating a virtual machine with Premium_LRS but in an Availability Set (a.k.a. Cluster)
.\create-azurermmanagedvm.ps1 -RgName AzureRG -Location eastus2 -subscriptionID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -VirtualNetworkName stdVnet -VMName testvm1 -VMSize Standard_F1 -VMOsDiskSize 128 -VMManagedDiskType Standard_LRS -VMVhdSourceURI https://organizationimages.blob.core.windows.net/vhds/azurebaseimage.vhd -verbose -EnableVMCluster -AvailabilitySetName AvailabilitySet

.LINK
https://azure.microsoft.com/en-us/pricing/details/managed-disks/

.LINK
https://docs.microsoft.com/en-us/azure/virtual-network/virtual-machine-network-throughput

.LINK
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/managed-disks-overview

.LINK
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/manage-availability#configure-multiple-virtual-machines-in-an-availability-set-for-redundancy
#>


[CmdletBinding(
    DefaultParameterSetName = 'Default'
    )]
Param (
    [Parameter(
        Mandatory = $true, 
        HelpMessage = "The Resource Group to place the virtual machine into",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [string]$RgName,

    [Parameter(
        Mandatory = $true, 
        HelpMessage = "The Azure Region where the Resource Group and Virtual Machine will be located",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [string]$Location,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "The Azure Subscription Id",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [ValidatePattern(
        "^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$"
        )]
    [string]$SubscriptionId,

    [Parameter(
        Mandatory= $true,
        HelpMessage = "The Name of the Azure Virtual Network",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [string]$VirtualNetworkName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "The Name of the Virtual Machine",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [string]$VMName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "The Size of the Virtual Machine",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [ValidateSet(
        "Standard_D1_v2",
        "Standard_DS1_v2",
        "Standard_D3_v2",
        "Standard_DS3_v2",
        "Standard_F1s",
        "Standard_F1",
        "Standard_F2s",
        "Standard_F2",
        "Standard_F4s",
        "Standard_F4"
        )]
    [string]$VMSize,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "The Size of the Virtual Machine Operating System Disk",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [ValidateSet(
        "128", # Default image size
        "256",
        "512",
        "1024",
        "2048",
        "4095"
        )]
    [int]$VMOsDiskSize,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Specify the type of Disk attached to the Virtual Machine",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [ValidateSet(
        "Standard_LRS","Premium_LRS"
        )]
    [string]$VMManagedDiskType,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "The URI (or URL) of the VHD file to be used",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [string]$VMVhdSourceURI,

    [Parameter(
        HelpMessage = "Specify if a Public IP will be created",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [ValidateSet(
        "Standard_LRS","Premium_LRS"
        )]
    [switch]$VMPublicIP,

    [Parameter(
        HelpMessage = "Specify whether the Virtual Machine is apart of an Availability Set",
        ParameterSetName = 'Cluster'
        )]
    [switch]$EnableVMCluster,

    [Parameter(
        HelpMessage = "Specify the Availability Set Name",
        ParameterSetName = 'Cluster'
        )]
    [string]$AvailabilitySetName,

    [Parameter(
        HelpMessage = "Specify if the Virtual Machine uses Enhanced Networking",
        ParameterSetName = 'Default'
        )]
    [Parameter(
        ParameterSetName = 'Cluster'
        )]
    [switch]$VMEnhancedNetworking
)

BEGIN {

    try {
        Import-Module AzureRM -ErrorAction Stop
    }
    catch {
        throw "Please install the 'AzureRM' Module."
    }

    Function Connect-Azure {
        Write-Host "Connecting to Azure..."
        switch ((Get-AzureRmContext).Environment.Name -eq 'AzureCloud') {
            $true {
                Write-Host "Already logged into into Azure!"
            }
            $false {
                try {
                    Connect-AzureRmAccount -Credential (Get-Credential -Message "Please enter Azure Credentials...")
                    break
                }
                catch {
                    Write-Error $_.Exception
                    exit
                }
            }
        }
    }

    # Connect to Azure
    Connect-Azure

    Write-Verbose "Setting session Subscription ID to: $SubscriptionId"
    Set-AzureRMContext -SubscriptionId $SubscriptionId

    # VM has dependencies, change these values as needed
    $VMSubnet = "vmsubnet"
    $VMNicName = $VMName + 'nic-1'
    $Vm_Os_Disk_Name = $VMName + 'OsDisk'
    $Vm_Diag_Storage_Name = $VMName + 'diagdisk'
    $NetworkAddressPrefix = '10.0.0.0/16'
    $SubnetAddressPrefix = '10.0.1.0/24'
    $VMSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $VMSubnet -AddressPrefix $SubnetAddressPrefix

    # Adjust these values if you wish to configure Availability Set Update and Fault Domains from the defaults
    [int]$AvailSetFaultDomainCount = '3'
    [int]$AvailSetUpdateDomainCount = '5'

    ### REMOVE IF NOT NEEDED
    # # Handle Microsoft's conversion for the SKU
    # if ($VMManagedDiskType -eq "Standard_LRS") {
    #     $ConvertedManagedDiskType = "StandardLRS"
    # }

    # if ($VMManagedDiskType -eq "Premium_LRS") {
    #     $ConvertedManagedDiskType = "PremiumLRS"
    # }

    # Ensure diagnostic name uses lower case letters. In addition, ensure the length is less than 24 characters
    $Vm_Diag_Storage_Name_Lower = $Vm_Diag_Storage_Name.ToLower()
    if ($Vm_Diag_Storage_Name_Lower.Length -gt 24) {
        Write-Warning -Message "VM Diagnostic Storage Account procedures WILL NOT be executed due to 24 character length limit"
    }

    # Check if Resource Group exists
    try {
        Write-Verbose "Checking if a Resource Group exists..."
        $GetRGStatus = Get-AzureRmResourceGroup $RgName -Location $Location -ErrorAction Stop
        Write-Verbose "Resource group '$($GetRGStatus.ResourceGroupName)' exists"
    }
    catch {
        $NewRGStatus = New-AzureRmResourceGroup -Name $RgName -Location $Location
        Write-Verbose "Resource group '$($NewRGStatus.ResourceGroupName)' provisioning has $($NewRGStatus.ProvisioningState)"
    }
}

PROCESS {
    # Gather details on virtual network
    try {
        $VNet = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $RgName -ErrorAction Stop
        Write-Verbose "Virtual Network '$VirtualNetworkName' already exists"
    }
    catch {
        try {
            $VNet = New-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $RgName -Location $Location -Subnet $VMSubnetConfig -AddressPrefix $NetworkAddressPrefix -ErrorVariable VNetError
            Write-Host "Created Virtual Network $($VNet.Name)"
        }
        catch {
            Write-Output $VNetError
            exit
        }
    }    
    $VMNetworkSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $VMSubnet -VirtualNetwork $VNet

    switch ($VMManagedDiskType) {
        'Standard_LRS' {
            Write-Verbose "Detected $VMManagedDiskType SKU for creation."
            switch ($VMEnhancedNetworking) {
                $true {
                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -EnableAcceleratedNetworking -ErrorAction Stop
                    Write-Verbose "Creation of '$($VMNic.Name)' on the subnet '$($VNet.Subnets[0].Name)' successful. Enhanced Networking is enabled."
                }
                $false {
                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -ErrorAction Stop
                    Write-Host "Creation of $($VMNic.Name) on the subnet $($VNet.Subnets[0].Name) successful."
                }
            }
            # We need to create a Virtual Machine object to create the VM
            $NewVM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
            $VM = Add-AzureRmVMNetworkInterface -VM $NewVM -Id $VMNic.Id
            Write-Host "We are creating a $VMManagedDiskType disk and assigning it to the VM."
            $sourceUri = ("$VMVhdSourceURI")
            # Not all Powershell cmdlets support the Storage Account SKUs without underscores
            $OSDisk = New-AzureRmDisk -DiskName $vm_os_disk_name -Disk (New-AzureRmDiskConfig -SkuName Standard_LRS -Location $Location -CreateOption Import -SourceUri $sourceUri) -ResourceGroupName $RgName -ErrorAction Stop
            $VM = Set-AzureRmVMOSDisk -VM $VM -ManagedDiskId $OSDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows
        }
        'Premium_LRS' {
            Write-Verbose "Detected $VMManagedDiskType SKU for creation."
            try {
                $VNet = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $RgName -ErrorAction Stop
                Write-Verbose "Virtual Network '$VirtualNetworkName' already exists"
            }
            catch {
                try {
                    $VNet = New-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $RgName -Location $Location -Subnet $VMSubnetConfig -AddressPrefix $NetworkAddressPrefix -ErrorVariable VNetError
                    Write-Verbose "Created Virtual Network $($VNet.Name)"
                }
                catch {
                    Write-Output $VNetError
                    exit
                }
            }

            switch ($VMEnhancedNetworking) {
                $true {
                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -EnableAcceleratedNetworking -ErrorAction Stop
                    Write-Verbose "Creation of '$($VMNic.Name)' on the subnet '$($VNet.Subnets[0].Name)' successful. Enhanced Networking is enabled."
                }
                $false {
                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -ErrorAction Stop
                    Write-Host "Creation of $($VMNic.Name) on the subnet $($VNet.Subnets[0].Name) successful."
                }
            }
            # We need to create a Virtual Machine object to create the VM
            $NewVM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
            $VM = Add-AzureRmVMNetworkInterface -VM $NewVM -Id $VMNic.Id
            Write-Host "We are creating a $VMManagedDiskType disk and assigning it to the VM."
            $sourceUri = ("$VMVhdSourceURI")
            # Not all Powershell cmdlets support the Storage Account SKUs without underscores
            $OSDisk = New-AzureRmDisk -DiskName $vm_os_disk_name -Disk (New-AzureRmDiskConfig -SkuName Standard_LRS -Location $Location -CreateOption Import -SourceUri $sourceUri) -ResourceGroupName $RgName -ErrorAction Stop
            $VM = Set-AzureRmVMOSDisk -VM $VM -ManagedDiskId $OSDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows
        }
    }

    
    # Diagnostic Storage Account Creation Block
    $StatusDiagnostics = Get-AzureRmStorageAccount -ResourceGroupName $RgName -Name $Vm_Diag_Storage_Name -ErrorAction SilentlyContinue
    switch ($StatusDiagnostics.ProvisioningState) {
        'Succeeded' {
            Write-Output "Diagnostic Account '$($StatusDiagnostics.StorageAccountName)' already exists."
            Set-AzureRmVMBootDiagnostics -VM $VM -Enable -ResourceGroupName $RgName -StorageAccountName $Vm_Diag_Storage_Name_Lower > $null
            break
        }
        default {
            # Create VM Boot Diagnostic account. We always use the SKU 'Standard_LRS'. It's just diagnostic data required by the New-AzureRMVM Command...
            Write-Verbose "Creating VM Diagnostic Storage account..."
            $CreateDiagnostics = New-AzureRmStorageAccount -ResourceGroupName $RgName -Name $Vm_Diag_Storage_Name_Lower -Location $Location -SkuName Standard_LRS -ErrorAction Stop
            Write-Host "Diagnostic storage account provisioning has $($CreateDiagnostics.ProvisioningState)"
            Set-AzureRmVMBootDiagnostics -VM $VM -Enable -ResourceGroupName $RgName -StorageAccountName $Vm_Diag_Storage_Name_Lower > $null
        }
    }

    # Reset our Diagnostics because the cmdlet errors out otherwise
    Set-AzureRmVMBootDiagnostics -VM $newVM -Enable -ResourceGroupName $RgName -StorageAccountName $Vm_Diag_Storage_Name_Lower
    # Create the VM, specifying we are using the Azure Hybrid Use benefit.
    New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $NewVM -DisableBginfoExtension –LicenseType "Windows_Server"

    # If Availability Set was desired, we continue with the rest of this script...
    switch ($EnableVMCluster)
    {
        $true {
            # Create Availability Set if there is none. If there is, begin setting up New Virtual Machine with previously created values.
            Write-Verbose "Checking if an Availability Set already exists..."
            $AvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $AvailabilitySetName -ErrorVariable AvailSetExists -ErrorAction SilentlyContinue
            if (($AvailSetExists.exception.InnerException) -like "*found*") {
                Write-Verbose "Availability Set $AvailabilitySetName not found in Resource Group $RgName."
                Write-Verbose "We must create a new managed Availability Set called $AvailabilitySetName."
                $AvailabilitySet = New-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $AvailabilitySetName -Location $Location -Sku Aligned -PlatformUpdateDomainCount $AvailSetUpdateDomainCount -PlatformFaultDomainCount $AvailSetFaultDomainCount -ErrorAction Stop
                
                Write-Host "Ready to add VM to Availability Set... please wait"
                $VM = Get-AzureRmVM -ResourceGroupName $RgName -Name $VMName
                Write-Verbose "Before adding $($VM.Name) to the Availability set, Azure requires us to remove the machine."
                $removeVM = Remove-AzureRmVM -ResourceGroupName $RgName -Name $VMName -Force
                Write-Verbose "VM Removal $($removeVM.Status)"
                Write-Verbose "Attaching VM Configuration and Disks to the availability set..."
                $newVM = New-AzureRmVMConfig -VMName $VM.Name -VMSize $VM.HardwareProfile.VMSize -AvailabilitySetId $AvailabilitySet.Id

                $vmDisk = Set-AzureRmVMOSDisk -VM $NewVM -ManagedDiskId $OSDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows

                # Add available NIC(s) to the VM
                foreach ($VMNic in $VM.NetworkProfile) {
                    Add-AzureRmVMNetworkInterface -VM $NewVM -Id $VM.NetworkProfile.NetworkInterfaces[0].Id > $null
                }

                # Reset our Diagnostics because the cmdlet errors out otherwise
                Set-AzureRmVMBootDiagnostics -VM $newVM -Enable -ResourceGroupName $RgName -StorageAccountName $Vm_Diag_Storage_Name_Lower
                # Create the VM, specifying we are using the Azure Hybrid Use benefit.
                New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $NewVM -DisableBginfoExtension –LicenseType "Windows_Server"
            }
            else {
                    # Store information whether the availability set is Managed or not
                    switch ($AvailabilitySet.Managed) {
                        $false {
                            $AvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $AvailabilitySetName
                            Write-Warning -Message "The specified Availability Set '$($AvailabilitySet.Name)' must be in a managed state before continuing."
                            Write-Warning -Message "This requires the current Availability Set to be DELETED!"
                            Write-Warning -Message "Please confirm you wish to DELETE the Availability Set '$($AvailabilitySet.Name)'"
                            Remove-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $($AvailabilitySet.Name) -Confirm
                            Write-Host "Creating new Managed Availability Set"
                            New-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $AvailabilitySetName -Location $Location -Sku Aligned -PlatformUpdateDomainCount $AvailSetUpdateDomainCount -PlatformFaultDomainCount $AvailSetFaultDomainCount -ErrorAction Stop

                            Write-Verbose "The Availability Set is now a managed Availability Set."
                            Write-Host "Ready to add VM to Availability Set... please wait"
                            $VM = Get-AzureRmVM -ResourceGroupName $RgName -Name $VMName
                            Write-Verbose "Before adding $($VM.Name) to the Availability set, Azure requires us to remove the machine."
                            $removeVM = Remove-AzureRmVM -ResourceGroupName $RgName -Name $VMName -Force
                            Write-Verbose "VM Removal $($removeVM.Status)"
                            Write-Verbose "Attaching VM Configuration and Disks to the availability set..."
                            $NewVM = New-AzureRmVMConfig -VMName $VM.Name -VMSize $VM.HardwareProfile.VMSize -AvailabilitySetId $AvailabilitySet.Id

                            $vmDisk = Set-AzureRmVMOSDisk -VM $NewVM -ManagedDiskId $OSDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows
    
                            # Add available NIC(s) to the VM
                            foreach ($VMNic in $VM.NetworkProfile) {
                                Add-AzureRmVMNetworkInterface -VM $NewVM -Id $VM.NetworkProfile.NetworkInterfaces[0].Id > $null
                            }
    
                            # Reset our Diagnostics because the cmdlet errors out otherwise
                            Set-AzureRmVMBootDiagnostics -VM $newVM -Enable -ResourceGroupName $RgName -StorageAccountName $Vm_Diag_Storage_Name_Lower
                            # Create the VM, specifying we are using the Azure Hybrid Use benefit.
                            New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $NewVM -DisableBginfoExtension –LicenseType "Windows_Server"
                        }
                        $true {
                            Write-Verbose "The Availability Set is a Managed Availability Set."
                            Write-Host "Ready to add VM to Availability Set... please wait"

                            $VM = Get-AzureRmVM -ResourceGroupName $RgName -Name $VMName
                            Write-Warning "Before adding $($VM.Name) to the Availability set, Azure requires us to remove the machine."
                            $removeVM = Remove-AzureRmVM -ResourceGroupName $RgName -Name $VMName -Force
                            Write-Verbose "VM Removal $($removeVM.Status)"
                            Write-Verbose "Attaching VM Configuration and Disks to the availability set..."
                            $newVM = New-AzureRmVMConfig -VMName $VM.Name -VMSize $VM.HardwareProfile.VMSize -AvailabilitySetId $AvailabilitySet.Id

                            $vmDisk = Set-AzureRmVMOSDisk -VM $NewVM -ManagedDiskId $OSDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows

                            #Add available NIC(s) to the VM
                            foreach ($VMNic in $VM.NetworkProfile) {
                                Add-AzureRmVMNetworkInterface -VM $NewVM -Id $VM.NetworkProfile.NetworkInterfaces[0].Id > $null
                            }

                            #Reset our Diagnostics because the cmdlet errors out otherwise
                            Set-AzureRmVMBootDiagnostics -VM $newVM -Enable -ResourceGroupName $RgName -StorageAccountName $Vm_Diag_Storage_Name_Lower
                            #Create the VM, specifying we are using the Azure Hybrid Use benefit.
                            New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $NewVM -DisableBginfoExtension –LicenseType "Windows_Server"
                    }
                }
            }
        }
    #...Otherwise end the script here
        $false {
            Write-Verbose "This VM is not being attached to an Availability Set."
            Write-Host "Creating the Virtual Machine..."
            $NewVM = New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $VM –LicenseType "Windows_Server" -DisableBginfoExtension -ErrorAction Stop
            Write-Host "Virtual machine '$VMName' has been created and the status code is '$($NewVM.StatusCode)'"
        }
    }
}

END {
    Write-Host "Script Complete!"
}
