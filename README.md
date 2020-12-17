# Assign-DeviceScopeTags.ps1
PowerShell Script to automatically assign Intune Device Scope Tags based on Primary SMTP Address of enrolling user.

Author       : Cary GARVIN (Script Main body)  
Credit       : Microsoft   (Script functions)  
Contact      : cary(at)garvin.tech  
LinkedIn     : [https://www.linkedin.com/in/cary-garvin](https://www.linkedin.com/in/cary-garvin)  
GitHub       : [https://github.com/carygarvin/](https://github.com/carygarvin/)  


Script Name  : [Assign-DeviceScopeTags.ps1](https://github.com/carygarvin/Assign-DeviceScopeTags.ps1/)  
Script URL   : [https://carygarvin.github.io/Assign-DeviceScopeTags.ps1/](https://carygarvin.github.io/Assign-DeviceScopeTags.ps1/)
Version      : 1.0  
Release date : 06/01/2019 (CET)  

History      : This script was written before Microsoft added to the Intune MDM product the feature to set Device Scope tags based on groups. Before that Office 365 Intune feature was introduced, newly enrolled devices would need to have their Scope Tags assigned one by one by the Intune Administrator before Intune policies would trickle down onto the device. The present script facilitates this by allowing the Intune Administrator to programmatically set Scope Tags for all newly enrolled devices in one shot by running the present script based on a simple SMTP Domain to Scope Tag mapping table.  
               PowerShell Script Main written by Cary GARVIN using only Functions from 2 scripts supplied by Microsoft.  
               
__Functions from the following 2 official Microsoft scripts are used in the present script:__  
* Script 'RBAC_ScopeTags_DeviceAssign.ps1'	[https://github.com/microsoftgraph/powershell-intune-samples/tree/master/RBAC](https://github.com/microsoftgraph/powershell-intune-samples/tree/master/RBAC)  
* Script 'ManagedDevices_Get.ps1'		[https://github.com/microsoftgraph/powershell-intune-samples/tree/master/ManagedDevices](https://github.com/microsoftgraph/powershell-intune-samples/tree/master/ManagedDevices)  
               
__The Microsoft functions used from both scripts are as follows:__  
* Function '_Get-AuthToken_' from script '_RBAC_ScopeTags_DeviceAssign.ps1_' or script '_ManagedDevices_Get.ps1_'  
* Function '_Get-ManagedDevices_'	from version with ID parameter from script '_RBAC_ScopeTags_DeviceAssign.ps1_' and not the one found in script '_ManagedDevices_Get.ps1_' without ID parameter  
* Function '_Get-ManagedDeviceUser_' from script '_ManagedDevices_Get.ps1_'  
* Function '_Get-AADUser_' from script '_ManagedDevices_Get.ps1_'  
* Function '_Get-RBACScopeTag_' from script '_RBAC_ScopeTags_DeviceAssign.ps1_'  
* Function '_Update-ManagedDevices_' from script '_RBAC_ScopeTags_DeviceAssign.ps1_'  
                 
Purpose      : The present Script is written for Organizations having several subsidiaries and wishing to handle mobile devices for each entity in a specific way through the use of specified Intune Scope Tags. The  Script sets Intune Scope Tags on all newly enrolled mobile devices (i.e. appearing without any Scope Tag) based on the Domain portion of the SMTP Address taken from the device's associated user's UPN (User Principal Name) who enrolled the device. Such a script is especially useful for Organizations which have several companies or Domains hosted in a single Office365 tenant. If the Script is scheduled at regular intervals it can ensure newly enrolled devices get their Scope Tags assigned immediately and then have the right policies applied to the devices (as opposed as being left in limbo until the Intune Administrator assigns the right Scope Tag). The present script enabled this by allowing the Intune Administrator to set Scope Tags for all newly enrolled devices efficiently in one shot by running the present script.  

# Script configuration  
The present Script relies on input file '_ScopeTagMappings.txt_' to be present in the 'My Documents' folder of the current user. The input file '_ScopeTagMappings.txt_' is read and loaded into a Hashtable/Dictionary variable called **$SMTPDomain2DeviceScopeTag** containing SMTP Domains to corresponding Intune Scope Tags mapping pairs. Mappings are defined in this file in the format `@CompanyDomain.tld=CompanyScopeTag` such as the following example:  

                          @contoso.com=contoso

See sample file '_ScopeTagMappings.txt_' for the correct input format for several Domains to Scope Tag pairs.  
