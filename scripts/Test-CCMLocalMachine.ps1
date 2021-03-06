# 
# NAME
#     Test-CCMLocalMachine
#     
# SYNTAX
#     Test-CCMLocalMachine [[-ComputerName] <Object>]  
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
function Test-CCMLocalMachine 
{

    param( $ComputerName)
    
        $i = [system.net.dns]::GetHostAddresses('localhost').ipaddresstostring
        $result = $false
        $I+=[system.net.dns]::GetHostAddresses($env:COMPUTERNAME).ipaddresstostring

        if( ([system.net.dns]::GetHostAddresses($ComputerName).ipaddresstostring | Where-object{$i -contains $_}) -gt 0)
        {
          $result = $true
        }
    $result


}
