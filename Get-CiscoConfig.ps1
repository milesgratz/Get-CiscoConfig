Function Get-CiscoConfig {
<#
.DESCRIPTION
  Script to backup Cisco switch (running-config) to file

.PARAMETERS
  List                  (MANDATORY)         -  Txt File with switch IP addresses
  Destination           (MANDATORY)         -  Folder for Cisco Backup 
  Credential            (MANDATORY)         -  Credentials for Cisco Switch account (Plink.exe doesn't support $Cred sadly)
  Commands              (OPTIONAL)          -  Commands to run against Cisco Switch (If not specified, "show running-config")

.EXAMPLE
  Get-CiscoConfig -List "C:\Backups\Cisco\switches.txt" -Destination "C:\Backups\Cisco" -Credential $Cred -Commands "C:\Backups\Cisco\commands.txt" 
  [SUCCESS]     10.9.16.1
  [SUCCESS]     10.9.17.1
  [SUCCESS]     10.9.18.1

.AUTHOR
  Miles Gratz (serveradventures.com)     

.DATE
  10/23/2015
#>

Param (
  [Parameter(Mandatory=$True)][string] $List,
  [Parameter(Mandatory=$True)][string] $Destination,
  [Parameter(Mandatory=$True)][System.Management.Automation.PSCredential] $Credential,
  [Parameter(Mandatory=$False)][string] $Commands
  )

  # VERIFY SWITCH LIST PARAMETER AND CONVERT TO OBJECT
  Try {$ListObj = Get-Item $List -ErrorAction Stop}
  Catch {Write-Host "[ERROR] Switch List Path is inaccessible. Function aborting..." -ForegroundColor Red; Exit }

  # VERIFY DESTINATION PARAMETER AND CONVERT TO OBJECT
  Try {$DestinationObj = Get-Item $Destination  -ErrorAction Stop}
  Catch {Write-Host "[ERROR] Destination Path is inaccessible. Function aborting..." -ForegroundColor Red; Exit }

  # VERIFY COMMANDS PARAMETER AND CONVERT TO OBJECT
  If ($Commands.Length -gt 1)
  {
    Try {$CommandsObj = Get-Item $Commands -ErrorAction Stop}
    Catch {Write-Host "[ERROR] Command Path is inaccessible. Function aborting..." -ForegroundColor Red; Exit }
  }
  
  # OTHERWISE, CREATE COMMANDS.TXT WITH "SHOW RUNNING-CONFIG"
  Else 
  {
    $Commands = $DestinationObj.FullName + "\Commands.txt"
    Try { "show running-config" | Out-File $Commands -Encoding Ascii -Force  -ErrorAction Stop | Out-Null }
    Catch { Write-Host "[ERROR] Unable to create Commands.txt file in Destination folder. Function aborting..." -ForegroundColor Red; Exit }
  }

  # VERIFY PLINK.EXE EXISTENCE
  If (Test-Path ($env:ProgramFiles + "\PuTTY\plink.exe"))
    {$Plink = (${env:ProgramFiles} + "\PuTTy\plink.exe")}
  If (Test-Path (${env:ProgramFiles(x86)} + "\PuTTy\plink.exe"))
    {$Plink = (${env:ProgramFiles(x86)} + "\PuTTy\plink.exe")}
  If (Test-Path ($DestinationObj.FullName + "\plink.exe"))
    {$Plink = $DestinationObj.FullName + "\plink.exe"}

  # DEFINE PATH FOR SSH KEYS USING NEW DESTINATION OBJECT
  $KeyPath = $DestinationObj.FullName + "\Keys"

  # CREATE FOLDER FOR STORING SSH KEYS IF NOT EXIST
   If (!(Test-Path $KeyPath))
    {
      Try {New-Item -ItemType Directory -Path $KeyPath  -ErrorAction Stop | Out-Null}
      Catch {Write-Host "[ERROR] Unable to create subfolder in Destination folder. Function aborting..." -ForegroundColor Red; Exit }
    }

  # DEFINE DATE VARIABLE
  $Date = Get-Date -Format M-d-yyyy

  # DEFINE BACKUP PATH WITH DATED FOLDER
  $BackupPath = $DestinationObj.FullName + "\" + $Date

  # CREATE FOLDER WITH NAME OF DATE FOR STORING BACKUP IF NOT EXIST
  If (!(Test-Path $BackupPath))
  {
    Try {New-Item -ItemType Directory -Path $BackupPath  -ErrorAction Stop | Out-Null}
    Catch {Write-Host "[ERROR] Unable to create subfolder for storing backups. Function aborting..." -ForegroundColor Red; Exit }
  }

  # DEFINE LIST OF SWITCHES
  $remoteHosts = Get-Content $List

  # LOOP THROUGH LIST OF SWITCHES
  ForEach ($remoteHost in $remoteHosts)
  {
    # ACCEPT SSH KEY IF NOT EXIST
    If ((Test-Path "$KeyPath\$remoteHost-key.txt") -eq $False)
      { 
      # EMULATING TYPING "YES" WHEN SSH PRESENTS KEY
      echo y | & "$Plink" -ssh $remoteHost "exit" > "$KeyPath\$remoteHost-key.txt"
      
      # WAITING 5 SECONDS TO PREVENT SSH OVERLOAD
      Start-Sleep -Seconds 5
      }
      
    # USE PLINK TO RUN LIST OF CISCO COMMANDS (e.g. SHOW RUNNING-CONFIG)
    Try {New-Item -ItemType File -Path "$BackupPath\$remoteHost.txt" -ErrorAction Stop -Force | Out-Null}
    Catch {Write-Host "[ERROR] Unable to create backup file for $remoteHost. Function aborting..." -ForegroundColor Red; Exit }
    & $Plink -ssh $remoteHost -l ($Credential.GetNetworkCredential().Username) -pw ($Credential.GetNetworkCredential().Password) -batch -m $Commands >> "$BackupPath\$remoteHost.txt"
    
    # WAITING 5 SECONDS TO PREVENT SSH OVERLOAD
    Start-Sleep -Seconds 5
  
    # OUTPUT TO HOST IF COMMAND WAS SUCCESSFUL IF RUNNING-CONFIG IS GREATER THAN 10 LINES (MEDIOCRE ERROR HANDLING I WILL ADMIT)
    If ((Get-Content "$BackupPath\$remoteHost.txt").Length -gt 10)  
      {Write-Host "[SUCCESS]  $remoteHost" -ForegroundColor Green}
    Else {Write-Host "[ERROR] Plink.exe experienced an error on $remoteHost. Incorrect commands? Function aborting..." -ForegroundColor Red; Exit}
  }
}
