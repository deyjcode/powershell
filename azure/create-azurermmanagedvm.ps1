#Requires -Module AzureRM

<#

.SYNOPSIS
Creates an Azure VM with Managed Disks. Optionally, add it to an Availability Set.

.DESCRIPTION
Creates an Azure VM with Managed Disks by also creating the necessary resource group, network, etc.. This script can also handle adding virtual machines to an Availability Set which is a form of clustering providing high-availability in the Azure fabric.

Alternatively, one can also provide a vhd image Location to clone a managed disk from.

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
c:\create-azurermmanagedvm.ps1 -RgName testing -Location eastus2 -vmNetwork stdVnet -VMName testvm1 -VMSize Standard_F1 -VMOsDiskSize 64 -VMManagedDiskType Standard_LRS -VMSubnet stdSubnet -VMVhdSourceURI https://organizationimages.blob.core.windows.net/vhds/azurebaseimage.vhd

.EXAMPLE
Creating a virtual machine with Premium_LRS
c:\create-azurermmanagedvm.ps1 -RgName testing -Location eastus2 -vmNetwork stdVnet -VMName testvm1 -VMSize Standard_F1s -VMOsDiskSize 64 -VMManagedDiskType Premium_LRS -VMSubnet stdSubnet -VMVhdSourceURI https://organizationimages.blob.core.windows.net/vhds/azurebaseimage.vhd

.LINK
https://azure.microsoft.com/en-us/pricing/details/managed-disks/

.LINK
https://docs.microsoft.com/en-us/azure/virtual-network/virtual-machine-network-throughput

.LINK
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/managed-disks-overview

.LINK
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/manage-availability#configure-multiple-virtual-machines-in-an-availability-set-for-redundancy
#>


[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The Resource Group to place the virtual machine into")]
    [string]$RgName,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure Region where the Resource Group and Virtual Machine will be located")]
    [string]$Location,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure Subscription Id")]
    [ValidatePattern("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$")]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true, HelpMessage = "The Name of the Azure Virtual Network")]
    [string]$VMNetworkName,

    [Parameter(Mandatory=$true, HelpMessage = "The Name of the Virtual Machine")]
    [string]$VMName,

    [Parameter(Mandatory=$true, HelpMessage = "The Size of the Virtual Machine")]
    [ValidateSet("Standard_D1_v2","Standard_DS1_v2","Standard_F1s","Standard_F1","Standard_F2s","Standard_F2","Standard_F4s","Standard_F4")]
    [string]$VMSize,

    [Parameter(Mandatory=$true, HelpMessage = "The Size of the Virtual Machine Operating System Disk")]
    [ValidateSet("32","64","128","256","512","1024","2048","4095")]
    [int]$VMOsDiskSize,

    [Parameter(Mandatory=$true, HelpMessage = "Specify the type of Disk attached to the Virtual Machine")]
    [ValidateSet("Standard_LRS","Premium_LRS")]
    [string]$VMManagedDiskType,

    [Parameter(HelpMessage = "The name of the Virtual Subnet in the Virtual Network")]
    [string]$VMSubnet = "vmsubnet",

    [Parameter(Mandatory=$true, HelpMessage = "The URI (or URL) of the VHD file to be used")]
    [string]$VMVhdSourceURI,

    [Parameter(HelpMessage = "Specify whether the Virtual Machine is apart of an Availability Set")]
    [switch]$EnableVMCluster,

    [Parameter(HelpMessage = "Specify the Availability Set Name")]
    [string]$VMAvailsetName,

    [Parameter(HelpMessage = "Specify the Availability Set Update Domain count")]
    [int]$AvailSetUpdateDomainCount,

    [Parameter(HelpMessage = "Specify the Availability Set Fault Domain count")]
    [int]$AvailSetFaultDomainCount,

    [Parameter(HelpMessage = "Specify if the Virtual Machine uses Enhanced Networking")]
    [switch]$VMEnhancedNetworking
)

BEGIN {

    try {
        Import-Module AzureRM -ErrorAction Stop
    }
    catch {
        throw "Unable to Import AzureRM Module. Please install the AzureRM Module."
    }

    switch ((Get-AzureRmContext).Name -eq 'Default') {
        $true {
            Write-Output "Already logged into into Azure..."
        }
        $false {
            try {
                Write-Output "We need to login to Azure..."
                $azure_credential_username = Read-Host -Prompt "Please enter the username to log into Azure"
                Connect-AzureRmAccount -Credential (Get-Credential -UserName $azure_credential_username -Message "Please enter your password")
            }
            catch {
                Write-Error $_.Exception
            }
        }
    }

    Write-Output "Setting Subscription ID session to: $SubscriptionId"
    Set-AzureRMContext -SubscriptionId $SubscriptionId

    # VM has dependencies, but they need to be unique
    $VMNicName = $VMName + 'nic-1'
    $vm_os_disk_name = $VMName + 'OsDisk'
    $vm_diag_storage_name = $VMName + 'diagdisk'

    # Ensure diagnostic name uses lower case letters. In addition, ensure the length is less than 24 characters
    $vm_diag_storage_name_lower = $vm_diag_storage_name.ToLower()
    if ($vm_diag_storage_name_lower.Length -gt 24) {
        Write-Warning -Message "VM Diagnostic Storage Account procedures WILL NOT be executed due to 24 character length limit"
    }

    try {
        Write-Verbose "Checking if a Resource Group exists..."
        Get-AzureRmResourceGroup $RgName -ErrorAction Stop
        Write-Verbose "Success!"
    }
    catch {
        Write-Output "We need to create a Resource Group named, $RgName located in $Location."
        New-AzureRmResourceGroup -Name $RgName -Location $Location
        $SubnetAddressPrefix = '10.0.1.0/24'
        $VMSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $VMSubnet -AddressPrefix $SubnetAddressPrefix
        $NetworkAddressPrefix = '10.0.0.0/16'
        Write-Output "Because a Resource Group needed to be created, we are creating a Virtual Network named $VMNetworkName with a $NetworkAddressPrefix address space."
        New-AzureRmVirtualNetwork -Name $VMNetworkName -ResourceGroupName $RgName -Location $Location -AddressPrefix $NetworkAddressPrefix -Subnet $VMSubnetConfig
    }

    # Create public IP ahead of virtual machine, if required
    switch ($VMPublicIP) {
        $true {
            $VMPublicIPLabel = Read-Host "Please enter a name for the Public IP resource"
            # We must make the label lowercase for Azure validation
            $VMPublicIPLabelLower = $VMPublicIPLabel.ToLower()
            [ValidateSet("static","dynamic")]$publicIPAlLocationMethod = Read-Host "You must specify if the Public IP is static or dynamic"
            $pip = New-AzureRmPublicIpAddress -ResourceGroupName $RgName -Name $VMPublicIPLabelLower -AlLocationMethod $publicIPAlLocationMethod
            Write-Output "New Public IP Address: $($pip.IpAddress). The type of Public IP is $($pip.PublicIpAlLocationMethod)."
        }
    }
}

PROCESS {
    switch ($VMManagedDiskType) {
        'Standard_LRS' {
            switch ($VMSize) {
                'Standard_DS1_v2' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }

                'Standard_F1s' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }

                'Standard_F2s' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }

                'Standard_F4s' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }

                default {
                    Write-Verbose "Detected $VMManagedDiskType for creation."
                    Write-Output "Gathering information on Azure Virtual Network '$VMNetworkName'."
                    try {
                        Write-Verbose "Does the Virtual Network $VMNetworkName exist?"
                        $vnet = Get-AzureRmVirtualNetwork -Name $VMNetworkName -ResourceGroupName $RgName -ErrorAction Stop
                        Write-Verbose "Yes! Continuing..."
                    }
                    catch {
                        Write-Verbose "No! Creating..."
                        try {
                            $vnet = New-AzureRmVirtualNetwork -Name $VMNetworkName -ResourceGroupName $RgName -Location $Location -Subnet $VMSubnet -AddressPrefix "10.0.0.0/16" -ErrorVariable $vneterror
                            Write-Verbose "Created Virtual Network $vnet.Name"
                        }
                        catch {
                            Write-Output $vneterror
                            exit
                        }
                    }
                    
                    Write-Output "Assigning New NIC Card to the Azure Virtual Network"
    
                    $VMNetwork = Get-AzureRmVirtualNetwork -Name $VMNetworkName -ResourceGroupName $RgName
                    $VMNetworkSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $VMSubnet -VirtualNetwork $VMNetwork
    
                    switch ($VMEnhancedNetworking) {
                        $true {
                            switch ($VMPublicIP) {
                                $true {
                                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -EnableAcceleratedNetworking -PublicIpAddress $pip -ErrorAction Stop
                                    Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful. Enhanced Networking is enabled."
                                }
                            }
                            $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                            -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -EnableAcceleratedNetworking -ErrorAction Stop
                            Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful. Enhanced Networking is enabled."
                        }
                        $false {
                            switch ($VMPublicIP) {
                                $true {
                                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -PublicIpAddress $pip -ErrorAction Stop
                                    Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful."
                                }
                            }
                            $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                            -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -ErrorAction Stop
                            Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful."
                        }
                    }
                    $vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
                    $vm = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $VMNic.Id
                    Write-Output "We are creating a $VMManagedDiskType disk and assigning it to the VM."
                    $sourceUri = ("$VMVhdSourceURI")
                    $osDisk = New-AzureRmDisk -DiskName $vm_os_disk_name -Disk `
                        (New-AzureRmDiskConfig -AccountType $VMManagedDiskType  `
                        -Location $Location -CreateOption Import `
                        -SourceUri $sourceUri) -ResourceGroupName $RgName -ErrorAction Stop
                        $vm = Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $osDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows
                }
            }
        }
        'Premium_LRS' {
            switch ($VMSize) {
                'Standard_D1_v2' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }

                'Standard_F1' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }

                'Standard_F2' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }

                'Standard_F4' { Write-Error -Exception "Incompatible VM Size with Specified Disks" -Message "The specified VM Size: $VMSize, is incompatible with Standard Disks. Please see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general for details." }
                
                default {
                    Write-Verbose "Detected $VMManagedDiskType for creation."
                    Write-Output "Gathering information on Azure Virtual Network '$VMNetworkName'."
                    $vnet = Get-AzureRmVirtualNetwork -Name $VMNetworkName -ResourceGroupName $RgName -ErrorAction Stop
                    Write-Output "Assigning New NIC Card to the Azure Virtual Network"

                    $VMNetwork = Get-AzureRmVirtualNetwork -Name $VMNetworkName -ResourceGroupName $RgName
                    $VMNetworkSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $VMSubnet -VirtualNetwork $VMNetwork

                    switch ($VMEnhancedNetworking) {
                        $true {
                            switch ($VMPublicIP) {
                                $true {
                                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -EnableAcceleratedNetworking -PublicIpAddress $pip -ErrorAction Stop
                                    Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful. Enhanced Networking is enabled."
                                }
                            }
                            $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                            -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -EnableAcceleratedNetworking -ErrorAction Stop
                            Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful. Enhanced Networking is enabled."
                        }
                        $false {
                            switch ($VMPublicIP) {
                                $true {
                                    $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                                    -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -PublicIpAddress $pip -ErrorAction Stop
                                    Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful."
                                }
                            }
                            $VMNic = New-AzureRmNetworkInterface -Name $VMNicName -ResourceGroupName $RgName -Location $Location `
                            -Subnet $VMNetworkSubnet -IpConfigurationName ipconfig1 -ErrorAction Stop
                            Write-Output "Creation of $($VMNic.Name) on the subnet $($vnet.Subnets[0].Name) successful."
                        }
                    }
                    $vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
                    $vm = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $VMNic.Id
                    Write-Output "We are creating a $VMManagedDiskType disk and assigning it to the VM."
                    $sourceUri = ("$VMVhdSourceURI")
                    $osDisk = New-AzureRmDisk -DiskName $vm_os_disk_name -Disk `
                        (New-AzureRmDiskConfig -AccountType $VMManagedDiskType  `
                        -Location $Location -CreateOption Import `
                        -SourceUri $sourceUri) -ResourceGroupName $RgName -ErrorAction Stop
                        $vm = Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $osDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows
                }
            }
        }
    }

    # Create VM Boot Diagnostic account. We always use the SKU 'Standard_LRS'. It's just diagnostic data required by the New-AzureRMVM Command...
    Write-Output "Creating VM Diagnostic Storage account..."
    New-AzureRmStorageAccount -ResourceGroupName $RgName -Name $vm_diag_storage_name_lower -Location $Location -SkuName Standard_LRS
    Set-AzureRmVMBootDiagnostics -VM $vm -Enable -ResourceGroupName $RgName -StorageAccountName $vm_diag_storage_name_lower

    Write-Output "Creating the Virtual Machine..."
    New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $vm –LicenseType "Windows_Server" -DisableBginfoExtension -ErrorAction Stop

    # If Availability Set was desired, we continue with the rest of this script...
    switch ($EnableVMCluster)
    {
        $true {
            Write-Output "This VM is being attached to an Availability Set"
            # Create Availability Set if there is none. If there is, begin setting up New Virtual Machine with previously created values.
            Write-Output "Checking if an Availability Set exists..."
            $availSet = Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $VMAvailsetName -ErrorVariable AvailSetExists -ErrorAction SilentlyContinue
            if (($AvailSetExists.exception.InnerException) -like "*found*") {
                Write-Output "Availability Set $VMAvailsetName not found in Resource Group $RgName."
                Write-Output "We must create a new managed Availability Set called $VMAvailsetName."
                $availset = New-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $VMAvailsetName -Location $Location -Sku Aligned -PlatformUpdateDomainCount $AvailSetUpdateDomainCount -PlatformFaultDomainCount $AvailSetFaultDomainCount
                # Store information whether the availability set is Managed or not
                $availSetManagedCheck = Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $VMAvailsetName
                switch ($availSetManagedCheck.Managed) {
                    $false {
                        $availSetManagedCheck = Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $VMAvailsetName
                        Write-Warning -Message "The specified Availability Set $($availSetManagedCheck.Name) must be in a managed state before continuing."
                        Write-Warning -Message "This requires the Availability Set to be DELETED."
                        Write-Warning -Message "Please confirm you wish to DELETE the Availability Set $($availSetManagedCheck.Name)"
                        Remove-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $($availSetManagedCheck.Name) -Confirm
                    }
                    $true {
                        Write-Output "The Availability Set is a Managed Availability Set."
                        Write-Output "Ready to add VM..."
                        Write-Output "Capture virtual machine details and output to console..."
                        $vm = Get-AzureRmVM -ResourceGroupName $RgName -Name $VMName;
                        Write-Output "Before adding $($vm.Name) to the Availability set, Azure requires us to remove the machine."
                        Remove-AzureRmVM -ResourceGroupName $RgName -Name $VMName -Force
                        Write-Output "Attaching VM Configuration and Disks to the availability set..."
                        $newVM = New-AzureRmVMConfig -VMName $vm.Name -VMSize $VM.HardwareProfile.VMSize -AvailabilitySetId $availSet.Id
                        Set-AzureRmVMOSDisk -VM $NewVM -ManagedDiskId $osDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows

                        # Add available NIC(s) to the VM
                        foreach ($VMNic in $vm.NetworkProfile) {
                            Add-AzureRmVMNetworkInterface -VM $NewVM -Id $vm.NetworkProfile.NetworkInterfaces[0].Id
                        }

                        # Reset our Diagnostics because the cmdlet errors out otherwise
                        Set-AzureRmVMBootDiagnostics -VM $newVM -Enable -ResourceGroupName $RgName -StorageAccountName $vm_diag_storage_name_lower
                        # Create the VM, specifying we are using the Azure Hybrid Use benefit.
                        New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $NewVM -DisableBginfoExtension –LicenseType "Windows_Server"

                        Write-Output "Confirm that the New VM exists..."
                        Get-AzureRmVM -ResourceGroupName $RgName -Name $NewVM.Name
                    }
                }
            }
            else {
                    Write-Output "Availability set $VMAvailsetName found."
                    # Store information whether the availability set is Managed or not
                    $availSetManagedCheck = Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $VMAvailsetName -ErrorAction SilentlyContinue
                    switch ($availSetManagedCheck.Managed) {
                        $false {
                            $availSetManagedCheck = Get-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $VMAvailsetName
                            Write-Warning -Message "The specified Availability Set $($availSetManagedCheck.Name) must be in a managed state before continuing."
                            Write-Warning -Message "This requires the Availability Set to be DELETED."
                            Write-Warning -Message "Please confirm you wish to DELETE the Availability Set $($availSetManagedCheck.Name)"
                            Remove-AzureRmAvailabilitySet -ResourceGroupName $RgName -Name $($availSetManagedCheck.Name) -Confirm
                        }
                        $true {
                            Write-Output "The Availability Set is a Managed Availability Set."
                            Write-Output "Ready to add VM..."
                            Write-Output "Capture virtual machine details and output to console..."
                            $vm = Get-AzureRmVM -ResourceGroupName $RgName -Name $VMName;
                            Write-Output "Before adding $($vm.Name) to the Availability set, Azure requires us to remove the machine."
                            Remove-AzureRmVM -ResourceGroupName $RgName -Name $VMName -Force
                            Write-Output "Attaching VM Configuration and Disks to the availability set..."
                            $newVM = New-AzureRmVMConfig -VMName $vm.Name -VMSize $VM.HardwareProfile.VMSize -AvailabilitySetId $availSet.Id
                            Set-AzureRmVMOSDisk -VM $NewVM -ManagedDiskId $osDisk.Id -StorageAccountType $VMManagedDiskType -DiskSizeInGB $VMOsDiskSize -CreateOption Attach -Windows

                            #Add available NIC(s) to the VM
                            foreach ($VMNic in $vm.NetworkProfile) {
                                    Add-AzureRmVMNetworkInterface -VM $NewVM -Id $vm.NetworkProfile.NetworkInterfaces[0].Id
                                }

                            #Reset our Diagnostics because the cmdlet errors out otherwise
                            Set-AzureRmVMBootDiagnostics -VM $newVM -Enable -ResourceGroupName $RgName -StorageAccountName $vm_diag_storage_name_lower
                            #Create the VM, specifying we are using the Azure Hybrid Use benefit.
                            New-AzureRmVM -ResourceGroupName $RgName -Location $Location -VM $NewVM -DisableBginfoExtension –LicenseType "Windows_Server"
                    }
                }
            }
        }
        #...Otherwise end the script here
        $false {
            Write-Output "This VM is not being attached to an Availability Set. Nothing else to do."
        }
    }
}