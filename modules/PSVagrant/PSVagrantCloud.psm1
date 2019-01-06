Function Find-VagrantCloudBox {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>
    <#

.SYNOPSIS
Search for Vagrant Cloud Boxes 
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will search and find Vagrant Cloud boxes utilizing a variety of arguments:

- q: The search query. Results will match the username, name, or short_description fields for a box. If omitted, the top boxes based on sort and order will be returned (defaults to "downloads desc").
- provider: (Optional) Filter results to boxes supporting for a specific provider.
- sort: (Optional, default: "downloads") The field to sort results on. Can be one of "downloads", "created", or "updated".
- order: (Optional, default: "desc") The order to return the sorted field in. Can be "desc" os "asc".
- limit: (Optional, default: 10) The number of results to return (max of 100).
- page: (Optional, default: 1)

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.EXAMPLE
Searches for boxes from the Vagrant Cloud
Find-VagrantCloudBox -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71" -q "test" -provider "virtualbox"

.EXAMPLE
Search for all boxes from the Vagrant Cloud
Find-VagrantCloudBox

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [string]$q,
        [string]$provider,
        [ValidateSet("downloads", "created", "updated")]
        [string]$sort,
        [ValidateSet("desc", "asc")]
        [string]$order,
        [int]$limit,
        [int]$page,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken
    )

    if ($q.IsPresent -and $provider.IsPresent -and $sort.IsPresent -and $order.IsPresent -and $limit.IsPresent -and $page.IsPresent) {
        $VagrantAPIURI = "https://app.vagrantup.com/api/v1/search?q=$q&provider=$provider&sort=$sort&order=$order&limit=$limit&page=$page"
    }

    if ($q.IsPresent -and $provider.IsPresent -and $sort.IsPresent -and $order.IsPresent -and $limit.IsPresent) {
        $VagrantAPIURI = "https://app.vagrantup.com/api/v1/search?q=$q&provider=$provider&sort=$sort&order=$order&limit=$limit"
    }

    if ($q.IsPresent -and $provider.IsPresent -and $sort.IsPresent -and $order.IsPresent) {
        $VagrantAPIURI = "https://app.vagrantup.com/api/v1/search?q=$q&provider=$provider&sort=$sort&order=$order"
    }

    if ($q.IsPresent -and $provider.IsPresent -and $sort.IsPresent) {
        $VagrantAPIURI = "https://app.vagrantup.com/api/v1/search?q=$q&provider=$provider&sort=$sort"
    }

    if ($q.IsPresent -and $provider.IsPresent) {
        $VagrantAPIURI = "https://app.vagrantup.com/api/v1/search?q=$q&provider=$provider"
    }

    if ($q.IsPresent) {
        $VagrantAPIURI = "https://app.vagrantup.com/api/v1/search?q=$q"
    }

    $VagrantAPIMethod = "GET"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Get-VagrantCloud2FACode {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Sends a 2FA code to the requested delivery method. 
--Supports only sms at this time--

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
Sends a 2FA code to the requested deliver method. 

This command is used in conjunction with New-VagrantCloudAPIToken when using the Enable2FA switch.

IMPORTANT: This will error out if two-factor authentication hasn't been enabled on the Vagrant Cloud dashboard!

.EXAMPLE
This will send a 2FA code via the requested delivery method:
Get-VagrantCloud2FACode

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.INPUTS
none

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(

    )
    $VagrantAccountDetails = (Get-Credential -Message "Enter your Vagrant Cloud Account Information")
    $ConvertVagrantPassword = $VagrantAccountDetails.GetNetworkCredential().Password

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/two-factor/request-code"
    $VagrantAPIMethod = "POST"

    # Create token json dataset
    $TokenHash = [ordered]@{
        two_factor = @{
            delivery_method = "sms"
        }
        user       = [ordered]@{
            login    = $($VagrantAccountDetails.UserName)
            password = $ConvertVagrantPassword
        }
    }

    $TokenData = $TokenHash | ConvertTo-Json -Compress

    try {
        $SMSData = Invoke-RestMethod -Uri $VagrantAPIURI -Body $TokenData -Method $VagrantAPIMethod -ContentType "application/json"
        $ExtractedSMSNumber = ($SMSData.two_factor).obfuscated_destination

        Write-Output "A validation code has been sent to the $ExtractedSMSNumber"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Get-VagrantCloudAPIToken {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>
    <#

.SYNOPSIS
Validates a API token located in the Vagrant Cloud. 
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This function validates token on the Vagrant Cloud.

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.EXAMPLE
Returns information from Vagrant Cloud on the specified api token.
Get-VagrantCloudAPIToken -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.INPUTS
System.Collections.Hashtable

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/authenticate"
    $VagrantAPIMethod = "GET"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Get-VagrantCloudBox {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>
    <#

.SYNOPSIS
Gathers information on a Vagrant Box located in the Vagrant Cloud. 
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This function gathers information on a Vagrant Box in the Vagrant Cloud.

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.EXAMPLE
Returns information from Vagrant Cloud on the specified box.
Get-VagrantCloudBox -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName"
    $VagrantAPIMethod = "GET"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $AddBoxJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Get-VagrantCloudBoxVersion {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Updates a Vagrant Box on the Vagrant Cloud with new information.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will update Vagrant Box details on the Vagrant Cloud. 
This does not update box versions. Use Set-VagrantCloudBoxVersion instead.

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER VagrantCloudBoxVersion
A version incremental number. Uses Semantic Versioning. See related links for details.
Alias: version


.EXAMPLE
Below is an example specifying values at the console window.
#Get-VagrantBoxVersion -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -BoxVersion "1.0.0" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html
https://semver.org/

.INPUTS
System.Collections.Hashtable

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [alias("version")]
        [string]$VagrantCloudBoxVersion
    )
    
    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName/version/$VagrantCloudBoxVersion"
    $VagrantAPIMethod = "GET"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Get-VagrantCloudOrganization {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>
    <#

.SYNOPSIS
Retrieves data on an organization.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
Retrieves data on an organization.

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.EXAMPLE
Get-VagrantCloudOrganization -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.INPUTS
System.Collections.Hashtable

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [parameter(
            Mandatory = $true
        )]
        [alias("user")]
        [string]$VagrantCloudUser
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/user/$VagrantCloudUser"
    $VagrantAPIMethod = "GET"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Get-VagrantCloudProvider {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>
    <#

.SYNOPSIS
Gathers information on a Vagrant Provider located in the Vagrant Cloud. 
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
Gathers information on a Vagrant Provider located in the Vagrant Cloud. 

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER VagrantCloudBoxName
The Box Name
Alias: name

.PARAMETER ProviderName
Your Vagrant Provider Name
Alias: provider

.PARAMETER Version
The Provider Version

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.EXAMPLE
Returns information from Vagrant Cloud on the specified provider.
Get-VagrantCloudBox -VagrantCloudUsername "vagrantadmin" -Provider "virtualbox" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("provider")]
        [string]$ProviderName,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$VagrantCloudBoxName,

        [parameter(
            Mandatory = $true
        )]
        [alias("version")]
        [string]$VagrantCloudBoxVersion,

        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$VagrantCloudBoxName/version/$VagrantCloudBoxVersion/provider/$ProviderName"
    $VagrantAPIMethod = "GET"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function New-VagrantCloudAPIToken {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Creates a new Vagrant Cloud API Token.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This function creates a new Vagrant Cloud API Token.

.PARAMETER Enable2FA
A two-factor authentication code. Required to use this API method if 2FA is enabled. Use New-Enable2FA to request a code.
Alias: 2facode

.PARAMETER VagrantTokenDescription
The provider used by the Vagrant box
Alias: description  

.EXAMPLE
Below is an example specifying values at the console window.
New-VagrantCloudAPIToken -VagrantCloudUsername "vagrantadmin" -VagrantCloudPassword "qcyq8aNhTbSj7q4" -VagrantTokenDescription "Generated with PowerShell!"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.INPUTS
System.Collections.Hashtable

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [alias("description")]
        [string]$VagrantTokenDescription,

        [alias("2facode")]
        [boolean]$Enable2FA
    )
    $VagrantAccountDetails = (Get-Credential -Message "Enter your Vagrant Cloud Account Information")
    $ConvertVagrantPassword = $VagrantAccountDetails.GetNetworkCredential().Password

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/authenticate"
    $VagrantAPIMethod = "POST"

    # Create token json dataset
    $TokenHash = [ordered]@{
        token = @{
            description = $VagrantTokenDescription
        }
        user  = [ordered]@{
            login    = $($VagrantAccountDetails.UserName)
            password = $ConvertVagrantPassword
        }
    }

    if ($Enable2FA) {
        # If account uses Two-Factor Authentication, we need to add such data to our original token dataset
        $2FACode = Read-Host -Prompt "Enter two-factor code"
        $2FAHashTable = @{
            two_factor = @{
                code = $2FACode
            }
        }
        $TokenHash += $2FAHashTable
    }

    $TokenData = $TokenHash | ConvertTo-Json -Compress

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Body $TokenData -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function New-VagrantCloudBox {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Creates a new Vagrant Box on the Vagrant Cloud. 
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This function creates a new Vagrant Box on the Vagrant Cloud.

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER VagrantCloudBoxProvider
The provider used by the Vagrant box
Alias: provider

.PARAMETER VagrantCloudBoxDescription
A short description of the Vagrant Box, i.e, 'Windows Server 2019'
Alias: short_description

.PARAMETER BoxIsPrivate
Optional. Determines whether the box is a public or private box. Accepts boolean values.
DEFAULT IS PRIVATE. A Vagrant Cloud subscription is required to use private boxes.
Alias: is_private


.EXAMPLE
Below is an example specifying values at the console window.
New-VagrantCloudBox -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -VagrantCloudBoxProvider "virtualbox" -VagrantCloudBoxDescription "Ubuntu Bionic" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71" -BoxIsPrivate:$false

.EXAMPLE
This example utilizes hash table splatting to generate a new Vagrant Box.

# Generate a hash table of values
$boxvalues = @{
    username = 'vagrantadmin'
    name = 'ubuntu-bionic'
    token = 'a5db113927404aeb84a8aa2fc5ec4d71'
    provider = 'virtualbox'
    description = 'Ubuntu Bionic'
    # is_private is optional
    is_private = $false
}

New-VagrantCloudBox @boxvalues

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [parameter(
            Mandatory = $true
        )]
        [alias("provider")]
        [string]$VagrantCloudBoxProvider,
        [parameter(
            Mandatory = $true
        )]
        [alias("short_description")]
        [alias("is_private")]
        [boolean]$BoxIsPrivate
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/boxes"
    $VagrantAPIMethod = "POST"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    # Create Private Box Data Set
    $VagrantBoxData = [ordered]@{
        username          = $VagrantCloudUsername
        name              = $BoxName
        short_description = $VagrantCloudBoxDescription
    }
    if ($BoxIsPrivate) {
        $VagrantBoxData.Add("is_private", $true)
    }
    else {
        $VagrantBoxData.Add("is_private", $false)
    }

    # Create Nested Box Data for JSON
    $CreateBoxHashTable = @{
        box = $VagrantBoxData
    }
    # Create JSON necessary for submission
    $AddBoxJson = $CreateBoxHashTable | ConvertTo-Json -Compress

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $AddBoxJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function New-VagrantCloudBoxVersion {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Creates a version object for a Vagrant Box on the Vagrant Cloud.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will create a Vagrant Box version on the Vagrant Cloud. 

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER BoxVersionDescription
A short description of the Box version, i.e, 'Changes have been made to add packages'
Alias: description

.PARAMETER BoxVersion
A version incremental number. Uses Semantic Versioning. See related links for details.
Alias: version

.EXAMPLE
Below is an example specifying values at the console window.
New-VagrantCloudBoxVersion -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -BoxVersion "1.0.0" -BoxVersionDescription "Initial Version" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html
https://semver.org/

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [alias("version")]
        [string]$BoxVersion,
        [alias("description")]
        [string]$BoxVersionDescription
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName/versions"
    $VagrantAPIMethod = "POST"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    # Create Box Version Data
    $VagrantBoxVersionData = [ordered]@{
        version     = $BoxVersion
        description = $BoxVersionDescription
    }

    # Create Nested Version Data for JSON
    $VersionHashTable = @{
        version = $VagrantBoxVersionData
    }

    $NewBoxVersionJson = $VersionHashTable | ConvertTo-Json


    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $NewBoxVersionJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function New-VagrantCloudProvider {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Updates a Vagrant Box on the Vagrant Cloud with new information.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will create a new Vagrant Box Provider on the Vagrant Cloud. 

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER VagrantCloudBoxProvider
The name of the provider.
Alias: provider

.PARAMETER VagrantCloudBoxProviderURL
A valid URL to download this provider. If omitted, you must upload the Vagrant box image for this provider to Vagrant Cloud before the provider can be used.
Alias: url


.EXAMPLE
Below is an example specifying values at the console window.
New-VagrantCloudProvider -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -VagrantCloudBoxProvider "virtualbox" -VagrantCloudBoxProviderURL https://example.com/virtualbox-1.2.3.box

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [alias("provider")]
        [string]$VagrantCloudBoxProvider,
        [alias("url")]
        [string]$VagrantCloudBoxProviderURL
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName/version/$BoxVersion/providers"
    $VagrantAPIMethod = "POST"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    # Create Box Provider Data
    $VagrantBoxProviderData = [ordered]@{
        name = $VagrantCloudBoxProvider
        url  = $VagrantCloudBoxProviderURL
    }

    # Create Nested Version Data for JSON
    $VersionHashTable = @{
        provider = $VagrantBoxProviderData
    }

    $NewBoxProviderJson = $VersionHashTable | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $NewBoxProviderJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Remove-VagrantCloudAPIToken {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Removes a Vagrant Token from the Vagrant Cloud.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will remove a specified Vagrant Token from the Vagrant Cloud. 

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.EXAMPLE
Below is an example specifying values at the console window.
Remove-VagrantCloudToken -VagrantCloudToken "9OtpdAyFssBd3Q.atlasv1.vXczXnv5XsDGCbYtdZqqag8Nn9Fe7i73I1jzDgFL0G9iX4f1JtRXyo8CwH7G2F2VubI"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/authenticate"
    $VagrantAPIMethod = "DELETE"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Remove-VagrantCloudBox {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Removes a Vagrant Box from the Vagrant Cloud.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will remove a specified Vagrant Box from the Vagrant Cloud. 

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token


.EXAMPLE
Below is an example specifying values at the console window.
Remove-VagrantCloudBox -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -VagrantCloudToken "9OtpdAyFssBd3Q.atlasv1.vXczXnv5XsDGCbYtdZqqag8Nn9Fe7i73I1jzDgFL0G9iX4f1JtRXyo8CwH7G2F2VubI"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName"
    $VagrantAPIMethod = "DELETE"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    # Create Private Box Data Set
    $VagrantBoxData = [ordered]@{
        username = $VagrantCloudUsername
        name     = $BoxName
    }
    if ($BoxIsPrivate) {
        $VagrantBoxData.Add("is_private", $true)
    }
    else {
        $VagrantBoxData.Add("is_private", $false)
    }

    # Create Nested Box Data for JSON
    $CreateBoxHashTable = @{
        box = $VagrantBoxData
    }
    # Create JSON necessary for submission
    $AddBoxJson = $CreateBoxHashTable | ConvertTo-Json -Compress

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $AddBoxJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Remove-VagrantCloudBoxVersion {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Updates a Vagrant Box on the Vagrant Cloud with new information.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will update Vagrant Box details on the Vagrant Cloud. 
This does not update box versions. Use Set-VagrantCloudBoxVersion instead.

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER BoxVersion
A version incremental number. Uses Semantic Versioning. See related links for details.
Alias: version

.EXAMPLE
Below is an example specifying values at the console window.
Remove-VagrantCloudBoxVersion -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -BoxVersion "1.0.0" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html
https://semver.org/

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [alias("version")]
        [string]$BoxVersion
    )
    
    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName/version/$BoxVersion"
    $VagrantAPIMethod = "DELETE"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Remove-VagrantCloudProvider {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Removes a Vagrant Provider on the Vagrant Cloud.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
Removes a Vagrant Provider on the Vagrant Cloud.

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER ProviderName
Your Vagrant Provider Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER ProviderVersion
A version incremental number. Uses Semantic Versioning. See related links for details.
Alias: version

.EXAMPLE
Below is an example specifying values at the console window.
Remove-VagrantCloudProvider -VagrantCloudUsername "vagrantadmin" -ProviderName "virtualbox" -ProviderVersion "1.0.0" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html
https://semver.org/

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$ProviderName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [alias("version")]
        [string]$ProviderVersion
    )
    
    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$ProviderName/version/$ProviderVersion"
    $VagrantAPIMethod = "DELETE"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Set-VagrantCloudBox {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Updates a Vagrant Box on the Vagrant Cloud with new information.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will update Vagrant Box details on the Vagrant Cloud. 
This does not update box versions. Use Set-VagrantCloudBoxVersion instead.

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER VagrantCloudBoxProvider
The provider used by the Vagrant box
Alias: provider

.PARAMETER VagrantCloudBoxDescription
A short description of the Vagrant Box, i.e, 'Windows Server 2019'
Alias: short_description

.PARAMETER BoxIsPrivate
Optional. Determines whether the box is a public or private box. Accepts boolean values.
DEFAULT IS PRIVATE. A Vagrant Cloud subscription is required to use private boxes.
Alias: is_private


.EXAMPLE
Below is an example specifying values at the console window.
Set-VagrantCloudBox -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -VagrantCloudBoxProvider "virtualbox" -VagrantCloudBoxDescription "Updated Ubuntu Description" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71" -BoxIsPrivate:$false

.EXAMPLE
Below is an example passing variables from the Get-VagrantCloudBox command to set the description. Note that the token is required in both commands.
Get-VagrantCloudBox.ps1 -VagrantCloudUsername vagrantadmin -BoxName win2012core -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71" | Set-VagrantCloudBox.ps1 -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71" -VagrantCloudBoxDescription "Pipelines!

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [alias("is_private")]
        [boolean]$BoxIsPrivate,
        [alias("short_description")]
        [string]$VagrantCloudBoxDescription
    )

    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName"
    $VagrantAPIMethod = "PUT"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    # Update Box Data Set
    $VagrantBoxData = [ordered]@{
        username          = $VagrantCloudUsername
        name              = $BoxName
        short_description = $VagrantCloudBoxDescription
    }
    if ($BoxIsPrivate) {
        $VagrantBoxData.Add("is_private", $true)
    }
    else {
        $VagrantBoxData.Add("is_private", $false)
    }

    # Create Nested Box Data for JSON
    $CreateBoxHashTable = @{
        box = $VagrantBoxData
    }
    # Create JSON necessary for submission
    $UpdateBoxJson = $CreateBoxHashTable | ConvertTo-Json -Compress

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $UpdateBoxJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Set-VagrantCloudBoxProvider {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Updates a Vagrant Provider on the Vagrant Cloud with new information.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will update Vagrant Provider details on the Vagrant Cloud. 

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER ProviderName
Your Vagrant Provider Name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token


.EXAMPLE
Below is an example specifying values at the console window.
Set-VagrantCloudBoxProvider -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71" -ProviderName "virtualbox-iso" -URL "https://example.com/virtualbox-1.2.3.box"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

.OUTPUTS
System.Management.Automation.PSCustomObject

#>
    [CmdletBinding()]
    param(
        [parameter(
            Mandatory = $true
        )]
        [alias("username")]
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [string]$ProviderName,

        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,

        [parameter(
            Mandatory = $true
        )]
        [string]$URL
    )
    
    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName/version/$BoxVersion/provider/$ProviderName"
    $VagrantAPIMethod = "PUT"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    # Update Provider Data
    $VagrantProviderData = [ordered]@{
        name = $ProviderName
        url  = $URL
    }

    # Update Nested Version Data for JSON
    $ProviderHashTable = @{
        provider = $VagrantProviderData
    }

    $UpdatedProviderJson = $ProviderHashTable | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $UpdatedProviderJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}

Function Set-VagrantCloudBoxVersion {
    <#PSScriptInfo

.AUTHOR steven@automatingops.com

#>

    <#

.SYNOPSIS
Updates a Vagrant Box on the Vagrant Cloud with new information.
This requires a Vagrant Cloud API Token to use.

.DESCRIPTION
This is a PowerShell Core wrapper for the Vagrant API.
This will update Vagrant Box details on the Vagrant Cloud. 
This does not update box versions. Use Set-VagrantCloudBoxVersion instead.

.PARAMETER VagrantCloudUsername
Your Vagrant Cloud Username
Alias: username

.PARAMETER BoxName
Your Vagrant Box Name
Alias: name

.PARAMETER VagrantCloudToken
The Vagrant Cloud API Token
Alias: token

.PARAMETER VagrantCloudBoxProvider
The provider used by the Vagrant box
Alias: provider

.PARAMETER VagrantCloudBoxDescription
A short description of the Vagrant Box, i.e, 'Windows Server 2019'
Alias: short_description

.PARAMETER BoxIsPrivate
Optional. Determines whether the box is a public or private box. Accepts boolean values.
DEFAULT IS PRIVATE. A Vagrant Cloud subscription is required to use private boxes.
Alias: is_private


.EXAMPLE
Below is an example specifying values at the console window.
Set-VagrantCloudBoxVersion -VagrantCloudUsername "vagrantadmin" -BoxName "ubuntu-bionic" -BoxVersion "1.0.0" -BoxVersionDescription "Update Version" -VagrantCloudToken "a5db113927404aeb84a8aa2fc5ec4d71"

.LINK
https://www.vagrantup.com/docs/vagrant-cloud/api.html

#>
    [CmdletBinding()]
    param(
        [string]$VagrantCloudUsername,

        [parameter(
            Mandatory = $true
        )]
        [alias("name")]
        [string]$BoxName,
        [parameter(
            Mandatory = $true
        )]
        [alias("token")]
        [string]$VagrantCloudToken,
        [parameter(
            Mandatory = $true
        )]
        [alias("version")]
        [string]$VagrantCloudBoxVersion,
        [parameter(
            Mandatory = $true
        )]
        [alias("description")]
        [string]$BoxVersionDescription
    )
    
    $VagrantAPIURI = "https://app.vagrantup.com/api/v1/box/$VagrantCloudUsername/$BoxName/version/$VagrantCloudBoxVersion"
    $VagrantAPIMethod = "PUT"

    $VagrantCloudHeaders = @{
        Authorization = "Bearer $VagrantCloudToken"
    }

    # Update Box Version Data
    $VagrantBoxVersionData = [ordered]@{
        version     = $VagrantCloudBoxVersion
        description = $BoxVersionDescription
    }

    # Update Nested Version Data for JSON
    $VersionHashTable = @{
        version = $VagrantBoxVersionData
    }

    $UpdatedBoxVersionJson = $VersionHashTable | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $VagrantAPIURI -Headers $VagrantCloudHeaders -Body $UpdatedBoxVersionJson -Method $VagrantAPIMethod -ContentType "application/json"
    }
    catch {
        $Exception = $_
        Write-Error $Exception
    }
}
