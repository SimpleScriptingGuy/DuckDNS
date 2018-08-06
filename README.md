## This is based on a Powershell Script no longer available by Bryan Childs.

# Powershell DuckDNS Update Script	-	Update-DuckDNS.ps1
Updates the IP address of your Duck DNS domain(s). Intended to be run as a scheduled task, but it can be run interactively for debug/viewing purposes.

## Requirements
I am using it with PowerShell 4, but It will work on PowerShell 3 and above.

## Before First Usage
You will need to edit the file Update-DuckDNS.ps1, changing the following variables to match Your Needs:
- $MyDomains
- $MyToken


## You'll need to create the Event Log on your system, execute the following command below on a Powershell with Admin rights.
- New-EventLog -LogName "DuckDNS" -Source "DuckDNS Update"

I've created this Independent EventLog called "DuckDNS", with source entries named "DuckDNS Update", to be able to track what's happening overtime without mixing with Windows Application and System Logs.

## After First Usage And Successful Modifications:
Create a Schedule Task to run this script, with the desired periodicity (every 10 min, every day, ...).

Since the script will only update your Valid IP Address if it's different than the IP resolved for your DuckDNS Domain, there's no unneded WebRequests to the DuckDNS Servers.

# Ongoing changes:
- Introducing Try {} Catch {} to handle error events.
