# 
# NAME
#     Write-log
#     
# SYNTAX
#     Write-log [-Path] <string> [-Message] <string> [-Component] <string> [-Type] {Info | Warning | Error}  
#     [<CommonParameters>]
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
function Write-log 
{

    #https://janikvonrotz.ch/2017/10/26/powershell-logging-in-cmtrace-format/
    [CmdletBinding()]
    Param(
          [parameter(Mandatory=$true)]
          [String]$Path,

          [parameter(Mandatory=$true)]
          [String]$Message,

          [parameter(Mandatory=$true)]
          [String]$Component,

          [Parameter(Mandatory=$true)]
          [ValidateSet("Info", "Warning", "Error")]
          [String]$Type
    )

    switch ($Type) {
        "Info" { [int]$Type = 1 }
        "Warning" { [int]$Type = 2 }
        "Error" { [int]$Type = 3 }
    }

    # Create a log entry
    $Content = "<![LOG[$Message]LOG]!>" +`
        "<time=`"$(Get-Date -Format "HH:mm:ss.fff")+000`" " +`
        "date=`"$(Get-Date -Format "MM-dd-yyyy")`" " +`
        "component=`"$Component`" " +`
        "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
        "type=`"$Type`" " +`
        "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +`
        "file=`"$Path`">"

    # Write the line to the log file
    Add-Content -Path $Path -Value $Content


}
