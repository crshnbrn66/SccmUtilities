# 
# NAME
#     Invoke-CCMAvailable
#     
# SYNTAX
#     Invoke-CCMAvailable  
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
function Invoke-CCMAvailable 
{

    $stopwatchTotal = [System.Diagnostics.Stopwatch]::StartNew()
    if(!(Get-WmiObject -class sms_client -Namespace root\ccm -ErrorAction Ignore))
    {
        $TimeReference = Get-Date
        $clientup = $null
        do{
            $execlog = (Get-CmLog -path c:\windows\ccm\logs\ccmExec.log  )
            $clientUp = $execlog |Where-Object{$_.Localtime -gt $TimeReference} | Where-object{$_.message -like "*Completed phase 1 initialization.  Service is now fully operational.*"}
            #write-output "sleeping 30 seconds - waiting for Sccm client to start $computername"   |Tee-Object -FilePath $log -Append
            Start-Sleep 30
   
        }While([string]::IsNullOrEmpty($clientup) -and ($stopwatchTotal.Elapsed.Minutes -lt 5))
        if($stopwatchTotal.Elapsed.Minutes -ge 5)
        {
            $false
        }
        $true
    }
    else
    {
        $true
    }


}
