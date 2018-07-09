$scripts = gci $PSScriptRoot\scripts\*.ps1
foreach($s in $scripts)
{
. "$($s.fullname)"
}