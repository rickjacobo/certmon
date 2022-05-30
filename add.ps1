param (
[Parameter(Mandatory=$true)]$Url
)

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
    $Table = $Config.table

    mysql --host=$Hostname --user=$Username --password=$Password --database=$Database --execute=$Query 2>/dev/null | ConvertFrom-csv -delimiter `t
}

$Config = ".config"
$Table = (Get-Content $Config | ConvertFrom-Json).table
$Query = "INSERT INTO [TABLE](url,daysuntilexpiration,status,alert,pagerduty_dedup,lastupdate_utc) VALUES ('$Url','','','','','');"
$Query = $Query.Replace("[TABLE]","$Table")

Invoke-SQLQuery -Config $Config -Query $Query
