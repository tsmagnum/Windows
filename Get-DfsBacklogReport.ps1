<#
.SYNOPSIS
The script checks the DFS replication backlog on selected servers.
.DESCRIPTION
The script checks the DFS replication backlog on selected servers using dfsrdiag for backward compatibility with pre-2012 R2 servers. 
.EXAMPLE
Get-DfsBacklogReport.ps1 -sourceServer srv1 -destinationServer srv2
.PARAMETER sourceServer
The name of the sending DFS member server, e.g. srv1
.PARAMETER destinationServer
The name of the receiving DFS member server, e.g. srv2
.PARAMETER logFile
Full path for the logfile, e.g. C:\logs\mylog.txt . If omitted, it defaults to the user's desktop.
#>

#region Credits
# Author: Federico Lillacci - Coesione Srl - www.coesione.net
# Version: 1.0
#endregion

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $sourceServer,

    [Parameter(Mandatory=$true)]
    [string]
    $destinationServer,

    [Parameter(Mandatory=$false)]
    [string]
    $logFile = "$env:USERPROFILE\Desktop\DFS_Replica_Log.txt"
)

$replicatedFolders = Get-DfsReplicatedFolder | Select-Object GroupName,FolderName

foreach ($folder in $replicatedFolders)
{
    Write-Host "Analyzing Backlog for folder:" $folder.FolderName -ForegroundColor Yellow

   $cmd = '& dfsrdiag.exe Backlog /SendingMember:{0} /ReceivingMember:{1} /RGName:"{2}" /RFName:"{3}" '`
   -f $sourceServer, $destinationServer, $folder.GroupName, $folder.FolderName 

   Write-Output "Displaying Backlog for folder:" $folder.FolderName | Out-File -FilePath $logFile -Append
   Invoke-Expression $cmd | Out-File -FilePath $logFile -Append

}
