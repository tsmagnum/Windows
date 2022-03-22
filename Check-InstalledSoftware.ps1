<#
.SYNOPSIS
This scripts checks if a specific software is installed on a Windows computer, producing a CSV report.

.DESCRIPTION
This scripts checks if a specific software is installed on a Windows computer, producing a CSV report.

.NOTES
To get the right software name for the $software variable, look for the registry key 
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" in a computer with the desired software installed: here there is 
a subkey for every software installed; look for the "DisplayValue" item in the subkey of your software.
You can add * as wildcards. 
For example, if you want to check for the .NET FX 4.7.2 set $software to "Microsoft .NET Framework 4.7.2*" .

Author: Federico Lillacci - Coesione Srl - https://github.com/tsmagnum

Link - https://github.com/tsmagnum/Windows/blob/master/Check-InstalledSoftware.ps1
#>

#region user-variables - please modify the values before running this script!
#Set the logfile name and path before running the script
$logFile = "C:\Scripts\SoftwareReport.csv"
#Set the target computers in a text file, one per line.
$targets = Get-Content "C:\Scripts\myComputers.txt"
#Set the name of the target software, please see the NOTES section above
$software = "Microsoft .NET Framework 4.7.2*"
#endregion

#Getting the user credential to run the check
$creds = Get-Credential

#Creating the logfile
Set-Content -Path $logFile -Value "Computer, InstallationStatus"

foreach ($target in $targets)
{
    #Checking if the target computer is online: if so, the check continues
    $pingtest = Test-Connection -ComputerName $target -Quiet -Count 1 -ErrorAction SilentlyContinue
    
    if ($pingtest)
    {
        Write-Host -ForegroundColor Yellow "Checking software on $target"
    
        try 
            {
                #Getting the installed software list
                $softwareList = Invoke-Command -Credential $creds -ComputerName $target `
                    -ScriptBlock {Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*}
            }
        catch 
            {
                Write-Host "The requested operation failed" -ForegroundColor Red
                Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red
                Add-Content -Path $logFile -Value "$target,error_notChecked" 
            }
        
        #Checking if the target software is present
        $installedSw = $softwareList | Where-Object {$_.DisplayName -like $software}

        If ( $installedSw.Count -gt 0)
            {
            Write-Host -ForegroundColor Green "The requested software is installed on $target"
            Add-Content -Path $logFile -Value "$target,Installed" 
            }
        else
           {
            Write-Host -ForegroundColor Red "The requested software is not installed on $target"
            Add-Content -Path $logFile -Value "$target,Not Installed" 
            }
    }
    
    #The computer is offline, skipping the check
    else
        {
            Write-Host -ForegroundColor Red "$target is offline, skipping check"
            Add-Content -Path $logFile -Value "$target,Offline_notChecked" 
        }
    
    }
