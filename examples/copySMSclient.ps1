param($computerName ='DC01', $username ='Administrator', $password ='P@ssw0rd',[ValidateSet("Prod", "Dev")]$environment = 'Dev')
$scriptblock = @'
param($credential,$smsClientLocation)
$sccmsetuplog = 'C:\windows\ccmsetup\logs\ccmsetup.log'
$smsClientInstall = "$env:Temp\SMS_ClientInstall"
#$smsClientLocation = '\\cm02\SMS_TP1\Client'
$scriptLog = "$smsClientInstall\install-log.txt"

if($MyInvocation.MyCommand.Path)
{
  $scriptpath = $MyInvocation.MyCommand.Path
  $d = Split-Path $scriptpath
}
if(!(test-path $smsClientInstall))
{mkdir $smsClientInstall;}
new-psdrive -name dest -PSProvider FileSystem -Credential $credential -Root $smsClientInstall;
New-PSDrive -Name sms -PSProvider FileSystem -Credential $credential -Root $smsClientLocation;
Copy-Item  sms:\ -Recurse  -Destination dest:\ -Force -PassThru;
remove-psdrive sms;
remove-psdrive dest;
'@
if($environment -eq 'Dev')
{
    $smsClientLocation = '\\cm02\SMS_TP1\Client'
}
elseif($environment -eq 'Prod')
{
    $smsClientLocation = '\\cm02\SMS_TP1\Client'
}
else
{
    Throw "invalid value for $environment accepted values Dev / Prod"
}
$pw = ConvertTo-SecureString -String $password -AsPlainText -Force; 
$credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $username, $pw; 
$scriptblockCheck = [scriptblock]::Create($scriptblock);
Invoke-Command -ComputerName $computerName -ScriptBlock $scriptblockCheck -Credential $credential -ArgumentList $credential,$smsClientLocation ;
