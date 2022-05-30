param (
    [parameter(mandatory=$false)]
    $Id
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

    mysql --host=$Hostname --user=$Username --password=$Password --database=$Database --execute=$Query  2>/dev/null | ConvertFrom-csv -delimiter `t
}

$Config = ".config"
$Table = (Get-Content $Config | ConvertFrom-Json).table
$Query = "SELECT * FROM [TABLE]"
$Query = $Query.Replace("[TABLE]","$Table")

Write-Host " "
Invoke-SQLQuery -Config $Config -Query $Query | Select id,url | out-file tempquery.csv -Force
(Import-csv tempquery.csv -WarningAction SilentlyContinue).H1
rm tempquery.csv
Write-Host " "

if ($Id){}
else {
$ID = Read-Host "Select the service 'id' you would like to delete"
}

if ($ID) {
$Query = "Delete FROM [TABLE] WHERE id=$ID;"
$Query = $Query.Replace("[TABLE]","$Table")

Invoke-SQLQuery -Config $Config -Query $Query
}
