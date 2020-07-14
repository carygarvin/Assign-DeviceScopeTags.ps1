# Assign-DeviceScopeTags.ps1
PowerShell Script to automatically assign Intune Device Scope Tags based on Primary SMTP Address of enrolling user.

Author       : Cary GARVIN (Script Main body)  
Credit       : Microsoft   (Script functions)  
Contact      : cary(at)garvin.tech  
LinkedIn     : https://www.linkedin.com/in/cary-garvin-99909582  
GitHub       : https://github.com/carygarvin/  


Script Name  : Assign-DeviceScopeTags.ps1  
Version      : 1.0  
Release date : 06/01/2019 (CET)  

History      : This script was written before Microsoft added the feature to set Device Scope tags based on groups.  
               Before that Office 365 Intune feature was introduced, newly enrolled devices would need to have their Scope Tags assigned one by one by the Intune Administrator before Intune policies would trickle down onto the device.  
               The present script alleviated this by allowing the Intune Administrator to programmatically set Scope Tags for all newly enrolled devices in one shot by running the present script based on a simple SMTP Domaint to Scope Tag mapping table.  
               PowerShell Script Main written by Cary GARVIN using only Functions from 2 scripts supplied by Microsoft.  
               __Functions from the following 2 official Microsoft scripts are used in the present script:__  
* Script 'RBAC_ScopeTags_DeviceAssign.ps1'	(https://github.com/microsoftgraph/powershell-intune-samples/tree/master/RBAC)  
* Script 'ManagedDevices_Get.ps1'		(https://github.com/microsoftgraph/powershell-intune-samples/tree/master/ManagedDevices)  
               __The Microsoft functions used from both scripts are as follows:__   
* Function 'Get-AuthToken'			 From script 'RBAC_ScopeTags_DeviceAssign.ps1' or script 'ManagedDevices_Get.ps1'  
* Function 'Get-ManagedDevices'		 Version with ID parameter from script 'RBAC_ScopeTags_DeviceAssign.ps1' and not the one from script 'ManagedDevices_Get.ps1' without ID parameter  
* Function 'Get-ManagedDeviceUser'	  	 From script 'ManagedDevices_Get.ps1'  
* Function 'Get-AADUser'			 From script 'ManagedDevices_Get.ps1'  
* Function 'Get-RBACScopeTag'		 From script 'RBAC_ScopeTags_DeviceAssign.ps1'  
* Function 'Update-ManagedDevices'		 From script 'RBAC_ScopeTags_DeviceAssign.ps1'  
                 
Purpose      : The present Script is written for organizations having several subsidiaries and wishing to handle mobile devices for each entity in a particular way through the use of specific Intune Scope Tags.  
               The  Script sets Intune Scope Tags on all newly enrolled mobile devices (thus without any Scope Tag assigned) based on the Domain portion of the SMTP Address taken from the device's associated user's UPN (User Principal Name) of the user who enrolled the device.  
               Such a script is especially usefull for Organizations who have several companies or Domains hosted in a single Office 365 tenant.  
               If the Script is scheduled at regular intervals it can ensure newly enrolled devices get their Scope Tags assigned immediately and then have the right policies applied to the devices, as oposed as being left in limo until the Intune Adminstrator assgined the right Scope Tag.  
               The present script alleviated this by allowing the Intune Administrator to set Scope Tags for all newly enrolled devices properly in one shot by running the present script.  

# Script configuration:  
The present Script relies on input file 'ScopeTagMappings.txt' to be present in the 'My Documents' folder of the current user.  
The input file 'ScopeTagMappings.txt' is read and loaded into a Hashtable/Dictionnary variable called '$SMTPDomain2DeviceScopeTag' thus containing SMTP Domains to corresponding Intune Scope Tags mapping pairs.  
Mappings are defined in this file in the format '@CompanyDomain.tld=CompanyScopeTag' such as the following example:  
                '@contoso.com=contoso'  
See sample file 'ScopeTagMappings.txt' for the correct input format for several Domain to Scope Tag pairs.  
