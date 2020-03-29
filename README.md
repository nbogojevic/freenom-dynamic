# Dynamic DNS for Freenom.com

This repository contains script to update Freenom.com records.

Script is written in PowerShell 7 and can be run on any OS supporting it.

For use on machines that do not have PowerShell, the script is packaged in a docker container 
`nbogojevic/freenom`

To use it on such machines:

```sh
docker run -ti --rm nbogojevic/freenom-dynamic
```

## Docker Container Building

```sh
docker build . --tag nbogojevic/freenom-dynamic
```

## Script Usage

```powershell
<#
.SYNOPSIS
    This script provides Dynamic DNS on Freenom.com
.DESCRIPTION
    This script allows updating Freenom.com hosted domains with IP address. If 'A' record for domain and
    optional subdomain doesn't exist an 'A' record will be created. TTL for records is set to 600 seconds.
    The script also allows renewing domains that are about to expire.
.PARAMETER Email
    Specifies email used to log in to Freenom.com
.PARAMETER Passwd
    Specifies password used to log in to Freenom.com
.PARAMETER Domain
    Specifies the domain to update. If set to 'all', all domains will be updated.
.PARAMETER Ip
    Specifies IP address to use. If set to 'auto', IP address will be retrieved from one of the web IP retrieval services.
.PARAMETER Subdomain
    Specifies subdomain of the main domain to update. If not set the main domain is updated.
.PARAMETER Renew
    If this switch is provided, domains will be renewed if possible.
.PARAMETER SkipIpUpdate
    If this switch is provided, the domain records will not be updated. Can be used in combination with -Renew.
.INPUTS
    none
.OUTPUTS
    System.String that describes state:
      good -  Update successfully.
      nochg - Update successfully but the IP address have not changed.
      nohost - The hostname specified does not exist in this user account.
      abuse - The hostname specified is blocked for update abuse.
      notfqdn - The hostname specified is not a fully-qualified domain name.
      badauth - Authenticate failed.
      911 - There is a problem or scheduled maintenance on provider side
      badagent - The user agent sent bad request(like HTTP method/parameters is not permitted)
      badresolv - Failed to connect to  because failed to resolve provider address.
      badconn - Failed to connect to provider because connection timeout.
.EXAMPLE
    freenom.ps1 user@example.com p455w0rd all 192.0.2.1

    Updates A records of all registered domains records to point to 192.0.2.0.

.EXAMPLE
    freenom.ps1 user@example.com p455w0rd my.example.com auto

    Updates A record of my.example.com domain to point to automatically detected address.

.EXAMPLE
    freenom.ps1 user@example.com p455w0rd my.example.com auto -Renew -SkipIpUpdate

    Renews my.example.com domain and doesn't update DNS records

.EXAMPLE
    freenom.ps1 user@example.com p455w0rd all 198.51.100.2 -Renew

    Renews all registered domains that are about to expire and updates their DNS record to 198.51.100.2.

.NOTES
    Author: Nenad Bogojevic
    Year:   2020
#>
```

