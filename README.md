# Dynamic DNS for Freenom.com

This repository contains script to update [Freenom](https://www.freenom.com) records.

Script is written in PowerShell 7 and can be run on any [OS supporting it](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7). For help, run:

```powershell
pwsh freenom.ps1 -Help
```

For use on machines that do not have PowerShell, the script is packaged in a [docker container 
`nbogojevic/freenom-dynamic`](https://hub.docker.com/repository/docker/nbogojevic/freenom-dynamic).

To use it from docker run following for more information:

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
    Specifies subdomain of the main domain to update. If not set the main domain is updated. Can be used in combination with -Update.
.PARAMETER Renew
    If this switch is provided, domains will be renewed if possible. Can be used in combination with -Update.
.PARAMETER Update
    If this switch is provided, the domain records will be updated. Can be used in combination with -Renew.
.PARAMETER Help
    Displays full help.
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
    ./freenom.ps1 nbogojevic/freenom-dynamic user@example.com p455w0rd all 192.0.2.1
    $ docker run -ti --rm nbogojevic/freenom-dynamic user@example.com p455w0rd all 192.0.2.1

    Updates A records of all registered domains records to point to 192.0.2.0.

.EXAMPLE
    ./freenom.ps1 nbogojevic/freenom-dynamic user@example.com p455w0rd my.example.com auto
    $ docker run -ti --rm nbogojevic/freenom-dynamic user@example.com p455w0rd my.example.com auto

    Updates A record of my.example.com domain to point to automatically detected address.

.EXAMPLE
    ./freenom.ps1 nbogojevic/freenom-dynamic user@example.com p455w0rd my.example.com auto -Renew -SkipIpUpdate
    $ docker run -ti --rm nbogojevic/freenom-dynamic user@example.com p455w0rd my.example.com auto -Renew -SkipIpUpdate

    Renews my.example.com domain and doesn't update DNS records

.EXAMPLE
    ./freenom.ps1 user@example.com p455w0rd all 198.51.100.2 -Renew
    $ docker run -ti --rm nbogojevic/freenom-dynamic user@example.com p455w0rd all 198.51.100.2 -Renew

    Renews all registered domains that are about to expire and updates their DNS record to 198.51.100.2.

.NOTES
    Author: Nenad Bogojevic
    Year:   2020

    Not affiliated with Freenom.
    Freenom and all other trademarks, logos and copyrights are the property of their respective owners. 

.LINK
    https://github.com/nbogojevic/freenom-dynamic
#>
```

## Copyright and Trademark Notice

This software is licensed under MIT License.

Freenom and all other trademarks, logos and copyrights are the property of their respective owners. 


