param($computerName = 'dc01', $collectionName ='UPDATE NOW - Servers', $SiteServer = 'cm02.corp.cmlab.com', $AdvertisementID='', $Schedule = '',$siteCode = 'TP1' , $username, $password, $logfile = "$(Get-Date -Format 'yyyyMMddHHmmss')")
$pass = $Password | convertto-securestring -AsPlainText -force;
$credentials = new-object -typename system.management.automation.pscredential -argumentlist $username, $pass;
$timespan = New-TimeSpan
$sleepSeconds = 15
Start-Transcript -Path "c:\temp\$computername-CallTaskSequence-$logfile.log"

if ($MyInvocation.MyCommand.Path)
{
    $scriptpath = $MyInvocation.MyCommand.Path
    $d = Split-Path $scriptpath
    write-output -InputObject "Script Directory: `t`t$D"
    import-module "$d\sccmUtilities.psm1" -Force -DisableNameChecking 
    Import-Module psini
}
else
{
    import-module .\sccmUtilities.psm1 -Force -DisableNameChecking 
    Import-Module psini
}

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"# @initParams 
    (Get-Module ConfigurationManager).Version
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider "CMSite" -Root $SiteServer #@initParams
}
$id = 0
Push-Location
do
{
    $SMSID = Get-IniContent -FilePath "\\$computername\c`$\windows\SMSCFG.ini"
    $smsid = $smsid['Configuration - Client Properties']['SMS Unique Identifier']
    ++$id
}while(($SMSID -eq $Null) -and ($id -ne 5))

Write-Output "Actual smsguid $computerName`: $smsid"
Pop-Location

Push-Location
#region SITEDRIVE
Set-Location "$siteCode`:" -ErrorAction Ignore

$collectionId = ((Get-CMCollection) |Where-Object{$_.name -eq $collectionName}).collectionid
#turns out clientactivestatus 1 = online during testing it was found not set appeared to be null

$cmDevices = get-cmDevice -name $computerName |Where-Object{$_.smsid -ne $SMSID}
    foreach($c in $cmDevices)
    {
        if($c.cnisonline -eq $false)
        {
            write-output "Removing $($c.SMSID)"
            Remove-CMResource -ResourceId $c.ResourceID -Force #-WhatIf
        }

    } 
    
#check log for id clientIDManagerstartup.log
#with a status of approval status 1
$resourceCounter = 40
while([string]::IsNullOrEmpty($cmDevice) -and ($count -ne $resourceCounter))
{
    $cmDevice = Get-CMDevice -name $computerName 
    $resourceId = $cmDevice.Resourceid
    Write-Output "resourceid: $resourceid"
    ++$Count
    write-output 'Sleeping 15 seconds'
    #check to see if the client has finished the install against sccm
    if((!([string]::IsNullOrEmpty($cmDevice))) -and (Test-CCMClientInstalled -computerName $computerName -credential $credentials -Guid $SMSID))
    {
        $count = $resourceCounter    
    } 
    $timespan =$timespan.add($(new-timespan -Seconds $sleepSeconds))
    Start-Sleep $sleepSeconds
}
if($count -eq 5)
{
    throw 'Cannot Get Resource ID'
}
#region AddToCollection
if(!(Get-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionId -ResourceId $resourceId -ErrorAction Ignore))
{
    Add-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionId -ResourceId $resourceId 
}
$pendingupdates =  Get-CMClientPendingUpdates -ComputerName $computerName -credential $credentials
$SmsClient =[wmiclass]("\\$ComputerName\ROOT\ccm:SMS_Client")
$Sccmhash = New-CMSccmTriggerHashTable
if($credentials)
{
    Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $computername -Credential $credentials -Name TriggerSchedule -ArgumentList "$($Sccmhash["RequestMachinePolicyAssignments"])" 
    Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $computername -Credential $credentials -Name TriggerSchedule -ArgumentList "$($Sccmhash["EvaluateMachinePolicyAssignments"])" 
}
else
{
    $SmsClient.TriggerSchedule($Sccmhash['RequestMachinePolicyAssignments'])
    $SmsClient.TriggerSchedule($Sccmhash['EvaluateMachinePolicyAssignments'])
}
while(!(get-wmiobject -computername $ComputerName -query "SELECT * FROM CCM_SoftwareDistribution" -namespace "root\ccm\policy\machine\actualconfig" -Credential $credentials | where-object{$_.adv_advertisementid -eq $AdvertisementID}))
{
    ++$w
    Write-Output "getting actual config -- sleeping $($w * 10)"
    $timespan =$timespan.add($(new-timespan -Seconds $sleepSeconds))
    Start-Sleep $sleepSeconds
    If(($w % 6) -eq 0)
    {
        Write-Output 'Firing triggers again'
        if($credentials)
            {
                Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $computername -Credential $credentials -Name TriggerSchedule -ArgumentList "$($Sccmhash["RequestMachinePolicyAssignments"])" 
                Invoke-WmiMethod -Class sms_client -Namespace 'root\ccm' -ComputerName $computername -Credential $credentials -Name TriggerSchedule -ArgumentList "$($Sccmhash["EvaluateMachinePolicyAssignments"])" 
            }
            else
            {
                $SmsClient.TriggerSchedule($Sccmhash['RequestMachinePolicyAssignments'])
                $SmsClient.TriggerSchedule($Sccmhash['EvaluateMachinePolicyAssignments'])
            }
    }
    if($w -eq 24)
    {
        throw "Can't get schedule Assignment"        
    }
}
$pendingupdates = $true

$success = $false
new-psdrive -root "\\$computername\c$\windows\ccm\logs" -name log -PSProvider FileSystem -Credential $credentials
while($pendingupdates) # if there is no items in this list assume that the task sequence has not but executed yet.
{
    $startTaskSeq = invoke-command -ComputerName $computername -scriptblock {get-date} -Credential $credentials
    $a = get-wmiobject -computername $ComputerName -query "SELECT * FROM CCM_TaskSequence" -namespace "root\ccm\policy\machine\actualconfig"  -Credential $credentials | Where {$_.ADV_AdvertisementID -like "*$AdvertisementID*"}
    $a.ADV_MandatoryAssignments=$True
    $a.Put() | Out-Null
  
    Write-Output "Triggering the schedule now! -- $Schedule" 
    Invoke-WmiMethod -ComputerName $computerName -Namespace ROOT\ccm -Class SMS_Client -Name TriggerSchedule -ArgumentList "$Schedule"  -Credential $credentials | Out-Null
    
    #https://www.scconfigmgr.com/2014/04/29/use-powershell-to-determine-if-a-task-sequence-has-successfully-completed/
    $validationString = '*finalized logs to SMS client log directory from*'
    while(($success -eq $false) -and ($timespan.TotalMinutes -le 30 ))
    {
        $ping = test-connection -ComputerName $computerName -Count 1  -ErrorAction Ignore 
        if((test-path "log:\SMSTSLog" -PathType Container -ErrorAction Ignore) -and $Ping )
        {
            Write-Output "Task running found initial log on $computername"
            $smstslog = Get-CCMSpecificLog -ComputerName $computerName -path 'c:\windows\ccm\logs\smstslog' -log smsts -credential $credentials
                if($smstslog.smstslog |Where-Object{$_.message -like $validationString} )
                {
                $t = Test-CMTaskSequenceComplete -SiteServer $SiteServer -SiteCode $siteCode -ComputerName $computerName -PastHours 1 -credential $credentials
                $pendingupdates = Get-CMClientPendingUpdates -ComputerName $computerName -credential $credentials
                    if(($t.LocalTime -gt $startTaskSeq)-and(!$pendingupdates))
                    {
                        $success = $true
                    }
                }
        }
        elseif(($ping) -and (test-path  "log:\smsts.log"  -PathType Leaf))
        {
            Write-Output "Task running file merged to logs directory on $computername"
            $smstslog = Get-CCMSpecificLog -ComputerName $computerName -path 'c:\windows\ccm\logs' -log smsts -credential $credentials
            if($smstslog.smstslog |Where-Object{$_.message -like $validationString} )
            {
                write-output "found $validationstring in SMSTS.log file on $computername"
                $t = Test-CMTaskSequenceComplete -SiteServer $SiteServer -SiteCode $siteCode -ComputerName $computerName -PastHours 1 -credential $credentials
                $pendingupdates = Get-CMClientPendingUpdates -ComputerName $computerName -credential $credentials
                if(($t.LocalTime -gt $startTaskSeq)-and(!$pendingupdates))
                {
                    $success = $true
                }
            }
        }
        $timespan =$timespan.add($(new-timespan -Seconds $sleepSeconds))
        Start-Sleep -Seconds $sleepSeconds
        Write-Output "Pending update check -- Total Seconds Slept $($timespan.TotalSeconds)"
    }
}

if($success)
{
    write-output "Successfully installed and updated patches on $computername at $(get-date) completed in $($timespan.TotalMinutes) Minutes"
    #remove machine from the update collection
    if(Get-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionId -ResourceId $resourceId -ErrorAction Ignore)
    {
        Write-Output "Removing $computerName from $collectionName SMSGuid - $smsid SMSResourceID - $resourceid"
        Remove-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionId -ResourceId $resourceId -Force
    }
}

get-psdrive -Name log   | Remove-PSDrive
#end region
Pop-Location
get-psdrive -name $siteCode | remove-psdrive 
Stop-Transcript