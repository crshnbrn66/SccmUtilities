# 
# NAME
#     Get-CMUpdateAssignments
#     
# SYNOPSIS
#     Short description
#     
#     
# SYNTAX
#     Get-CMUpdateAssignments [[-ComputerName] <Object>] [[-credential] <PSCredential>] [<CommonParameters>]
#     
#     
# DESCRIPTION
#     Long description
#     
# 
# RELATED LINKS
# 
# REMARKS
#     To see the examples, type: "get-help Get-CMUpdateAssignments -examples".
#     For more information, type: "get-help Get-CMUpdateAssignments -detailed".
#     For technical information, type: "get-help Get-CMUpdateAssignments -full".
# 
# 
# 
function Get-CMUpdateAssignments 
{

    param($ComputerName,
          [pscredential]$credential)
    if(Test-CCMLocalMachine $computerName)
    {
        $UpdateAssigment = Get-WmiObject -Query "Select * from CCM_AssignmentCompliance" -Namespace "root\ccm\SoftwareUpdates\DeploymentAgent"  -ErrorAction Stop 
        $UpdateCIAssigment = Get-WmiObject -Query "SELECT * FROM CCM_UpdateCIAssignment" -Namespace "ROOT\ccm\policy\machine\Actualconfig"  -ErrorAction Stop 
    
    }
    else
    {
        $UpdateAssigment = Get-WmiObject -Query "Select * from CCM_AssignmentCompliance" -Namespace "root\ccm\SoftwareUpdates\DeploymentAgent" -Computer $ComputerName -ErrorAction Stop -credential $credential
        $UpdateCIAssigment = Get-WmiObject -Query "SELECT * FROM CCM_UpdateCIAssignment" -Namespace "ROOT\ccm\policy\machine\Actualconfig" -ComputerName $ComputerName -ErrorAction Stop -credential $credential
    
    }
    #if update assignments were returned check to see if any are non-compliant
    if($UpdateAssigment)
    {
        $IsCompliant = $true 
        ForEach($u in $UpdateAssigment)
        {
            $ID = $u.AssignmentId
            $assignmentName = ($UpdateCIAssigment |  ?{$_.assignmentid -eq $u.AssignmentId}).AssignmentName
            if(!($u.IsCompliant))
            { $IsCompliant = $false} 

            #mark the compliance as false
            if($_.IsCompliant -eq $false -and $IsCompliant -eq $true){$IsCompliant = $false}
            [PscustomObject]@{'AssignmentName' = $assignmentName
                              'Compliant' = $IsCompliant
                              'ComputerName' = $ComputerName
                              'AssignmentId' = $u.AssignmentID
                              'isCompliant' = $u.IsCompliant
                              }
        }
    }
    else
    {
      [PscustomObject]@{'AssignmentName' = $null
        'Compliant' = $null
        'ComputerName' = $null
        'AssignmentId' =  $null
        'isCompliant' =  $null
        }
    }


}
