function Test-CCMClientInstalled
{
    param($computerName, [pscredential]$credential, $Guid)
    $credentials = $credential
    try{
     $smstslog = Get-CCMSpecificLog -ComputerName $computerName -path 'c:\windows\ccm\logs' -log clientIDManagerstartup -credential $credential
     }
     catch
     {}
     $validationstring = "*$GUID*Approval status 1*"
     $success = $false
        if($smstslog.clientIDManagerstartuplog |Where-Object{$_.message -like $validationString} )
        {
            write-verbose "found $validationstring in SMSTS.log file on $computername"
            $success = $true
        }
    $success
}