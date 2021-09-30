#region Credits
# Author: Federico Lillacci - Coesione Srl - www.coesione.net
# GitHub: https://github.com/tsmagnum
# Version: 1.0
#endregion

[CmdletBinding()]
$creds = Get-Credential
$reportDate = Get-Date -UFormat %d%m%Y

#######################################
#region User-variables - General Settings
$target = "server" # insert your NPS server here
$reportFormat = "html" # "console","html"
$reportHtmlPath = "NPS_VPN_Report_"+ $reportDate +".html"
#endregion

#region HTML Code
$preContent = "<h2>VPN Report</h2>"
$postContent = "<p>Creation Date: $(Get-Date)<p>"
$title = "NPS VPN Report"
#endregion

#region CSS Code
$header = @"
<style>
    body
  {
      background-color: White;
      font-size: 12px;
      font-family: Arial, Helvetica, sans-serif;
  }

    table {
      border: 0.5px solid;
      border-collapse: collapse;
      width: 100%;
    }

    th {
        background-color: CornflowerBlue;
        color: white;
        padding: 6px;
        border: 0.5px solid;
        border-color: #000000;
    }

    tr:nth-child(even) {
            background-color: #f5f5f5;
        }

    td {
        padding: 6px;
        margin: 0px;
        border: 1px solid;
}

    h2{
        background-color: CornflowerBlue;
        color:white;
        text-align: center;
    }
</style>
"@
#endregion

#region Functions
function reportHtml {
        
        [CmdletBinding()]
        Param(
                [Parameter(Mandatory = $true)] $rawStats,
                [Parameter(Mandatory = $false)] [switch] $generateFile
        )
        
        if ($generateFile) 
        { 
                $rawStats | `
                ConvertTo-Html `
                        -PreContent $preContent `
                        -PostContent $postContent `
                        -Title $title `
                        -Head $header | `
                        Out-File -FilePath $reportHtmlPath
        }

        else 
        {
                $rawStats | `
                ConvertTo-Html `
                        -PreContent $preContent `
                        -PostContent $postContent `
                        -Title $title `
                        -Head $header 
        }
}

function reportConsole ($rawStats){
        $rawStats | Sort-Object -Property $sortBy -Descending | Format-Table -AutoSize -Wrap
}
#endregion
#######################################

#Dot-sourcing the required script to manage logs
. .\Convert-EventLogRecord.ps1

#Selecting the logs time frame
$date = (Get-Date).AddDays(-1)

#Getting logs
$rawData = Get-WinEvent -FilterHashtable @{Logname="Security"; ID='6272','6273','6274'; StartTime=$date} -Credential $creds -ComputerName $target

#Filtering and processing
$filteredData = $rawData | Convert-EventLogRecord | Select-Object `
            -Property @{Label="Time";Expression={$_.TimeCreated}},`
                    @{Label="User";Expression={$_.SubjectUserName}},`
                    @{Label="IP Address";Expression={$_.CallingStationID}},`
                    @{Label="Success-Fail";Expression={$_.Keywords}},`
                    @{Label="Policy";Expression={$_.ProxyPolicyName}}

#Generating the report
switch ($reportFormat) 
{
    console { reportConsole($filteredData)}
    html { reportHtml -rawStats $filteredData -generateFile }
}
