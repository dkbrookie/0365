##powershell.exe -command "& {(new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/o365/master/O365.MigrateAzureToAD.ps1')}"

$answer = Read-Host "Are you running this from the DC server you want to create the users on? (y/n)"
If($answer -ne 'y') {
  Write-Warning "This script needs to be ran on the DC you want the users created on. Please run this on your desired DC server. Exiting script."
  Break
}

#region O365Connect
Try {
  ## If the msonline module isn't installed, install it
  IF($env:PSModulePath -notlike "*c:\Program Files\WindowsPowerShell\Modules*") {
    $env:PSModulePath = $env:PSModulePath + ";c:\Program Files\WindowsPowerShell\Modules"
  }
  If(!(Get-Module -ListAvailable -Name MSOnline)) {
    Install-Module MSOnline -Confirm:$False | Out-Null
  }
  If(!(Get-Module -ListAvailable -Name AzureAD)) {
    Install-Module AzureAD -Confirm:$False | Out-Null
  }

  ## Test for an open O365 session, connect if no session is open.
  Write-Host "You are about to be prompted for the O365 credentials of the tenant you want to get Azure AD users from..."
  Start-Sleep 3
  $O365Connection = Get-PSSession
  IF($O365Connection -eq $Null){
      $cred = Get-Credential
      Import-Module MSOnline
      Connect-MsolService -Credential $cred
      $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $cred -Authentication Basic -AllowRedirection
  }

  Import-Module AzureAD
  Connect-AzureAD -Credential $cred
} Catch {
  Write-Error "There was an issue installing / connecting to msonline, read error log for details"
}
#endregion O365Connect
Write-Warning "Passwords cannot be pulled from Azure AD Users, you must create a new password for all new users"
$pass = Read-Host "Please enter the password you would like to use for all new local AD users"
$DefaultPassword = (ConvertTo-SecureString $pass -AsPlainText -Force)
$azureUsers = Get-AzureADUser
$totalUsers = ($azureUsers).Count
Write-Output "$totalUsers Azure AD users have been discovered"
ForEach($user in $azureUsers) {
  $UserPrincipalName = $user.UserPrincipalName
  $Mail = $user.Mail
  $UserName = ($Mail) -Split '@' | Select-Object -First 1
  $AccountEnabled = $user.AccountEnabled
  $GivenName = $user.GivenName
  $SurName = $user.Surname
  $DisplayName = $user.DisplayName
  $JobTitle = $user.JobTitle
  $City = $user.City
  $State = $user.State
  $StreetAddress = $user.StreetAddress
  $PostalCode = $user.PostalCode
  $Country = $user.Country
  $Department = $user.Department
  $DisplayName = $user.DisplayName

  If(!($Mail)) {
    Write-Warning "Unable to find an email address for $UserPrincipalName, this user will NOT be created in AD!"
  } Else {
    $Mail = $Mail
  }
  If(!$GivenName) {
    Write-Warning "Unable to find a GivenName for $UserPrincipalName, this user will NOT be created in AD!"
    Continue
  } Else {
    $GivenName = $user.GivenName
  }
  If(!$Surname) {
    Write-Warning "Unable to find a Surname for $UserPrincipalName, this user will NOT be created in AD!"
    Continue
  } Else {
    $SurName = $user.Surname
  }
  If(!($DisplayName)) {
    $DisplayName = "$GivenName $SurName"
  } Else {
    $DisplayName = $user.DisplayName
  }
  If(!($Mail)) {
    Write-Warning "Unable to find an email address for $UserPrincipalName, this user will NOT be created in AD!"
  } Else {
    $Mail = $user.Mail
  }
  If(!$TelephoneNumber) {
    $TelephoneNumber = $Null
  }
  If(!$JobTitle) {
    $JobTitle = $Null
  }
  If(!$Department) {
    $Department = $Null
  }


  ## Create AD user account
  $Name = "$GivenName $Surname"
  $NewUserParams = @{
    'UserPrincipalName' = $UserName
    'Name' = $Name
    'SamAccountName' = $UserName
    'GivenName' = $GivenName
    'SurName' = $Surname
    'Title' = $JobTitle
    'AccountPassword' = (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force)
    'Enabled' = $user.AccountEnabled
    'ChangePasswordAtLogon' = $true
    'City' = $City
    'State' = $State
    'StreetAddress' = $StreetAddress
    'PostalCode' = $PostalCode
    'Department' = $Department
    'DisplayName' = $DisplayName
    'EmailAddress' = $Mail
  }
  $userTest = Get-ADUser -Filter {(UserPrincipalName -eq $Username)}
  If(!$userTest) {
    Write-Output "Creating an AD account for $name"
    New-ADUser @NewUserParams
  } Else {
    Write-Output "$Username already exists!"
  }
}
