#Requires -RunAsAdministrator
param($computerName = "$env:COMPUTERNAME", $logpath ="c:\temp\patchApply.log" )

#Start-Transcript -Path "D:\ucsd\$computername-SccmCollection-$logfile.log" -Append
$stopwatchTotal = [System.Diagnostics.Stopwatch]::StartNew()
if ($MyInvocation.MyCommand.Path)
{
    $scriptpath = $MyInvocation.MyCommand.Path
    $d = Split-Path $scriptpath
    write-output -InputObject "Script Directory: `t`t$D"
    if((test-path "$d\sccmUtilities.psm1"))
    {
        import-module "$d\sccmUtilities.psm1" -Force -DisableNameChecking 
    }
    else
    {
        Throw "supporting Modules not present"
        write-log -Path $logpath -Message "supporting Modules not present"  -Component getAvailupdates -Type Error 
        exit 1
    }
}
else
{
    if((test-path ".\sccmUtilities.psm1"))
    {
        import-module .\sccmUtilities.psm1 -Force -DisableNameChecking 
    }
    else
    {
        Throw "supporting Modules not present"
        write-log -Path $logpath -Message "supporting Modules not present"  -Component getAvailupdates -Type Error 
        exit 1
    }
}
#test
$Sccmhash = New-CMSccmTriggerHashTable
write-log -Path $logpath -Message "Started GetAvailUpdates" -Component getAvailupdates -Type Info
#region ForceUpdateScan
$complete = $false
do {
    $ForceUpdate = Invoke-CMForceUpdatescan -computername $computername 
    # peforms task on the client of forcupdatescan = {00000000-0000-0000-0000-000000000113}
    do {
    $done=Test-CMForceUpdateScan -computername $computername -TimeReference $ForceUpdate.timereference[1]
        #looks in wmi for verification that the schedule id was recieved by the client.
    } while([string]::IsNullOrEmpty($done) -or $done -eq $false)
    #Write-Output "Force Update completed at $($stopwatchTotal.Elapsed.Minutes) minutes into Script Run"  |Tee-Object -FilePath $log -Append 
    $msg="Force Update completed at $($stopwatchTotal.Elapsed.Minutes) minutes into Script Run"
    write-log -Path $logpath -Message $msg  -Component getAvailupdates -Type Info 
    #endregion ForceUpdateScan

    #region RequestMachinePolicyAssignments
    $RequestMachinePolicyAssignments = Invoke-CMRequestMachinePolicyAssignments -computername $computername  -Path c:\windows\ccm\logs
    #performs a requestMachinePolicyAssignments {00000000-0000-0000-0000-000000000021}
    do {
        $done=Test-CMRequestMachinePolicyAssignments -computername $computername -Path c:\windows\ccm\logs -TimeReference $RequestMachinePolicyAssignments.timereference[1] 
        Start-Sleep -Seconds 30
        #Write-Output "Sleeping 30 seconds looking for --[ Evaluation not required. No changes detected ]-- in: policyevaluator log Minutes-- $($stopwatchTotal.Elapsed.Minutes)" |Tee-Object -FilePath $log -Append 
        $msg = "Sleeping 30 seconds looking for --[ Evaluation not required. No changes detected ]-- in: policyevaluator log Minutes-- $($stopwatchTotal.Elapsed.Minutes)"
        write-log -Path $logpath -Message $msg  -Component getAvailupdates -Type Info 
        # this loops through the log policyevaluator log looking for the following entry:  Evaluation not required. No changes detected.
    } while([string]::IsNullOrEmpty($done) -or $done -eq $false)
   # Write-Output "Request MachinePolicy Assignments completed at $($stopwatchTotal.Elapsed.Minutes) into Script Run" |Tee-Object -FilePath $log -Append
    $msg = "Request MachinePolicy Assignments completed at $($stopwatchTotal.Elapsed.Minutes) into Script Run"
        write-log -Path $logpath -Message $msg  -Component getAvailupdates -Type Info 
    #endregion RequestMachinePolicyAssignments

    #region SoftwareUpdatesAgentAssignmentEvaluationCycle
    $SoftwareUpCycle = Invoke-CMSoftwareUpdatesAgentAssignmentEvaluationCycle -computername $computername -path C:\Windows\ccm\logs  
    # triggers the sccm schedule SoftwareUpdatesAgentAssignmentEvaluationCycle {00000000-0000-0000-0000-000000000108}
    do {
        $done = Test-CMSoftwareUpdatesAgentAssignmentEvaluationCycle -computername $computername -path c:\windows\ccm\logs -TimeReference $SoftwareUpCycle.timereference[1]
        sleep -Seconds 15
        #this loops through the following log SmsClientMethodProvider looking for the fact that the method for triggering this was called: {00000000-0000-0000-0000-000000000108}
    } while([string]::IsNullOrEmpty($done) -or $done -eq $false)
    #Write-Output "Software Updates Agent Assignment Evaluation Cycle completed at $($stopwatchTotal.Elapsed.Minutes) minutes into Script Run" |Tee-Object -FilePath $log -Append
    $msg = "Software Updates Agent Assignment Evaluation Cycle completed at $($stopwatchTotal.Elapsed.Minutes) minutes into Script Run"
    write-log -Path $logpath -Message $msg  -Component getAvailupdates -Type Info 
    #endregion SoftwareUpdatesAgentAssignmentEvaluationCycle
    
    #region updateCheck
    $PendingUpdates = Get-CMClientPendingUpdates -ComputerName $computerName |Select-Object Name, ArticleID
    #gets the pending updates for the machine after the triggers above have completed.
    #endregion updateCheck
    #Write-Output "Found - $($PendingUpdates.count) updates" |Tee-Object -FilePath $log -Append
    $msg = "Found - $($PendingUpdates.count) updates"
    write-log -Path $logpath -Message $msg  -Component getAvailupdates -Type Info
    #Write-Output $PendingUpdates |Tee-Object -FilePath $log -Append

    
    #region installupdate
   if ($PendingUpdates)
   {
    write-log -Path $logpath -Message "$($PendingUpdates.name -join ', ')" -Component getAvailupdates -Type Info
    $complete = $true
   }
   else 
   {
    write-log -Path $logpath -Message "NO UPDATES FOUND" -Component getAvailupdates -Type Info
    $complete = $true
   }
} while( $complete -eq $false)
write-log -Path $logpath -Message "GetAvailUpdates Complete" -Component getAvailupdates -Type Info
Pop-Location
#Stop-Transcript