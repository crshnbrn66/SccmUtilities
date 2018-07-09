param($computerName='dc01.corp.cmlab.com', $username='', $password = '', [ValidateSet("Prod", "Dev")]$environment = 'Dev' )
$computerName = (Resolve-DnsName $computerName).name;
$pw = ConvertTo-SecureString -String $password -AsPlainText -Force; 
$credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $username, $pw; 
if($environment -eq 'Dev')
{
    $sccmsetuplog = 'C:\windows\ccmsetup\logs\ccmsetup.log'
    $smsSiteString = 'SMSMP=cm02.corp.cmlab.com SMSSITECODE=TP1'
   
}
elseif($environment -eq 'Prod')
{
    $sccmsetuplog = 'C:\windows\ccmsetup\logs\ccmsetup.log'
    $smsSiteString = 'SMSMP=cm02.corp.cmlab.com SMSSITECODE=TP1'
}
else
{
    Throw "invalid value for $environment accepted values Dev / Prod"
}
if($MyInvocation.MyCommand.Path)
{
  $scriptpath = $MyInvocation.MyCommand.Path
  $d = Split-Path $scriptpath
}
$removeReinstall = Get-Content -raw "$d\SMSclientRe-install.ps1"
$scriptblockCheck = [scriptblock]::Create(@"
$removeReinstall
"@);
$sccmRun = Invoke-Command -ComputerName $computerName -ScriptBlock $scriptblockCheck -Credential $credential -ArgumentList $sccmsetuplog, $smsSiteString;
$sccmrunLog = "SCCM Re-install Complete? - $sccmRun $(get-date -format G)`r`n";
$sccmrunLog += "$environment -- Site -- $smsSiteString"
$sccmRunLog | out-file -FilePath "d:\ucsd\$computername-sccmRun.log" -Append;
$sccmRunlog;