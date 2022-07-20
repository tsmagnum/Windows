<#
.SYNOPSIS
This script looks in Active Directory for users with an expiring password and sends them a password expiration alert via email.
.DESCRIPTION
This script looks in Active Directory for users with an expiring password and sends them a password expiration alert via email.
The script requires a Microsoft Secret Store Vault configured, in order to store and retrieve safely the credentials.
Please see the NOTES section for more info.
You need to run the script with a user authorized to read the users properties in Active Directory.
All the user-variables must be set before running the script!
.NOTES
A Microsoft Secret Store Vault is required to store and retrieve safely the SMTP credentials: please read this article to configure
the vault https://adamtheautomator.com/powershell-encrypt-password/ . The $vaultPass variable has to be set to the full path 
to the XML Secret Store Master Password. 
The vault should contain the credentials required to connect to the SMTP server (variable $secretEmailName). 
You can easily get this values using the 'Get-SecretInfo' cmdlet, 'Name' property.
$adminEmail is optional, is a CC: address you can use to send the password expiration reminders to admins too. If you want only the 
users to receive the emails, leave it blank "".
$max_alert is the number of days before password expiry that will trigger the password expiry reminder.
$mailmessage.Body is the email message body. You can modify it as per your requirement.

You need to run the script with a user authorized to read the users properties in Active Directory.

Author: Federico Lillacci - Coesione Srl - https://github.com/tsmagnum
Link - https://github.com/tsmagnum/Windows/blob/master/New-PasswordReminder.ps1
#>

#TLS Settings required for Office 365 SMTP server
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

#region user-variables - SET ALL THE VARIABLES BEFORE RUNNING THE SCRIPT!
$vaultPass = "C:\Scripts\vault\smtpVaultPassword.xml" #please see the NOTES section above
$secretEmailName = "SecretCred" #please see the NOTES section above
$dcName = "YourDomainControllerHostname" #the hostname of one domain controller of your domain
$domainName = "DC=yourdomain,DC=lan"
$smtpServer = "smtp.office365.com" #the SMTP server; you can use any SMTP server.
$smtpPort = 587 #the SMTP server port
$smtpSSL = $true #do we want a SSL connection to our SMTP server?
$emailFrom = "yourSender@yourdomain.com" #the mailbox you want to use to send the password expiration reminders
$adminEmail = "" #optional, a CC: address to send the the password expiration reminders; otherwise leave blank ""
$max_alert = 30 #how many days before password expiry do we start sending reminder emails?
#endregion

#region Functions

#Get the max Password Age from AD 
function Get-maxPwdAge{
   $root = [ADSI]"LDAP://$dcName"
   $filter = "(&(objectcategory=domainDNS)(distinguishedName=$domainName))"
   $ds = New-Object system.DirectoryServices.DirectorySearcher($root,$filter)
   $dc = $ds.findone()
   [int64]$maxpwdage = [System.Math]::Abs( $dc.properties.item("maxPwdAge")[0])
   $maxpwdage/864000000000
}

#Function to send HTML email to each user
function send_email ($days_remaining, $email, $name ) 
{
 $today = Get-Date
 $today = $today.ToString("dd-MM-yyy")
 $date_expire = [DateTime]::Now.AddDays($days_remaining);
 $date_expire = $date_expire.ToString("dd-MM-yyy")
 $SmtpClient = New-object system.net.mail.smtpClient 
 $mailmessage = New-Object system.net.mail.mailmessage 
 $SmtpClient.Host = $smtpServer  
 $SmtpClient.Port = $smtpPort
 $SmtpClient.EnableSsl = $smtpSSL
 $SmtpClient.Credentials = New-Object System.Net.NetworkCredential($emailCreds.UserName, $emailCreds.Password)
 $mailmessage.from =  $emailFrom
 $mailmessage.To.add($email)
 #if a $adminEmail is specified, it will be used as CC: address
    if ($adminEmail)
        { $mailmessage.cc.Add($adminEmail) }
 $mailmessage.Subject = "$name, La tua password sta per scadere."
 $mailmessage.IsBodyHtml = $true

 #The email message in HTML format
 $mailmessage.Body = @"
<h4><font face=Sans-Serif>Gentile $name, </font></h4>
<h4><font face=Sans-Serif>La tua password scade tra <font color=red><strong>$days_remaining</strong></font> giorni,
 il <strong>$date_expire</strong></h4><br />
Per cambiare la password, <strong>in sede o connessi in VPN</strong>, dal proprio computer premere CTRL-ALT-CANC e scegliere CAMBIA PASSWORD<br /><br />
Per essere valida, la password deve essere di almeno 10 caratteri e contenere un mix di TRE di questi QUATTRO componenti:<br /><br />
    lettere maiuscole (A-Z)<br />
    lettere minuscole (a-z)<br />
    numeri (0-9)<br />
    simboli (!?@()[]{}<>$%^&*)<br /><br />
Se avete domande, contattate i Sistemi Informativi. <br /><br />

NON COMUNICATE A NESSUNO LA VOSTRA PASSWORD, nemmeno ai Sistemi Informativi!<br /><br />

Messaggio generato il : $today<br /><br />
<br /></font>
"@

 $smtpclient.Send($mailmessage) 
}

#endregion

#Getting the safely stored credentials to send emails
$vaultpassword = (Import-CliXml $vaultPass).Password
Unlock-SecretStore -Password $vaultpassword
$emailCreds = (Get-Secret -Name $secretEmailName).GetNetworkCredential() | Select-Object Username,Password


#Search for Non-disabled AD users that have a Password Expiry.
$strFilter = "(&(objectCategory=User)(logonCount>=0)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(userAccountControl:1.2.840.113556.1.4.803:=65536)))"

$objDomain = New-Object System.DirectoryServices.DirectoryEntry
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = $objDomain
$objSearcher.PageSize = 1000
$objSearcher.Filter = $strFilter
$colResults = $objSearcher.FindAll();


#Getting the maximum password lifetime from AD
$max_pwd_life = Get-maxPwdAge

#Getting all the users that have a password expiring in the next $max_alert days
$userlist = @()
foreach ($objResult in $colResults)
   {$objItem = $objResult.Properties; 
   if ( $objItem.mail.gettype.IsInstance -eq $True) 
      {      
         #Transform the DateTime readable format
         $user_logon = [datetime]::FromFileTime($objItem.lastlogon[0])
         $result = $objItem.pwdlastset 
         $user_pwd_last_set = [datetime]::FromFileTime($result[0])

         #Calculate the difference in Day from last time a password was set
         $diff_date = [INT]([DateTime]::Now - $user_pwd_last_set).TotalDays;

   $Subtracted = $max_pwd_life - $diff_date
         if (($Subtracted) -le $max_alert) {
            $selected_user = New-Object psobject
            $selected_user | Add-Member NoteProperty -Name "Name" -Value $objItem.Item("displayname")
            $selected_user | Add-Member NoteProperty -Name "Email" -Value $objItem.mail[0]
            $selected_user | Add-Member NoteProperty -Name "LastLogon" -Value $user_logon
            $selected_user | Add-Member NoteProperty -Name "LastPwdSet" -Value $user_pwd_last_set
            $selected_user | Add-Member NoteProperty -Name "RemainingDays" -Value ($Subtracted)
            $userlist+=$selected_user
         }
      }
   }
   

#Sending an email to each user (and admins if selected)

   foreach ($userItem in $userlist )
   {
    if ($userItem.RemainingDays -ge 0) {
      send_email $userItem.RemainingDays $userItem.Email $userItem.Name
       }
   }
