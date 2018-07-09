<#
.SYNOPSIS
Parses logs for System Center Configuration Manager.
.DESCRIPTION
Accepts a single log file or array of log files and parses them into objects.  Shows both UTC and local time for troubleshooting across time zones.
.ParameterETER Path
Specifies the path to a log file or files.
.INPUTS
Path/FullName.  
.OUTPUTS
PSCustomObject.  
.EXAMPLE
C:\PS> Get-CMLog -Path Sample.log
Converts each log line in Sample.log into objects
UTCTime   : 7/15/2013 3:28:08 PM
LocalTime : 7/15/2013 2:28:08 PM
FileName  : sample.log
Component : TSPxe
Context   : 
Type      : 3
TID       : 1040
Reference : libsmsmessaging.cpp:9281
Message   : content location request failed
.EXAMPLE
C:\PS> Get-ChildItem -Path C:\Windows\CCM\Logs | Select-String -Pattern 'failed' | Select -Unique Path | Get-CMLog
Find all log files in folder, create a unique list of files containing the phrase 'failed, and convert the logs into objects
UTCTime   : 7/15/2013 3:28:08 PM
LocalTime : 7/15/2013 2:28:08 PM
FileName  : sample.log
Component : TSPxe
Context   : 
Type      : 3
TID       : 1040
Reference : libsmsmessaging.cpp:9281
Message   : content location request failed
.LINK
http://blog.richprescott.com
#>

function Get-CCMLog 
{

    param([Parameter(Mandatory=$true,Position=0)]$ComputerName = '$env:computername', [Parameter(Mandatory=$true,Position=1)]$path = 'c:\windows\ccm\logs')
    DynamicParam
    {
        $ParameterName = 'Log'
        if($path.ToCharArray() -contains ':')
        {

            $FilePath = "\\$($ComputerName)\$($path -replace ':','$')"
        }
        else
        {
            $FilePath = "\\$($ComputerName)\$((get-item $path).FullName -replace ':','$')"
        }
        
        $logs = Get-ChildItem "$FilePath\*.log"
        $LogNames = $logs.basename

        $logAttribute = New-Object System.Management.Automation.ParameterAttribute
        $logAttribute.Position = 2
        $logAttribute.Mandatory = $true
        $logAttribute.HelpMessage = 'Pick A log to parse'                

        $logCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $logCollection.add($logAttribute)

        $logValidateSet = New-Object System.Management.Automation.ValidateSetAttribute($LogNames)
        $logCollection.add($logValidateSet)

        $logParam = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName,[string],$logCollection)

        $logDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $logDictionary.Add($ParameterName,$logParam)
        return $logDictionary
           
        
    }
    begin {
        # Bind the parameter to a friendly variable
        $Log = $PsBoundParameters[$ParameterName]
    }

    process {
        $i = [system.net.dns]::GetHostAddresses('localhost').ipaddresstostring
        $I+=[system.net.dns]::GetHostAddresses($env:COMPUTERNAME).ipaddresstostring
        if( ([system.net.dns]::GetHostAddresses($ComputerName).ipaddresstostring | Where-object{$i -contains $_}) -gt 0)
        {
            $results = get-cmlog -Path  "$path\$log.log"
        }
        else
        {
            $sb2 = "$((Get-ChildItem function:get-cmlog).scriptblock)`r`n"
            $sb1 = [scriptblock]::Create($sb2)
            $results = Invoke-Command -ComputerName $ComputerName -ScriptBlock $sb1 -ArgumentList "$path\$log.log"   
        }
        [PSCustomObject]@{"$($log)Log"=$results}
    }



}
