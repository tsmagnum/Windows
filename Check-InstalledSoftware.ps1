#$creds = Get-Credential
#Set the logfile name and path before running the script
$logFile = "C:\temp\SoftwareReport.csv"
#Set the target computers in a textfile 
$targets = Get-Content "C:\Targets\ClientSede.txt"
#Set the name of the target software
$software = "*Password Solution*"
#$software2 = "Microsoft .NET Framework 4.8*"

#Creating the logfile
Set-Content -Path $logFile -Value "Computer, InstallationStatus, WindowsBuild"

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

                $windowsBuild = Invoke-Command -Credential $creds -ComputerName $target `
                    -ScriptBlock {Get-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object -ExpandProperty CurrentBuild}
            }
        catch 
            {
                Write-Host "The requested operation failed" -ForegroundColor Red
                Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red
                Add-Content -Path $logFile -Value "$target,error_notChecked" 
            }
        
        #Checking if the target software is present
        $installedSw = @()
        $installedSw += $softwareList | Where-Object {$_.DisplayName -like $software}

        If ( $installedSw.Count -gt 0)
            {
            Write-Host -ForegroundColor Green "The requested software is installed on $target"
            Add-Content -Path $logFile -Value "$target,Installed,$windowsBuild" 
            }
        else
           {
            Write-Host -ForegroundColor Red "The requested software is not installed on $target"
            Add-Content -Path $logFile -Value "$target,Not Installed,$windowsBuild" 
            }
    }
    
    else
        {
            Write-Host -ForegroundColor Red "$target is offline, skipping check"
            Add-Content -Path $logFile -Value "$target,Offline_notChecked" 
        }
    
    }

    #Report Summary
    $data = Import-Csv -path $logFile
    $installedStatus = $data | where-object {$_.InstallationStatus -eq "Installed"}
    $notInstalledStatus = $data | where-object {$_.InstallationStatus -ne "Installed"}
    Write-Host "#### Report Summary ####"
    Write-Host ""
    Write-Host "Total computers checked: $($data.count)"
    Write-Host "The desired software is installed on $($installedStatus.count) computers" -ForegroundColor Green
    Write-Host "The desired software is not installed on $($notInstalledStatus.count) computers" -ForegroundColor Red
