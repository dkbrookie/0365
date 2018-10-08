##Test for an open O365 session, connect if no session is open.
Stop-Transcript -EA 0 | out-null
Start-Transcript -path C:\O365\AIC\MbxResults.csv -append

$O365Connection = Get-PSSession
IF(!$O365Connection){
    ##Save the username to a text file so we can upload this to Github without exposing any confidential information
    $adminName = Get-Content "C:\O365\AIC\O365User.txt"
    $file = "C:\O365\AIC\Master_pwd.txt"
    $cred = new-object -TypeName System.Management.Automation.PSCredential -argumentlist $adminName, (Get-Content $file | ConvertTo-SecureString)
    Import-Module MSOnline
    Connect-MsolService -Credential $cred
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $cred -Authentication Basic -AllowRedirection
    Import-PSSession $session
}

#Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox"} | Set-Mailbox -AuditEnabled $true
#Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox"} | Set-Mailbox -AuditOwner MailboxLogin,HardDelete,MovetoDeletedItems,Move,SoftDelete
#Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox"} | Set-Mailbox -AuditLogAgeLimit 365
Get-Mailbox | Export-csv UserPrincipalName, AuditEnabled, AuditLogAgeLimit, AuditOwner, AuditDelegate, AuditAdmin, WhenMailboxCreated, WhenChanged -Append #| Format-Table UserPrincipalName, AuditEnabled, AuditLogAgeLimit, AuditOwner, AuditDelegate, AuditAdmin, WhenMailboxCreated, WhenChanged

Remove-PSSession $session

Stop-Transcript -EA 0 | out-null
