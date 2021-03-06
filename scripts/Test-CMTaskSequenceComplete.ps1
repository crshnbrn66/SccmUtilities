# 
# NAME
#     Test-CMTaskSequenceComplete
#     
# SYNTAX
#     Test-CMTaskSequenceComplete [-SiteServer] <Object> [-SiteCode] <Object> [-ComputerName] <Object> [-PastHours] 
#     <Object> [[-credential] <pscredential>]  [<CommonParameters>]
#     
# 
# ALIASES
#     None
#     
# 
# REMARKS
#     None
# 
# 
# 
function Test-CMTaskSequenceComplete 
{

    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true)]
    $SiteServer,
    [parameter(Mandatory=$true)]
    $SiteCode,
    [parameter(Mandatory=$true)]
    $ComputerName,
    [parameter(Mandatory=$true)]
    $PastHours,
    [pscredential]$credential
    )
    
    $TimeFrame = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime((Get-Date).AddHours(-$PastHours))
    if( (Resolve-DNS $SiteServer).hostname -eq (Resolve-DNS $env:COMPUTERNAME).hostname)
    {$TSSummary = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_StatusMessage -ComputerName $SiteServer -Filter "(Component like 'Task Sequence Engine') AND (MachineName like '$($ComputerName)' AND (MessageID = 11143))" -ErrorAction Stop}
    else
    {$TSSummary = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_StatusMessage -ComputerName $SiteServer -Filter "(Component like 'Task Sequence Engine') AND (MachineName like '$($ComputerName)' AND (MessageID = 11143))" -ErrorAction Stop  -credential $credential}
    $StatusMessageCount = ($TSSummary | Measure-Object).Count
    if (($TSSummary -ne $null) -and ($StatusMessageCount -eq 1)) {
        foreach ($Object in $TSSummary) {
            if (($Object.Time -ge $TimeFrame)) {
                $PSObject = New-Object -TypeName PSObject -Property @{
                    UTCTime = [System.Management.ManagementDateTimeconverter]::ToDateTime($Object.Time)
                    LocalTime = ([System.Management.ManagementDateTimeconverter]::ToDateTime($Object.Time)).toLocalTime()
                    MachineName = $Object.MachineName
                }
                Write-Output $PSObject
            }
        }
    }
    elseif (($TSSummary -ne $null) -and ($StatusMessageCount -ge 2)) {
        foreach ($Object in $TSSummary) {
            if ($Object.Time -ge $TimeFrame) {
                $PSObject = New-Object -TypeName PSObject -Property @{
                    UTCTime = [System.Management.ManagementDateTimeconverter]::ToDateTime($Object.Time)
                    LocalTime = ([System.Management.ManagementDateTimeconverter]::ToDateTime($Object.Time)).toLocalTime()
                    MachineName = $Object.MachineName
                }
                Write-Output $PSObject
            }
        }
    }
    else {
        Write-Output "No matches found"
    }


}
