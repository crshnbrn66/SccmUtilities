param(
    $sccmsetuplog = 'C:\windows\ccmsetup\logs\ccmsetup.log',
    $smsSiteString = 'SMSMP=cm02.corp.cmlab.com SMSSITECODE=TP1',
    $smsClientInstall = "$env:TEMP\SMS_ClientInstall",
    $scriptLog = "$smsClientInstall\install-log.txt"    
    ) #dev SMSMP=cm02.corp.cmlab.com SMSSITECODE=TP1 
#region functions
function New-SCCMSetupObject
{
    param($log)
    #<![LOG[MSI: Action 15:32:38: CcmRestorePowerScheme. Restore original power scheme.]LOG]!><time="15:32:38.560+360" date="12-18-2017" component="ccmsetup" context="" type="0" thread="5164" file="msiutil.cpp:316">
    #<![LOG[CcmSetup is exiting with return code 0]LOG]!><time="10:27:38.002+360" date="02-16-2018" component="ccmsetup" context="" type="1" thread="7556" file="ccmsetup.cpp:11051">
    #<![LOG[CcmSetup failed with error code 0x80004005]LOG]!><time="15:34:23.493+360" date="02-21-2018" component="ccmsetup" context="" type="1" thread="580" file="ccmsetup.cpp:11055">
    #$logs = (get-content $log | sls '<!\[LOG\[CCMSetup ' -AllMatches)[-1]
    $logs =[array](get-content $log  | Select-String 'CCMSetup ' -AllMatches)
    
    $results = @()
    foreach($aa in $logs)
    {
        $result = @{}
        $splita = $aa -split '!><'
        $a = ($splita[1]).trim('>')
        $status = ($splita[0]).trim('<!')
        $entries = ([regex]::Split($a,"`"*`""))
        foreach($e in $entries)
        {
            if($e -like "*=")
            {
               $value = $entries.IndexOf($e) + 1
               $name = ($e -replace "=",'').trim()
               if($name -eq 'time')
               {
                  $t = [datetime]( ($entries[$value]) -split '\+')[0]
                  $result.add($name,$t)
               }
               elseif($name -eq 'date')
               {
                $t = [datetime]($entries[$value])
                $result.add($name,$entries[$value])
                $days = ($t - $result['time'] ).days
                $result['time']=$result['time'].adddays($days)
                
               }
               elseif($entries[$value] -like "*=*")
               {$result.add($name, '')}
               else
               {$result.add($name, $entries[$value])}
            }
        }
        $result.add('status',$status)
        $results += new-object psobject -property $result
    }
    $results
}

function get-SCCMLastSuccess
{
    param($log)
    $r = New-SCCMSetupObject $log
    if($r.count -eq 1)
    {
        $r
    }
    else{($r| Sort-Object -Descending -Property date)[-1]}
    
}

function find-SCCMSetupLog
{
    (gci -Recurse c:\ccmsetup.log -ea Ignore).FullName
}
function Install-SCCMAgent
{
    param($smsClientInstall,$smsSiteString)
    $result = @()
    $result = "Start-Process -FilePath $smsClientInstall\ccmsetup.exe -ArgumentList $smsSiteString CCMLOGMAXSIZE=500000 CCMLOGMAXHISTORY=2 -Wait -PassThru"
    $result = Start-Process -FilePath "$smsClientInstall\ccmsetup.exe" -ArgumentList "$smsSiteString CCMLOGMAXSIZE=500000 CCMLOGMAXHISTORY=2" -Wait -PassThru
    $result
}
function Remove-SCCMAgent
{
    param($smsClientInstall)
    $result = Start-Process -FilePath 'C:\windows\CCMsetup\ccmsetup.exe' -ArgumentList '/uninstall' -Wait
    $result
}
function Get-SCCMClientVersion
{
    (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\sms\Mobile Client' -name productversion -ErrorAction Ignore).productversion
}
#endregion
#region StartTime
$scriptLog = $scriptLog.insert($scriptLog.indexOf('.'),"$(get-date -f 'MMddhhmmssyyy')") ;
new-item $scriptLog -ItemType file -Force
$sccmRegKey ='HKLM:\software\Microsoft\ccm'
If(test-path $sccmRegKey)
{
    Write-Output (Get-Date)  | Tee-Object -FilePath $scriptLog -Append;
    Write-Output 'removing SCCM Client' | Tee-Object -FilePath $scriptLog -Append ;
    Write-Output "SCCM version $(Get-SCCMClientVersion)" | Tee-Object -FilePath $scriptLog -Append;
    if(!(test-path $sccmsetuplog))
    {$sccmsetuplog =  find-SCCMSetupLog;}
    Remove-SCCMAgent -smsClientInstall $sccmsetuplog;
  
}
else
{ 
    Write-Output (Get-Date)  | Tee-Object -FilePath $scriptLog -Append; 
    Write-Output "No SCCM Agent key found: $sccmRegKey"  | Tee-Object -FilePath $scriptLog -Append;
}
$installStart = Get-Date ;
#endregion
#region install Client
$sccmsetuplog | Tee-Object -FilePath $scriptLog -Append ;
$smsSiteString | Tee-Object -FilePath $scriptLog -Append ;
$smsClientInstall | Tee-Object -FilePath $scriptLog -Append ;
$x = Install-SCCMAgent -smsClientInstall "$smsClientInstall\client" -smsSiteString $smsSiteString | Tee-Object -FilePath $scriptLog -Append ;
#endregion
#region Install complete?
$y = 0;
do 
{
    $obj = New-SCCMSetupObject -log $sccmsetuplog #create an object that contains the setup log
    if(($obj | Where-Object{$_.status -like '*CcmSetup is exiting with return code 0*'} | Where-Object{$_.time -gt $installStart}).time -gt $installStart) #look for install complete
    {
        #"Install status: $successSccm" | Tee-Object -FilePath $scriptLog -Append ;
        $installEnd = ($obj | Where-Object{$_.status -like '*CcmSetup is exiting with return code 0*'} | Where-Object {$_.time -gt $installStart});
        $installTime = New-TimeSpan -Start $installStart -End $installEnd.time;
        "Install Start: $installStart Install End:  $($successSccm.time) Total Install Time: $installTime Status: $($installEnd.status)" | Tee-Object -FilePath $scriptLog -Append ;
        if($installTime -gt 0)
        {
            Write-Output "SCCM Client installed successfully $($successSccm.time)" | Tee-Object -FilePath $scriptLog -Append;
        }
    
    elseif(($obj | Where-Object{$_.status -like '*CcmSetup failed with error code*'} | where-object{$_.time -gt $installStart}) )
    { #only run the install again if the install is not successful and we haven't run more than 3 times
        $ErrorLog = ($obj | ?{$_.status -like '*CcmSetup failed with error code*'} |where-object{$_.time -gt $installStart});
        If(test-path $sccmRegKey)
        {
            Write-Output "ERRROR with Install - removing SCCM Client -- SCCM Error $($ErrorLog.Status)"| Tee-Object -FilePath $scriptLog -Append ;
            Write-Output "SCCM version $(Get-SCCMClientVersion)" | Tee-Object -FilePath $scriptLog -Append;
            Remove-SCCMAgent -smsClientInstall $sccmsetuplog;
        }
        $x = Install-SCCMAgent -smsClientInstall "$smsClientInstall\client" | Tee-Object -FilePath $scriptLog -Append ;
        $y++;
        if($y -gt 3)
        {
            throw "Install of SCCM was un-successful check client $env:computername SCCM Setup Error $($ErrorLog.Status)" | Tee-Object -FilePath $scriptLog -Append ;
        }
    }
    else
    {
    Write-Output "Waiting on SCCM Client installer $(Get-Date)" | Tee-Object -FilePath $scriptLog -Append ;
    start-sleep -Seconds 60}
    }

}

while(!($installTime -gt 0))
#endregion
