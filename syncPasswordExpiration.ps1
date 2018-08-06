<#
-Summary-
Function 1)
This script finds the password expiration dates for all users in AD for the OU you specify in $ADOU, then compares that expiration date to the expiration date in O365. If the password is already expired in AD but the account is still active in O365, it will force a password reset on next login for that user in O365, and AD. By default, despite the password policy being set in O365, it will only give the user a notification that their password is expired but continue to allow them to use their account. With this script, you ensure a user is forced to change their password once it's expired. This does check both AD and O365 separately so if the password date is expired in O365 but not AD, it will only force the reset in O365 and the same in reverse.

Function 2)
This script also finds accounts in AD that have the "Password Never Expires" box checked and unchecks it, then sets the same property to unchecked in O365.
#>

##Define AD user info
##You can find the OU information for which OU you want to run this script on by opening AD, right clicking the OU you want to run this script on and go to Properties>Attribute Editor>DistinguishedName.
$ADOU = Get-Content "C:\Windows\LTSvc\ou.txt"
##Here is where you defines the DistinguishedName -notlike, it's listing the OU "Test Users". If you need to exclude a different OU just swap "Test Users", and you could also add additional OUs to exclude by adding -and $_.DistinguishedName -notlike "*,OU=Another OU Name,*"
$ADUsers = Get-ADUser -Filter * -SearchBase $ADOU | Where-Object {$_.DistinguishedName -notlike "*,OU=Test Users,*" -and $_.Enabled -eq $True} -EA 0 | Select -ExpandProperty SAMAccountName

##Test for an open O365 session, connect if no session is open.
$O365Connection = Get-PSSession
IF($O365Connection -eq $Null){
    $userName = Get-Content "C:\Windows\LTSvc\o365User.txt"
    $file = "C:\Windows\LTSvc\o365Cred.txt"
    $cred = new-object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, (Get-Content $file | ConvertTo-SecureString)
    Import-Module MSOnline
    Connect-MsolService -Credential $cred
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $cred -Authentication Basic -AllowRedirection
}

##Set O365/AD password policy
$expirDayPolicy = 90
$O365NotificationDays = 14
##Specify the domain for O365 you want to run this script on
$domain = "surgicalnotes.com"
Set-MsolPasswordPolicy -ValidityPeriod $expirDayPolicy -NotificationDays $O365NotificationDays -DomainName $domain


ForEach($ADUser in $ADUsers){
    $365User = "$ADUser@$domain"

    ##Get the last date the password was changed in AD
    $ADUserPassSet = Get-ADUser -Filter {Enabled -eq $True -and SamAccountName -eq $ADUser} -Properties PasswordLastSet -EA 0 | Select -ExpandProperty PasswordLastSet
    ##Get AD user "password never expires" status
    $ADNeverExpire = Get-ADUser -Filter {Enabled -eq $True -and SamAccountName -eq $ADUser} -Properties PasswordNeverExpires -EA 0 | Select -ExpandProperty PasswordNeverExpires
    $today = Get-Date
    ##Get the last date the password was changed in O365
    $O365PassAge = Get-MsolUser -userprincipalname $365User -EA 0 | Select -ExpandProperty LastPasswordChangeTimeStamp
    ##This is checking to see if the user has never set an O365 password before
    IF($O365PassAge -ne $Null -and $ADUserPassSet -ne $Null){
        Write-Output "===$ADUser==="
        IF($ADUserPassSet -eq $Null){
            $ADExpirDate = "$ADUser has never set a password in AD"
        }
        ELSE{
            $ADExpirDate = ($ADUserPassSet).adddays($expirDayPolicy)
            Write-Output "AD Expiration Date: $ADExpirDate"
        }
        IF($O365PassAge -eq $Null){
            $O365ExpirDate = "$ADUser has never set a password in O365"
        }
        ELSE{
            $O365ExpirDate = ($O365PassAge).adddays($expirDayPolicy)
            Write-Output "O365 Expiration Date: $O365ExpirDate"
        }
        Write-Output "Password Never Expires: $ADNeverExpire"
        IF($ADNeverExpire -eq $True){
            Set-ADUser -Identity $ADUser -PasswordNeverExpires $False
            Write-Output "Disabled the 'Password Never Expires' check box for $ADuser in AD"
        }
        IF($O365ExpirDate -lt $today){
            Set-MsolUserPassword -UserPrincipalName $365User -ForceChangePasswordOnly:$True -ForceChangePassword:$True
            Set-MsolUser -UserPrincipalName $365User -StrongPasswordRequired:$True
            Write-Output "Set O365 to force a password reset at next logon"
        }
        IF($ADExpirDate -lt $today){
            Set-ADUser -Identity $ADUser -ChangePasswordAtLogon $True
            Write-Output "Set AD to force a password reset at next logon"
        }
    }
    ELSE{
        Write-Output "===$ADUser==="
        "No password expiration information could be found. This generally means the user has never set a password."
    }
}
