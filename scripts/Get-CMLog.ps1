function Get-CMLog
{
<#
.SYNOPSIS
Parses logs for System Center Configuration Manager.
.DESCRIPTION
Accepts a single log file or array of log files and parses them into objects.  Shows both UTC and local time for troubleshooting across time zones.
.PARAMETER Path
Specifies the path to a log file or files.
.INPUTS
Path/FullName.  
.OUTPUTS
PSCustomObject.  
.EXAMPLE
C:\PS> Get-CMLog -Path Sample.log
Converts each log line in Sample.log into objects
UTCTime   : 7/15/2013 3:28:08 PM
LocalTime : 7/15/2013 2:28:08 PM
FileName  : sample.log
Component : TSPxe
Context   : 
Type      : 3
TID       : 1040
Reference : libsmsmessaging.cpp:9281
Message   : content location request failed
.EXAMPLE
C:\PS> Get-ChildItem -Path C:\Windows\CCM\Logs | Select-String -Pattern 'failed' | Select -Unique Path | Get-CMLog
Find all log files in folder, create a unique list of files containing the phrase 'failed, and convert the logs into objects
UTCTime   : 7/15/2013 3:28:08 PM
LocalTime : 7/15/2013 2:28:08 PM
FileName  : sample.log
Component : TSPxe
Context   : 
Type      : 3
TID       : 1040
Reference : libsmsmessaging.cpp:9281
Message   : content location request failed
.LINK
http://blog.richprescott.com
#>
    param(
    [Parameter(Mandatory=$true,
               Position=0,
               ValueFromPipelineByPropertyName=$true)]
    [Alias("FullName")]
    $Path,
    $tail
    )
    PROCESS
    {

        if(($Path -isnot [array]) -and (test-path $Path -PathType Container) )
        {
            $Path = Get-ChildItem "$path\*.log"
        }
        
        foreach ($File in $Path)
        {
            if(!( test-path $file))
            {
                $Path +=(Get-ChildItem "$file*.log").fullname
            }
            $FileName = Split-Path -Path $File -Leaf
            if($tail)
            {
                $lines = Get-Content -Path $File -tail $tail 
            }
            else {
                $lines = get-content -path $file
            }
            ForEach($l in $lines )
            {
                 
                    if($l -match '\<\!\[LOG\[(?<Message>.*[\w\W]*)?\]LOG\]\!\>\<time=\"(?<Time>.+)(?<TZAdjust>[+|-])(?<TZOffset>\d{2,3})\"\s+date=\"(?<Date>.+)?\"\s+component=\"(?<Component>.+)?\"\s+context="(?<Context>.*)?\"\s+type=\"(?<Type>\d)?\"\s+thread=\"(?<TID>\d+)?\"\s+file=\"(?<Reference>.+)?\"\>' )
                    {
                        #$UTCTime = [datetime]::ParseExact($("$($matches.date) $($matches.time)$($matches.TZAdjust)$($matches.TZOffset/60)"),"MM-dd-yyyy HH:mm:ss.fffz", $null, "AdjustToUniversal")
                        $LocalTime = [datetime]::ParseExact($("$($matches.date) $($matches.time)"),"MM-dd-yyyy HH:mm:ss.fff", $null)
                        $UTCTime = $LocalTime.ToUniversalTime()
                         [pscustomobject]@{         
                            UTCTime = $UTCTime
                            LocalTime = $LocalTime
                            FileName = $FileName
                            Component = $matches.component
                            Context = $matches.context
                            Type = $matches.type
                            TID = $matches.TI
                            Reference = $matches.reference
                            Message = $matches.message
                         }

                    }
                    elseif($l -match '\<\!\[LOG\[(?<Message>.*:)' )
                    {
                      $lineno = $j
                      for ($i = $lineno; $i -lt $lines.Count; $i++)
                      { 
                        if($lines[$i] -match '};')
                        {
                            $lns = $i - 1
                            $i=$lines.count
                        }
                      }
                      $Payload =  "$($lines[$lineno..$lns])`r`n};"
                      $payload -match '\<\!\[LOG\[(?<Message>.*[\w\W]*{)' |out-null

                      $message = ($matches['message'] -replace '{' ,'').Replace( "`n",' ')
                      $payload -match '{(?<w>[\w\W]*)}'  | Out-Null
                      $hash = New-Object hashtable
                      $m = ($matches['w'] -split ';').replace('"','') 
                      
                       $m|foreach{
                          if($_.contains('\'))
                            { 
                                $h = $_.replace("`t",'').replace(' ','')
                                ConvertFrom-StringData ([regex]::Escape($h))
                            }
                            else
                             { ConvertFrom-StringData $_ }

                      } | foreach{ $hash.add( "$($_.keys)" , "$($_.values)")}
                      
                      $dateTime =$hash['DateTime'] #.Substring(0,$hash['DateTime'].Length-4)
                      $UTCTime = ([datetime]::ParseExact($dateTime,"yyyyMMddHHmmss.ffffffzz\0",$null)).ToUniversalTime()

                      $dateTime2 =$hash['DateTime'].Substring(0,$hash['DateTime'].Length -4)
                      $LocalTime = [datetime]::ParseExact($dateTime,"yyyyMMddHHmmss\.ffffffzz\0",$null)
                      $message += "; $($hash.keys | %{ "$_ = $($hash[$_])  ; "} ) -join '')"
                        [pscustomobject]@{         
                            UTCTime = $UTCTime
                            LocalTime = $LocalTime
                            FileName = $FileName
                            Component = $matches.component
                            Context = $matches.context
                            Type = $matches.type
                            TID = $matches.TI
                            Reference = $matches.reference
                            Message = $message
                         }
                    }
                ++$J
            }
        }
    }
}
