while ($true) {
    
cd $PSScriptRoot

Function Invoke-SQLQuery {
    param (
    $Config,
    $Query
    )

    $Config = Get-Content $Config | ConvertFrom-Json

    $Hostname = $Config.hostname
    $Username = $Config.username
    $Password = $Config.password
    $Database = $Config.database

    mysql --host=$Hostname --user=$Username --password=$Password --database=$Database --execute=$Query  2>/dev/null | ConvertFrom-csv -delimiter `t
}

function Invoke-PagerDutyAlert {

    param (
        $Config,
        $Event_Action = "trigger",
        $Payload_Summary = "message",
        $Payload_Source = "hostname",
        $Dedup,
        $Payload_Severity = "critical"

    )

    $Config = Get-Content $Config | ConvertFrom-Json
    $PagerDutyEndpoint = $Config.pagerduty_endpoint
    $Routing_Key = $Config.pagerduty_routing_key

$Payload = @"
{
    "payload": {
        "summary":"$Payload_Summary",
        "source":"$Payload_Source",
        "severity":"$Payload_Severity"
    },
        "routing_key" : "$Routing_Key",
        "dedup_key":"$Dedup",
        "event_action" : "$Event_Action"
}
"@

Invoke-WebRequest -Method 'Post' -Uri $PagerDutyEndpoint -Body $Payload -ContentType "application/json"
}

function Start-CertMon {
param (
        [parameter(mandatory=$true,position=1)]
        $URL
)

$FQDN = "$URL"
$URL = "$URL" + ":"  + "443"
$CertCheck = echo "Q" | openssl s_client -connect $URL 2>/dev/null | openssl x509 -noout -dates
$CertCheck = ($CertCheck | Select-String -Pattern notAfter)
$CertCheck = $CertCheck -replace "notAfter=",""
$CertCheck = $CertCheck.split() | Where {$_}

$Month = $CertCheck[0]
$Day = $CertCheck[1]
$Year = $CertCheck[3]

$DaysUntilExpiration = "$Year" + "-" +  "$Day" + "-" + "$Month"
$DaysUntilExpiration = [DateTime]$DaysUntilExpiration
$DaysUntilExpiration = (($DaysUntilExpiration) - (Get-Date)).Days

if ($Month -eq "Jan"){
$Month = "1"
}

if ($Month -eq "Feb"){
$Month = "2"
}

if ($Month -eq "Mar"){
$Month = "3"
}

if ($Month -eq "Apr"){
$Month = "4"
}

if ($Month -eq "May"){
$Month = "5"
}

if ($Month -eq "Jun"){
$Month = "6"
}

if ($Month -eq "Jul"){
$Month = "7"
}

if ($Month -eq "Aug"){
$Month = "8"
}

if ($Month -eq "Sep"){
$Month = "9"
}

if ($Month -eq "Oct"){
$Month = "10"
}

if ($Month -eq "Nov"){
$Month = "11"
}

if ($Month -eq "Dec"){
$Month = "12"
}

$Expiration = [PSCustomObject] @{
        URL = "$FQDN"
        Month = "$Month"
        Day = "$Day"
        Year = "$Year"
        daysuntilexpiration = "$DaysUntilExpiration"
}
$Expiration
}


$Config = ".config"
$Table = (Get-Content $Config | ConvertFrom-Json).table

$NotificationEndpoint = (Get-Content $Config | ConvertFrom-Json).notification_endpoint

$Query = @"
SELECT * FROM [TABLE]
"@
$Query = $Query.Replace("[TABLE]","$Table")

# Test-Connections
$Hosts = Invoke-SQLQuery -Config $Config -Query $Query
$Hosts | foreach {
    $ID = $_.id
    $Url = $_.url
    $DaysUntilExpiration = (Start-CertMon -Url $URL).daysuntilexpiration
    $DaysUntilExpiration = $DaysUntilExpiration -as [int]
    $Status = $_.status
    $Date = ((Get-Date).ToUniversalTime()).ToString("yyyy-MMdd-HHmm")

$StatusUpdate = @"
UPDATE [TABLE]
SET daysuntilexpiration='[DAYSUNTILEXPIRATION]', status='[STATUS]', lastupdate_utc='[LASTUPDATE]'
WHERE id='[ID]'
"@

	if ($DaysUntilExpiration -gt "30"){
            $StatusUpdate = $StatusUpdate.Replace("[TABLE]","$Table")
            $StatusUpdate = $StatusUpdate.Replace("[STATUS]","OK")
            $StatusUpdate = $StatusUpdate.Replace("[DAYSUNTILEXPIRATION]","$DaysUntilExpiration")
            $StatusUpdate = $StatusUpdate.Replace("[ID]","$Id")
            $StatusUpdate = $StatusUpdate.Replace("[LASTUPDATE]","$Date")
            Invoke-SQLQuery -Config $Config -Query $StatusUpdate
        }
        else {
            $StatusUpdate = $StatusUpdate.Replace("[TABLE]","$Table")
            $StatusUpdate = $StatusUpdate.Replace("[STATUS]","Replace")
            $StatusUpdate = $StatusUpdate.Replace("[DAYSUNTILEXPIRATION]","$DaysUntilExpiration")
            $StatusUpdate = $StatusUpdate.Replace("[ID]","$Id")
            $StatusUpdate = $StatusUpdate.Replace("[LASTUPDATE]","$Date")
            Invoke-SQLQuery -Config $Config -Query $StatusUpdate
        }
}


### Alert Notification
$Hosts = Invoke-SQLQuery -Config $Config -Query $Query | where {$_.status -ne "OK" -and $_.alert -ne "Alerted"}
$Hosts | Foreach {

    $ID = $_.id
    $URL = $_.url
    $DaysUntilExpiration = $_.daysuntilexpiration
    $Status = $_.status
    $Date = ((Get-Date).ToUniversalTime()).ToString("yyyy-MMdd-HHmm")

$AlertUpdate = @"
UPDATE [TABLE]
SET alert ='[ALERT]', lastupdate_utc='[LASTUPDATE]', pagerduty_dedup='[DEDUPKEY]'
WHERE id='[ID]'
"@
    $Seperator = "::"
    $Alert_message = "$Url $DaysUntilExpiration Days Until Certificate Expires [$Date UTC]"
    Write-Host $Alert_message
    $PagerDutyAlert = ((Invoke-PagerDutyAlert -Config $Config -Payload_Summary $Alert_message).content  | ConvertFrom-Json).dedup_key

    $AlertUpdate = $AlertUpdate.Replace("[TABLE]","$Table")
    $AlertUpdate = $AlertUpdate.Replace("[ALERT]","Alerted")
    $AlertUpdate = $AlertUpdate.Replace("[ID]","$Id")
    $AlertUpdate = $AlertUpdate.Replace("[LASTUPDATE]","$Date")
    $AlertUpdate = $AlertUpdate.Replace("[DEDUPKEY]","$PagerDutyAlert")
    Invoke-SQLQuery -Config $Config -Query $AlertUpdate
}


### Resolved Alert Notification
$Hosts = Invoke-SQLQuery -Config $Config -Query $Query | where {$_.status -eq "OK" -and $_.alert -eq "Alerted"}
$Hosts | Foreach {
#Send Resolved Message
    $ID = $_.id
    $Url = $_.url
    $DaysUntilExpiration = $_.daysuntilexpiration
    $Status = $_.status
    $Dedup = $_.pagerduty_dedup
    $Date = ((Get-Date).ToUniversalTime()).ToString("yyyy-MMdd-HHmm")

$AlertUpdate = @"
UPDATE [TABLE]
SET alert ='[ALERT]', lastupdate_utc='[LASTUPDATE]', pagerduty_dedup='[DEDUPKEY]'
WHERE id='[ID]'
"@
    $Seperator = "::"
    $Resolve_message = "Resolved: $Url $DaysUntilExpiration Days Until Certificate Expires [$Date UTC]"
    Write-Host $Resolve_message
    Invoke-PagerDutyAlert -Config $Config -Payload_Summary $Resolve_message -Dedup $Dedup -Event_Action "resolve"
    $AlertUpdate = $AlertUpdate.Replace("[TABLE]","$Table")
    $AlertUpdate = $AlertUpdate.Replace("[ALERT]","")
    $AlertUpdate = $AlertUpdate.Replace("[ID]","$Id")
    $AlertUpdate = $AlertUpdate.Replace("[LASTUPDATE]","$Date")
    $AlertUpdate = $AlertUpdate.Replace("[DEDUPKEY]","")
    Invoke-SQLQuery -Config $Config -Query $AlertUpdate
}
Start-Sleep -S $env:ENV_POLL_FREQUENCY_SECONDS
}
