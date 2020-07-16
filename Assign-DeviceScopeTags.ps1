# ***************************************************************************************************
# ***************************************************************************************************
#
#  Author       : Cary GARVIN (Script Main body)
#  Credit       : Microsoft   (Script functions)
#  Contact      : cary(at)garvin.tech
#  LinkedIn     : https://www.linkedin.com/in/cary-garvin
#  GitHub       : https://github.com/carygarvin/
#
#
#  Script Name  : Assign-DeviceScopeTags.ps1
#  Version      : 1.0
#  Release date : 06/01/2019 (CET)
#  History      : This script was written before Microsoft added the feature to set Device Scope tags based on groups.
#                 Before that Office 365 Intune feature was introduced, newly enrolled devices would need to have their Scope Tags assigned one by one by the Intune Administrator before Intune policies would trickle down onto the device.
#                 The present script alleviated this by allowing the Intune Administrator to programmatically set Scope Tags for all newly enrolled devices in one shot by running the present script based on a simple SMTP Domaint to Scope Tag mapping table.
#                 Script Main written by Cary GARVIN using only Functions from 2 scripts supplied by Microsoft
#                 Functions from the following 2 official Microsoft scripts are used in the present script:
# 		               Script 'RBAC_ScopeTags_DeviceAssign.ps1'      (https://github.com/microsoftgraph/powershell-intune-samples/tree/master/RBAC)
# 		               Script 'ManagedDevices_Get.ps1'               (https://github.com/microsoftgraph/powershell-intune-samples/tree/master/ManagedDevices)
#                 The Microsoft functions used from both scripts are as follows: 
#		               Function 'Get-AuthToken'                      From script 'RBAC_ScopeTags_DeviceAssign.ps1' or script 'ManagedDevices_Get.ps1'
#		               Function 'Get-ManagedDevices'                 Version with ID parameter from script 'RBAC_ScopeTags_DeviceAssign.ps1' and not the one from script 'ManagedDevices_Get.ps1' without ID parameter
#		               Function 'Get-ManagedDeviceUser'              From script 'ManagedDevices_Get.ps1'
#		               Function 'Get-AADUser'                        From script 'ManagedDevices_Get.ps1'
#		               Function 'Get-RBACScopeTag'                   From script 'RBAC_ScopeTags_DeviceAssign.ps1'
#		               Function 'Update-ManagedDevices'              From script 'RBAC_ScopeTags_DeviceAssign.ps1'
#                 
#  Purpose      : The present Script is written for organizations having several subsidiaries and wishing to handle mobile devices for each entity in a particular way through the use of specific Intune Scope Tags.
#                 The  Script sets Intune Scope Tags on all newly enrolled mobile devices (thus without any Scope Tag assigned) based on the Domain portion of the SMTP Address taken from the device's associated user's UPN (User Principal Name) of the user who enrolled the device.
#                 Such a script is especially usefull for Organizations who have several companies or Domains hosted in a single Office 365 tenant.
#                 If the Script is scheduled at regular intervals it can ensure newly enrolled devices get their Scope Tags assigned immediately and then have the right policies applied to the devices, as oposed as being left in limo until the Intune Adminstrator assgined the right Scope Tag.
#                 The present script alleviated this by allowing the Intune Administrator to set Scope Tags for all newly enrolled devices properly in one shot by running the present script.
#
#  The present Script relies on input file 'ScopeTagMappings.txt' to be present in the 'My Documents' folder of the current user.
#  The input file 'ScopeTagMappings.txt' is read and loaded into a Hashtable/Dictionnary variable called '$SMTPDomain2DeviceScopeTag' thus containing SMTP Domains to corresponding Intune Scope Tags mapping pairs.
#  Mappings are defined in this file in the format '@CompanyDomain.tld=CompanyScopeTag' such as the following example:
#                      @contoso.com=contoso
#  See sample file 'ScopeTagMappings.txt' for the correct input format for several Domains to Scope Tag pairs.
#




####################################################################################################
#                                       Script functions                                           #
####################################################################################################



Function Get-AuthToken
	{
	<#
	.SYNOPSIS
	This function is used to authenticate with the Graph API REST interface
	.DESCRIPTION
	The function authenticate with the Graph API Interface with the tenant name
	.EXAMPLE
	Get-AuthToken
	Authenticates you with the Graph API interface
	.NOTES
	NAME: Get-AuthToken
	#>

	[cmdletbinding()]

	param
		(
		[Parameter(Mandatory=$true)]
		$User
		)

	$userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
	$tenant = $userUpn.Host
	Write-Host "Checking for AzureAD module..."
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    If ($AadModule -eq $null)
		{
		Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
		$AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
		}

	If ($AadModule -eq $null)
		{
		write-host
		write-host "AzureAD Powershell module not installed..." -f Red
		write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
		write-host "Script can't continue..." -f Red
		write-host
		exit
		}

	# Getting path to ActiveDirectory Assemblies
	# If the module count is greater than 1 find the latest version

    If ($AadModule.count -gt 1)
		{
		$Latest_Version = ($AadModule | select version | Sort-Object)[-1]
		$aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }

		# Checking if there are multiple versions of the same module found
		If ($AadModule.count -gt 1)	{$aadModule = $AadModule | select -Unique}

		$adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
		$adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
		}
	Else
		{
		$adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
		$adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
		}

	[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null

	[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

	$clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"

	$redirectUri = "urn:ietf:wg:oauth:2.0:oob"

	$resourceAppIdURI = "https://graph.microsoft.com"

	$authority = "https://login.microsoftonline.com/$Tenant"

    try
		{
		$authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

		# https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
		# Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
		$platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"

		$userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")

		$authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

		# If the accesstoken is valid then create the authentication header
		If ($authResult.AccessToken)
			{
			# Creating header for Authorization token
			$authHeader = @{
				'Content-Type'='application/json'
				'Authorization'="Bearer " + $authResult.AccessToken
				'ExpiresOn'=$authResult.ExpiresOn
				}
			return $authHeader
			}
        Else
			{
			Write-Host
			Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
			Write-Host
			break
			}
		}
	catch
		{
		write-host $_.Exception.Message -f Red
		write-host $_.Exception.ItemName -f Red
		write-host
		break
		}
	}



Function Get-ManagedDevices()
	{
	<#
	.SYNOPSIS
	This function is used to get Intune Managed Devices from the Graph API REST interface
	.DESCRIPTION
	The function connects to the Graph API Interface and gets any Intune Managed Device
	.EXAMPLE
	Get-ManagedDevices
	Returns all managed devices but excludes EAS devices registered within the Intune Service
	.EXAMPLE
	Get-ManagedDevices -IncludeEAS
	Returns all managed devices including EAS devices registered within the Intune Service
	.NOTES
	NAME: Get-ManagedDevices
	#>

	[cmdletbinding()]

	param
		(
		[switch]$IncludeEAS,
		[switch]$ExcludeMDM,
		$DeviceName,
		$id
		)

	# Defining Variables
	$graphApiVersion = "beta"
	$Resource = "deviceManagement/managedDevices"

	try
		{
		$Count_Params = 0
		If ($IncludeEAS.IsPresent) {$Count_Params++}
		If ($ExcludeMDM.IsPresent) {$Count_Params++}
		If ($DeviceName.IsPresent) {$Count_Params++}
		If ($id.IsPresent) {$Count_Params++}
        
        If ($Count_Params -gt 1)
			{
			write-warning "Multiple parameters set, specify a single parameter -IncludeEAS, -ExcludeMDM, -deviceName, -id or no parameter against the function"
			Write-Host
			break
			}
		ElseIf ($IncludeEAS)
			{
			$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
			(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
			}
		ElseIf ($ExcludeMDM)
			{
			$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'eas'"
			(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
			}
		ElseIf ($id)
			{
			$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource('$id')"
			(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
			}
		ElseIf ($DeviceName)
			{
			$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=deviceName eq '$DeviceName'"
			(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
			}
		Else
			{
			$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'mdm' and managementAgent eq 'easmdm'"
			Write-Warning "EAS Devices are excluded by default, please use -IncludeEAS if you want to include those devices"
			Write-Host
			(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
			# (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | out-file mobiledevices.txt -append
			}
		}
    catch
		{
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		write-host
		break
		}
	}



Function Get-RBACScopeTag()
	{
	<#
	.SYNOPSIS
	This function is used to get scope tags using the Graph API REST interface
	.DESCRIPTION
	The function connects to the Graph API Interface and gets scope tags
	.EXAMPLE
	Get-RBACScopeTag -DisplayName "Test"
	Gets a scope tag with display Name 'Test'
	.NOTES
	NAME: Get-RBACScopeTag
	#>

	[cmdletbinding()]
	
	param
		(
		[Parameter(Mandatory=$false)]
		$DisplayName
		)

	# Defining Variables
	$graphApiVersion = "beta"
	$Resource = "deviceManagement/roleScopeTags"

    try
		{
		If ($DisplayName)
			{
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=displayName eq '$DisplayName'"
            $Result = (Invoke-RestMethod -Uri $uri -Method Get -Headers $authToken).Value
			}
		Else
			{
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
            $Result = (Invoke-RestMethod -Uri $uri -Method Get -Headers $authToken).Value
			}
		return $Result
		}
    catch
		{
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		write-host
		throw
		}
	}



Function Get-ManagedDeviceUser()
	{
	<#
	.SYNOPSIS
	This function is used to get a Managed Device username from the Graph API REST interface
	.DESCRIPTION
	The function connects to the Graph API Interface and gets a managed device users registered with Intune MDM
	.EXAMPLE
	Get-ManagedDeviceUser -DeviceID $DeviceID
	Returns a managed device user registered in Intune
	.NOTES
	NAME: Get-ManagedDeviceUser
	#>

	[cmdletbinding()]

	param
		(
		[Parameter(Mandatory=$true,HelpMessage="DeviceID (guid) for the device on must be specified:")]
		$DeviceID
		)

	# Defining Variables
	$graphApiVersion = "beta"
	$Resource = "deviceManagement/manageddevices('$DeviceID')?`$select=userId"

    try
		{
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
		Write-Verbose $uri
		(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).userId
		}
	catch
		{
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		write-host
		break
		}
	}



Function Get-AADUser()
	{
	<#
	.SYNOPSIS
	This function is used to get AAD Users from the Graph API REST interface
	.DESCRIPTION
	The function connects to the Graph API Interface and gets any users registered with AAD
	.EXAMPLE
	Get-AADUser
	Returns all users registered with Azure AD
	.EXAMPLE
	Get-AADUser -userPrincipleName user@domain.com
	Returns specific user by UserPrincipalName registered with Azure AD
	.NOTES
	NAME: Get-AADUser
	#>

	[cmdletbinding()]

	param
		(
		$userPrincipalName,
		$Property
		)

	# Defining Variables
	$graphApiVersion = "v1.0"
	$User_resource = "users"

	try
		{
        If ($userPrincipalName -eq "" -or $userPrincipalName -eq $null)
			{
			$uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)"
			(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
			}
		Else
			{
            If ($Property -eq "" -or $Property -eq $null)
				{
				$uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName"
				Write-Verbose $uri
				Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
				}
			Else
				{
				$uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName/$Property"
				Write-Verbose $uri
				(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
				}
			}
		}
    catch
		{
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		write-host
		break
		}
	}



Function Update-ManagedDevices()
	{
	<#
	.SYNOPSIS
	This function is used to add a device compliance policy using the Graph API REST interface
	.DESCRIPTION
	The function connects to the Graph API Interface and adds a device compliance policy
	.EXAMPLE
	Update-ManagedDevices -JSON $JSON
	Adds an Android device compliance policy in Intune
	.NOTES
	NAME: Update-ManagedDevices
	#>

	[cmdletbinding()]

	param
		(
		$id,
		$ScopeTags
		)

	$graphApiVersion = "beta"
	$Resource = "deviceManagement/managedDevices('$id')"

    try
    	{
		If ($ScopeTags -eq "" -or $ScopeTags -eq $null)
			{
$JSON = @"

{
  "roleScopeTagIds": []
}

"@
			}
        Else
			{
			$object = New-Object -TypeName PSObject
			$object | Add-Member -MemberType NoteProperty -Name 'roleScopeTagIds' -Value @($ScopeTags)
			$JSON = $object | ConvertTo-Json
			}

		$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
		Invoke-RestMethod -Uri $uri -Headers $authToken -Method Patch -Body $JSON -ContentType "application/json"
		Start-Sleep -Milliseconds 100
		}
    catch
		{
		Write-Host
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
		break
		}
	}




####################################################################################################
#                                          Script Main                                             #
####################################################################################################

<#
If (test-path "$($script:MyDocsFolder)\ScopeTagMappings.txt")
	{
	Try {$SMTPDomain2DeviceScopeTag = get-content "$($script:MyDocsFolder)\ScopeTagMappings.txt" | ConvertFrom-StringData}
	Catch
		{
		write-host "The format of input file '$($script:MyDocsFolder)\ScopeTagMappings.txt' is invalid" -foregroundcolor "red"
		write-host "Mappings should respect the pattern '@CompanyDomain.tld=CompanyScopeTag'" -foregroundcolor "white"
		write-host "For example '@contoso.com=contoso'" -foregroundcolor "white"
		write-host "Please correct entries in mappings file 'ScopeTagMappings.txt' and relaunch the script" -foregroundcolor "white"
		Break
		}
	
	$InvalidDomain = $SMTPDomain2DeviceScopeTag.Keys | ? { $_.SubString(0,1) -ne "@"}
	If ($InvalidDomain)
		{
		write-host "Invalid Domain format!" -foregroundcolor "red"
		$InvalidDomain
		write-host "All Domains in file 'ScopeTagMappings.txt' should start with '@'" -foregroundcolor "red"
		write-host "Please correct and relaunch the script" -foregroundcolor "white"
		Break
		}
	}
Else
	{
	write-host "File 'ScopeTagMappings.txt' not found! Aborting script." -foregroundcolor "red"
	Break
	}
	
write-host "Mappings dump of SMTP Domains to Intune Scope Tags from file 'ScopeTagMappings.txt':" -foregroundcolor "yellow"
$SMTPDomain2DeviceScopeTag
write-host




# Checking if authToken exists before running authentication
If ($global:authToken)
	{
    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

	If ($TokenExpires -le 0)
		{
		write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
		write-host

		# Defining User Principal Name if not present
		If ($User -eq $null -or $User -eq "")
			{
			$User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
			Write-Host
			}
		$global:authToken = Get-AuthToken -User $User
		}
	}

# Authentication doesn't exist, calling Get-AuthToken function
Else
	{
	If ($User -eq $null -or $User -eq "")
		{
		$User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
		Write-Host
		}
	# Getting the authorization token
	$global:authToken = Get-AuthToken -User $User
	}




# Getting list of Intune Scope Tages and their associated IDs
Write-Host
$ScopeTags = (Get-RBACScopeTag).displayName | sort
$ScopeTags2IDHT = @{}
$ScopeTags | ForEach {$ScopeTag = $_ ; $ScopeTags2IDHT.Add($_,(Get-RBACScopeTag | ? { $_.displayName -eq $ScopeTag }).id)}
write-host "Intune Scope Tags and corresponding IDs" -foregroundcolor "yellow"
$ScopeTags2IDHT
write-host



# Validating $SMTPDomain2DeviceScopeTag hashtable at top of script against reality of Scope Tags defined on the Office365 tenant
# Script aborts if a non existant Scope Tage is present in the hashtable
write-host "Validating SMTP Domain to Scope Tag table..." -foregroundcolor "yellow"
$SupportedSMTPDomains = @()
$ScopeTagsWithAssignments = @()
$SMTPDomain2DeviceScopeTag.GetEnumerator() | ForEach-Object {
	$message = 'SMTP Domain ''{0}'' will be assigned Scope Tag ''{1}''.' -f $_.key, $_.value
	Write-Output $message
	$SupportedSMTPDomains += $_.key
	$ScopeTagsWithAssignments += $_.value
	If ($ScopeTags.contains($_.value)) {write-host "'$($_.value)' is amongst the existing Intune Scope Tags" -foregroundcolor "green"}
	Else
		{
		write-host "Error: '$($_.value)' is NOT amongst the existing Intune Scope Tags!" -foregroundcolor "red"
		$ScopeTagFromHT = $_.value
		If ($ScopeTags -match $_.value) {write-host "Has Scope Tag '$($_.value)' into '$($ScopeTags | ?{$_ -match $ScopeTagFromHT})' been renamed?" -foregroundcolor "red"}
		write-host "Please correct invalid Scope Tag '$($_.value)' for SMTP Domain '$($_.key)'!" -foregroundcolor "red"
		write-host "The script will now abort." -foregroundcolor "white"
		Break
		}
	}
write-host
$ScopeTags | ForEach-Object {If (!($ScopeTagsWithAssignments.contains($_))) {write-host "Warning: Scope Tag '$_' from tenant does not have a corresponding SMTP Domain for device assignment!" -foregroundcolor "magenta"}}
write-host



# Enumerate through all InTune mobile devices and assign Scope Tags based on SMTP Domains for devices than have none, i.e. newly enrolled devices
$ManagedDevices = Get-ManagedDevices
If($ManagedDevices)
	{
	$NumberOfManagedDevices = $ManagedDevices.count
	$NumberOfNewManagedDevices = 0
    Foreach ($Device in $ManagedDevices)
		{
		$DeviceID = $Device.id
		$DeviceName = $Device.deviceName
		$Enroller = $Device.userPrincipalName

		write-host "Managed Device '$DeviceName' found..." -ForegroundColor Yellow

		$DeviceScopeTags = (Get-ManagedDevices -id $DeviceID).roleScopeTagIds
		If (($Device.deviceRegistrationState -eq "registered") -and ($DeviceScopeTags.count -eq 0))
			{
			$NumberOfNewManagedDevices++
			write-host "Device $DeviceName/$DeviceID enrolled by '$Enroller' has no Scope Tag. Assigning new Scope Tag!" -foregroundcolor "green"

			$UserId = Get-ManagedDeviceUser -DeviceID $DeviceID
			$User = Get-AADUser $userId

			Write-Host "`tDevice Registered User:" $User.displayName
			Write-Host "`tUser Principle Name   :" $User.userPrincipalName
			
			$UserSMTPDomain = $User.userPrincipalName.SubString($User.userPrincipalName.IndexOf("@"))
			
			If ($SupportedSMTPDomains.contains($UserSMTPDomain))
				{
				write-host "`tDevice '$DeviceName' from User '$($User.userPrincipalName)' will be assigned Scope Tag '$($SMTPDomain2DeviceScopeTag[$UserSMTPDomain])' with ScopeTagID '$($ScopeTags2IDHT.Item($SMTPDomain2DeviceScopeTag[$UserSMTPDomain]))'"
				# Actual Scope Tag assignment below
				$Result = Update-ManagedDevices -id $DeviceID -ScopeTags @($($ScopeTags2IDHT.Item($SMTPDomain2DeviceScopeTag[$UserSMTPDomain])))
				If ($Result -eq "") {Write-Host "New Device '$DeviceName' enrolled by $($User.userPrincipalName) patched with ScopeTag '$($SMTPDomain2DeviceScopeTag[$UserSMTPDomain])' corresponding to SMTP Domain $UserSMTPDomain..." -ForegroundColor "Green"}
				}
			Else {write-host "`tWarning: No corresponding Scope Tag has been specified in `$SMTPDomain2DeviceScopeTag hashtable for SMTP Domain '$UserSMTPDomain' of device user '$($User.userPrincipalName)'" -foregroundcolor "magenta"}
			}
		Else 
			{
			$STList = $DeviceScopeTags | % {$CurrentSCID = $_; $ScopeTags2IDHT.Keys | ? {$ScopeTags2IDHT[$_] -eq $CurrentSCID}}
			If ($STList -is [array]) {write-host "`tDevice enrolled by '$Enroller' already has Scope Tags '$($STList -join "', '")'."}
			Else {write-host "`tDevice enrolled by '$Enroller' already has Scope Tag '$STList'."}
			}
		Write-Host
		}
	If ($NumberOfNewManagedDevices -eq 0) {Write-Host "`r`nNo newly enrolled Managed Devices found amongst the $NumberOfManagedDevices present mobile devices in tenant...`r`n" -ForegroundColor "cyan"}
	Else {Write-Host "`r`n$NumberOfNewManagedDevices newly enrolled Managed Devices have been assigned corresponding Scope Tags...`r`n" -ForegroundColor "cyan"}
	}
Else {Write-Host "`r`nNo Managed Devices found in tenant...`r`n" -ForegroundColor cyan}
	
#>	

# ***************************************************************************************************
# ***************************************************************************************************
