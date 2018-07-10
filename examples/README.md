# SccmUtilities - Example Scripts

These scripts show how to use the SCCM utilities function to allow for calling a task sequence. 
- sccm.ps1 - 
  no more than a wrapper script to call and execute SMSClientRe-install.ps1
- SMSClientRe-install.ps1 - 
  installing - or reinstalling a SCCM client.
- CopySMSclient.ps1 - 
  Copying the Sms client to destination using the system to be installed on to do the copy.
- callTaskSequence.ps1 - 
  Calls a task sequence that will patch a machine with the appropriate patches for a collection
