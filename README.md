# Win 10 Update GUI
Implementation of a GUI for an existing ps1 script that shows/downloads available updates.
The script given by the customer has more capabilities but he only wants to manage Windows 10 updating.

## Installation:
* Paste the .exe file in the same folder where the scrips is located.
```
.\invoke-MSLatestUpdateDownload-GUI\Download-Latest-Cumulative-Update.exe
.\invoke-MSLatestUpdateDownload-GUI\Invoke-MSLatestUpdateDownload.ps1
```

## Release notes
# Version 1.0.0
* Functional GUI using a CMD shell in the background to let the PS1 script runs.

# Version 2.0.0
* GUI is now embedded in the exitent ps1 script, as a resulot we got one-file solution using only powershell code. 

## Thanks
Thanks to @NickolajA for his scripts, he developed the show/download script.
Thanks to my customer Franz from Germany, he asked me to develop this GUI.