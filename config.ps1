param (
    [switch]$SQLStatement
)
cd $PsScriptRoot

$Configuration = @"
{
    "hostname":"$env:ENV_SQL_HOSTNAME",
    "username":"$env:ENV_SQL_USERNAME",
    "password":"$env:ENV_SQL_PASSWORD",
    "database":"$env:ENV_SQL_DATABASE",
    "table":"$env:ENV_SQL_TABLE",
    "pagerduty_endpoint":"$env:ENV_PAGERDUTY_ENDPOINT",
    "pagerduty_routing_key":"$env:ENV_PAGERDUTY_ROUTING_KEY"
}
"@

$Configuration | Out-File /powershell/.config

$Hostname = $env:ENV_SQL_HOSTNAME
$Username = $env:ENV_SQL_USERNAME
$Password = $env:ENV_SQL_PASSWORD
$Database = $env:ENV_SQL_DATABASE
$Table = $env:ENV_SQL_TABLE

$MySQLImport = @"
CREATE DATABASE $Database;
USE $Database;
SET NAMES utf8;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';
SET NAMES utf8mb4;
DROP TABLE IF EXISTS $Table;
CREATE TABLE $Table (
          id int NOT NULL AUTO_INCREMENT,
          url varchar(500) NOT NULL,
          daysuntilexpiration varchar(500) NOT NULL,
          status varchar(500) NOT NULL,
          alert varchar(500) NOT NULL,
          pagerduty_dedup varchar(500) NOT NULL,
          lastupdate_utc varchar(500) NOT NULL,
          PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
INSERT INTO $Table (id, url, daysuntilexpiration, status, alert, pagerduty_dedup, lastupdate_utc) VALUES
(1,     'news.google.com',     '',     '',     '',     '',     '');
"@
$MySQLImport | Out-File import.sql -force

if ($SQLStatement){
write-host $MySQLImport
}
