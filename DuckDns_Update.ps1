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
# Making sure these enviroment variables are sterile before assigning values.
$MyWAN_IP = $null	; 	$Text_Response = $null	;	$webrequest = $null ; $Dig_IP = $null

	# Since in a single or multi domain registration they resolve to the same IP address, cheking only the first one.
	$DuckDomainDNS_Check = $($MyDomains).Split(",")[0] + ".duckdns.org"

	# If the domain does not exist, the script will stop and Log and error!
	try {
		$Dig_IP = $(Resolve-DnsName $DuckDomainDNS_Check -TcpOnly -ErrorAction SilentlyContinue -ErrorVariable ProcessError).IPAddress
		If ($ProcessError) { Write-Host "`n`tError in DNS Request: $ErrorMessage`n`tProcessError = $ProcessError`n`n`t Retries = $retries`n`n`t DuckDNS_IP = $Dig_IP`n" 
							 Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Error -EventID 911 -Message "`n`tError in DNS Request: $ErrorMessage`n`n`t ProcessError = $ProcessError`n`n`t ErrorMessage = $ErrorMessage`n`n`t Retries = $retries`n`n`t DuckDNS_IP = $Dig_IP`n"
							 }
	} catch {	$ErrorMessage = $_.Exception.Message
				# Write-Host "Error in DNS Request: $ErrorMessage`n"
				Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Error -EventID 911 -Message "Error in DNS Request: $ErrorMessage`n`n`t DuckDNS_IP = $Dig_IP`n"
				# break
			}
		
	Sleep 5		# Giving some time for the DNS resolution to take place (5s).

	# Getting and parsing your current IP address visible from the Internet using checkip.dyndns.com website.
	$ChkIpUrl = "http://checkip.dyndns.com"
	$webrequest = Invoke-WebRequest $ChkIpUrl
	$MyWAN_IP = $($webrequest.ParsedHtml.body.innerHtml).Split(":")[1].Trim()
	$retries = $retries + 1
	Write-Host "`n WebRequest: `n $webrequest`n `n`t Debugging: MyWAN_IP = $MyWAN_IP`n`t DuckDNS_IP = $Dig_IP `n`n`t Retries = $retries`n"
	# Looping while I have empty/null variables.
} While ((! $MyWAN_IP) -or (! $Dig_IP))

if("$MyWAN_IP" -eq "$Dig_IP") {
	Write-Host "IP's are equal, DOING NOTHING`n"
	Write-Host "Current`t NET MyWAN_IP: $MyWAN_IP `n`t DuckDNS's IP: $Dig_IP`n`t Retries = $retries`n"
	Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Information -EventID 13 -Message "DuckDNS IP Update SKIPPED, nothing to do `n`n`t DuckDNS_IP = $Dig_IP `n`t MyWAN_IP = $MyWAN_IP `n`t Retries = $retries`n"
	Write-Host "Exit code: "
	return 13
} else {

	Write-Host "IP's are DIFFERENT, Updating`n"
	Write-Host "Current WAN IP: $MyWAN_IP `t DuckDNS's IP: $Dig_IP `n`t retries = $retries`n"
	$DNS_url_Update = "https://www.duckdns.org/update?domains=" + $MyDomains + "&token=" + $MyToken + "&ip=" + $MyWAN_IP
		
	# Running a WebRequest to update the new values at DuckDNS's website.
    $HTTP_Response = Invoke-WebRequest -Uri $DNS_url_Update
    # Selecting the response value on the HTTP_Response.
	$Text_Response = $($HTTP_Response.StatusDescription)

		# Write an EventLog entry according to the response received.
		if($Text_Response -ne "OK"){
			# Bad Response Event
			Write-Host "DuckDNS Update FAILED for some reason. Check your Domain or Token.`n`t Text_Response = $Text_Response`n`n`t DNS_url_Update $DNS_url_Update`n`nDebugging: MyWAN_IP = $MyWAN_IP`n`nWebRequest: `n$webrequest`n `nText_Response $Text_Response`n`t retries = $retries`n"
			Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Error -EventID 911 -Message "DuckDNS Update FAILED for some reason. Check your Domain or Token.`n`t Text_Response = $Text_Response`n`n`t DNS_url_Update $DNS_url_Update`n`nDebugging: MyWAN_IP = $MyWAN_IP`n`nWebRequest: `n$webrequest`n `nText_Response $Text_Response`n`t retries = $retries`n";
			Write-Host "Exit code: "
			return 911
		} else {
			# OK Event
			Write-Host "DuckDNS Updated SUCCESSFULY `n`t DuckDNS_IP = $Dig_IP `n`t MyWAN_IP = $MyWAN_IP `n`t retries = $retries`n"
			Write-EventLog -LogName "DuckDNS" -Source "DuckDNS Update" -EntryType Warning -EventID 1 -Message "DuckDNS Updated SUCCESSFULY `n`t DuckDNS_IP = $Dig_IP `n`t MyWAN_IP = $MyWAN_IP `n`t retries = $retries`n"
			return 1
		}

	} # end else

