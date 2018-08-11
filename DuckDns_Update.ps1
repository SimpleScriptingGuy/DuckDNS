#Requires -Version 3.0
# All the Write-Host entries are only used if anyone wants to debug/visualize while running on a interactive poweshell command prompt
# Change anything according to your own standards an personal preferences


# To be able to track what's happening overtime, I've created an Independant EventLog called DuckDNS and write entries as "DuckDNS Update" on it.
# Before running the script, You need to create the Event Log on your system, to execute the following command below you'll need to run it on a Powershell with Administrative rights.
# PS C:\> New-EventLog -LogName "DuckDNS" -Source "DuckDNS Update"

# After that, you can create a Schedule Task to run this script every N times per day at your discretion.
# It will only update(s) your valid Internet IP address at the DuckDNS server, when you actual IP address is DIFFERENT than the IP address that was last set for your DuckDNS Domain.


# Change to Your domain(s) 
$MyDomains = "domain1,domain2,domain3"
# Change to Your token
$MyToken = "26f98765-abcd-4321-0027-5cb43ebfa400"
$retries = 0	# reseting the counter. For me, sometimes it runs 2 times before getting a valid non-empty response from Resolve-DnsName.

do {
# Added by Damiani		# New-EventLog -LogName DuckDNS -Source "DuckDNS Update"
# Cleaning variables
$MyWAN_IP = $null		;	$Dig_IP = $null		;	$DuckDomainDNS_Check = $null 
$Text_Response = $null	;	$WebRequest = $null ;	$ErrorMessage = $null	;	$ProcessError = $null
$EventLog_Info = $null	;	$Log_Head = $null	;	$Log_Try = $null		;	$Log_Catch = $null
$Log_Ident = $null		;	$Log_IPs = $null 	;	$HTTP_Response = $null	;	$DNS_URL_Update = $null
$LogRespKO = $null		;	$LogRespOK = $null	;	$LogTxtURL = $null		

	# Since in a single or multi domain registration they resolve to the same IP address, cheking only the first one.
	$DuckDomainDNS_Check = $($MyDomains).Split(",")[0] + ".duckdns.org"
	$Log_Head = "`t Checking this DuckDNS Domain Name: "
	Write-Host -NoNewline $Log_Head; Write-Host -ForegroundColor Yellow $DuckDomainDNS_Check "`n"
	# Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Information -EventID 12 -Message $($Log_Head + $DuckDomainDNS_Check)
		
	# If the domain does not exist, the script will stop and Log and error!
	try {
		$Dig_IP = $(Resolve-DnsName $DuckDomainDNS_Check -TcpOnly -ErrorAction SilentlyContinue -ErrorVariable ProcessError).IPAddress
			# Giving some time for the DNS resolution to take place (2s).
			# Sleep 1
		If ($ProcessError) { $Log_Try = "`n`n`t Error in DNS Request: $ErrorMessage `t ProcessError = $ProcessError`n`n`t Retrying...`n`n`t"
							 Write-Host $Log_Try
							 Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Error -EventID 919 -Message $($Log_Head + $DuckDomainDNS_Check + $Log_Try)
							 $retries = $retries + 1
							 }
	} catch {	$ErrorMessage = $_.Exception.Message
				$Log_Catch = "Error in DNS Request (Catch): ErrorMessage = $DuckDomainDNS_Check `n`t DuckDNS_IP = $Dig_IP`n`t Retries = $retries`n"
				Write-Host -BackgroundColor Black -ForegroundColor Red $Log_Catch
				Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Error -EventID 190 -Message $($Log_Head + $DuckDomainDNS_Check + $Log_Catch)
				$retries = $retries + 1
				break
			}
		
	$ChkIpUrl = "http://checkip.dyndns.com"
	$WebRequest = Invoke-WebRequest $ChkIpUrl
		# Giving some time for the DNS resolution to take place (2s).
		# Sleep 1
	$MyWAN_IP=$($WebRequest.ParsedHtml.body.innerHtml).Split(":")[1].Trim()

	# Debug info after 1 attempt
	if ($retries -gt 1) {
		Write-Host -BackgroundColor DarkRed -ForegroundColor Yellow "Debugging:" ; 	Write-Host -ForegroundColor White "`t MyWAN_IP = $MyWAN_IP`n`t DuckDNS_IP = $Dig_IP `n`n`t Retries = $retries`n" ; Write-Host -NoNewLine "`n WebRequest: `t $WebRequest`n`n`t"
		Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Information -EventID 21 -Message "`n`t Debug Info `>1:`n`t MyWAN_IP = $MyWAN_IP`n`t DuckDNS_IP = $Dig_IP `n`t WebRequest: `t $WebRequest`n`t Retries = $retries`n"
	}

	$retries = $retries + 1
} While ((! $MyWAN_IP) -or (! $Dig_IP))

if("$MyWAN_IP" -eq "$Dig_IP") {
	$Log_Ident = "IP's are Identical, NOTHING TO DO`!`n"
	$Log_IPs = "`n`t Actual`t NET MyWAN_IP:`t $MyWAN_IP `n`t`t DuckDNS's IP:`t $Dig_IP`n`t`t Retries = $retries`n"
	Write-Host -NoNewLine "`n`t " ; Write-Host -BackgroundColor Blue -ForegroundColor White $Log_Ident ; Write-Host $Log_IPs 
	Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Information -EventID 13 -Message $($Log_Head + $DuckDomainDNS_Check + "`n`n`t "  + $Log_Ident + $Log_IPs)
	Write-Host -NoNewLine -ForegroundColor Cyan "Exit code:" ; Write-Host -NoNewLine " "
	return 13
} else {
	$Log_IPs = "`n`t Actual`t NET MyWAN_IP: $MyWAN_IP `n`t`t DuckDNS's IP: $Dig_IP`n`t`t Retries = $retries`n"
	$Log_IPdiff = "IP's are DIFFERENT, Updating`!`n"
	Write-Host -NoNewLine "`n`t" ; Write-Host -BackgroundColor Green -ForegroundColor DarkGreen $Log_IPdiff	; Write-Host $Log_IPs
	$DNS_URL_Update = "https://www.duckdns.org/update?domains=" + $MyDomains + "&token=" + $MyToken + "&ip=" + $MyWAN_IP
		
	# Run the call to Update the Domain IP Address in DuckDNS's website
    $HTTP_Response = Invoke-WebRequest -Uri $DNS_URL_Update
	# Giving some time for the DNS resolution to take place (2s).
	Sleep 1
	$Text_Response = $($HTTP_Response.StatusDescription)

		# If the response is anything other than 'OK' then log an error in the windows event log
		if($Text_Response -ne "OK"){
			$LogRespKO = "DuckDNS Update FAILED for some reason. Check your Domain and`/or Token."
			$LogTxtURL = "`n`t Text_Response = $Text_Response`n`n`t DNS_URL_Update $DNS_URL_Update`n`n" + $Log_IPs
			Write-Host -BackgroundColor Red -ForegroundColor Yellow $LogRespKO
			Write-Host $LogTxtURL
			Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Error -EventID 911 -Message $($LogRespKO + $LogTxtURL)
			Write-Host -NoNewLine -ForegroundColor Cyan "Exit code:" ; Write-Host -NoNewLine " "
			return 911
		} else {
		
			$LogRespOK = "`n`t DuckDNS Updated SUCCESSFULY`!`n"
			Write-Host -BackgroundColor Black -ForegroundColor Yellow $Log_IPdiff
			Write-Host -BackgroundColor Red -ForegroundColor Yellow $LogRespOK ; Write-Host $Log_IPs
			Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Warning -EventID 1 -Message $($Log_IPdiff + $Log_IPs + $LogRespOK)
			Write-Host -NoNewLine -ForegroundColor Cyan "Exit code:" ; Write-Host -NoNewLine " "
			return 1
		}

	} # end else
