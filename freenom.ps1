#! /usr/bin/env pwsh
#
param(
  [Parameter(Mandatory = $true, Position = 0, ParameterSetName="Update")]
  [Parameter(Mandatory = $true, Position = 0, ParameterSetName="Renew")]
  [ValidateNotNullOrEmpty()]
  [string] $Email,
  [Parameter(Mandatory = $true, Position = 1, ParameterSetName="Update")]
  [Parameter(Mandatory = $true, Position = 0, ParameterSetName="Renew")]
  [ValidateNotNullOrEmpty()]
  [string] $Passwd,
  [Parameter(Mandatory = $true, Position = 2, ParameterSetName="Update")]
  [Parameter(Mandatory = $true, Position = 0, ParameterSetName="Renew")]
  [ValidateNotNullOrEmpty()]
  [string] $Domain,
  [Parameter(Mandatory = $true, Position = 3, ParameterSetName="Update")]
  [ValidateNotNullOrEmpty()]
  [string] $Ip,
  [Parameter(ParameterSetName="Update")]
  [string] $Subdomain = '',
  [Parameter(ParameterSetName="Update")]
  [switch] $Update,
  [Parameter(ParameterSetName="Update")]
  [Parameter(ParameterSetName="Renew")]
  [switch] $Renew,
  [Parameter(ParameterSetName="Help")]
  [switch] $Help
)

if ($Help) {
  Get-Help $($MYINVOCATION.InvocationName) -Full
  Exit 0
}

$userAgents = @(
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.108 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:69.0) Gecko/20100101 Firefox/69.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:66.0) Gecko/20100101 Firefox/66.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2486.0 Safari/537.36 Edge/13.10586',
  'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36',
  'Mozilla/5.0 (IE 11.0; Windows NT 6.3; Trident/7.0; .NET4.0E; .NET4.0C; rv:11.0) like Gecko',
  'Mozilla/5.0 (X11; Linux x86_64; rv:55.0) Gecko/20100101 Firefox/55.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Android 9.0; Mobile; rv:61.0) Gecko/61.0 Firefox/61.0'
)

$UserAgent = $userAgents[(Get-Random -Maximum $userAgents.Count)]
$progressPreference = 'silentlyContinue'
$script:status = 'good'

try {
  Write-Verbose "UserAgent: $UserAgent"
  Write-Verbose 'Connecting...'
  $connect = Invoke-WebRequest -Uri 'https://my.freenom.com/clientarea.php' -SessionVariable websession -UserAgent $UserAgent
  $token = ($connect.InputFields | Where-Object name -eq 'token' | Select-Object -First 1 Value).Value
  Write-Verbose "token=$token"
  
  $webArgs = @{
    Headers           = @{ Referer = 'https://my.freenom.com/clientarea.php' }
    WebSession        = $websession
    UserAgent         = $UserAgent
    MaximumRetryCount = 5
    RetryIntervalSec  = 2
  }
  try {
    $form = @{
      username = $Email
      password = $Passwd
      token    = $token
    }
    Write-Verbose 'Authenticating...'
    $auth = Invoke-WebRequest -Uri 'https://my.freenom.com/dologin.php' -Method Post -Form $form @webArgs
    if ($auth.Content.Contains('Login Details Incorrect') -or
        ($auth.Headers['Location'] -and $auth.Headers['Location'].Contains('clientarea.php?incorrect=true'))) {
      throw 'noauth'
    }
    try {
      Write-Verbose 'Retrieving domains...'
      $script:foundDomain = $false
      $allDomains = Invoke-WebRequest -Uri "https://my.freenom.com/clientarea.php?action=domains&itemlimit=all" @webArgs
      $allDomains.Links | Where-Object href -match 'action=domaindetails' | ForEach-Object {
        Write-Verbose "Retrieving domain data $($_.href)..."
        $aDomain = Invoke-WebRequest -Uri "https://my.freenom.com/$($_.href)" @webArgs
        $aDomain.Links | Where-Object href -match '\/clientarea.php\?managedns=([a-z\-\.]+)\&domainid=([0-9]+)' | ForEach-Object {
          $currentDomain = $matches[1]
          $domainId = $matches[2]
          Write-Verbose "Domain: $currentDomain Id: $domainId"
          if (($Domain -eq 'all') -or ($Domain -eq $currentDomain)) {
            $script:foundDomain = $true
            Write-Verbose "Checking domain $currentDomain..."
            $managedns = Invoke-WebRequest -Uri "https://my.freenom.com$($_.href)" @webArgs
            $records = @{ }
            $lastRecord = -1
            $managedns.InputFields | Where-Object name -match 'records\[([0-9]+)\]' | ForEach-Object {
              $records[$_.name] = $_.value
              $idx = [int]$matches[1]
              if ($idx -gt $lastRecord) {
                $lastRecord = $idx
              }
            }
            if ($Update) {
              if ($Ip -eq 'auto') {
                # Retrieve IP from on of the services
                Write-Verbose "Retrieving my IP address from http://checkip.amazonaws.com"
                $myIp = Invoke-WebRequest -Uri 'http://checkip.amazonaws.com' -UserAgent $UserAgent
                $Ip = [System.Text.Encoding]::ASCII.GetString($myIp.Content).Trim()
                Write-Verbose "Retrieved address $Ip"
              }
              $foundRecord = $false
              $manageDnsUrl = "https://my.freenom.com/clientarea.php?managedns=$currentDomain&domainid=$domainId"
              for ($i = 0; $i -lt $lastRecord; $i++) {
                # If record is A record for selected subdomain, update it
                if (($records["records[$i][name]"] -eq $Subdomain) -and
                    ($records["records[$i][type]"] -eq 'A')) {
                  $foundRecord = $true
                  if ($records["records[$i][value]"] -ne $Ip) {
                    Write-Verbose "Updating record for $currentDomain $($Subdomain ? "subdoman $Subdomain" : ''))"
                    $form = @{
                      dnsaction            = 'modify'
                      "records[$i][name]"  = $Subdomain
                      "records[$i][type]"  = 'A'
                      "records[$i][ttl]"   = '600'
                      "records[$i][value]" = $Ip
                    }
                    $_ = Invoke-WebRequest -Uri $manageDnsUrl -Method Post -Form $form @webArgs
                    Write-Verbose "Updated record for $currentDomain $($Subdomain ? "subdoman $Subdomain" : '')"
                  }
                  else {
                    Write-Verbose "IP address not changed for $currentDomain $($Subdomain ? "subdoman $Subdomain" : '')"
                  }
                  break;
                }
              }
              # If record was not found, adding new one
              if (!$foundRecord) {
                Write-Verbose "Adding new record for $currentDomain $($Subdomain ? "subdoman $Subdomain" : '')"
                $form = @{
                  dnsaction             = 'add'
                  "addrecord[0][name]"  = $Subdomain
                  "addrecord[0][type]"  = 'A'
                  "addrecord[0][ttl]"   = '600'
                  "addrecord[0][value]" = $Ip
                }
                $_ = Invoke-WebRequest -Uri $manageDnsUrl -Method Post -Form $form @webArgs
                Write-Verbose "Added new record for $currentDomain $($Subdomain ? "subdoman $Subdomain" : '')"
              }
            }
          }
        }
      }
      if (!$script:foundDomain) {
        throw 'nohost'
      }
      if ($Renew) {
        # Renewing freenom domains
        Write-Verbose "Renewing domains..."
        $allRenewals = Invoke-WebRequest -Uri 'https://my.freenom.com/domains.php?a=renewals&itemlimit=all' @webArgs
        $allRenewals.Links | Where-Object href -match 'a=renewdomain' | ForEach-Object {
          try {
            Write-Verbose "Check domain renewal at $($_.href)..."
            $renewDomain = Invoke-WebRequest -Uri "https://my.freenom.com/$($_.href)" @webArgs
            if ($renewDomain.Content -notmatch 'Minimum Advance Renewal is 14 Days for Free Domains') {
              if (($Domain -eq 'all') -or $renewDomain.Content.Contains("<td>$Domain</td>")) {
                $form = @{}

                $renewDomain.InputFields | ForEach-Object {
                  $form[$_.name] = $_.value
                }
                $renewalPeriod = 12
                # $renewalPeriod = .*option value="\(.*\)\".*FREE.*
                $form["renewalperiod[$($form['renewalid'])]"] = $renewalPeriod
                Write-Verbose "Renewing domain at $($_.href)..."
                $_ = Invoke-WebRequest -Uri "https://my.freenom.com/domains.php?submitrenewals=true" -Method Post -Form $form @webArgs
                Write-Verbose "Renewed domain at $($_.href)"
              }
              else {
                Write-Verbose "Domain at $($_.href) is ignored."
              }
            }
            else {
              Write-Verbose "Domain at $($_.href) not open for renewal."        
            }
          }
          catch {
            Write-Verbose $_.Exception
            throw 'notrenewed'
          }
        }
      }
      $script:status
    }
    catch {
      Write-Verbose $_.Exception
      throw $_.Exception.WasThrownFromThrowStatement ? $_.Exception.Message : 'badagent'
    }
  }
  catch {
    Write-Verbose $_.Exception
    throw $_.Exception.WasThrownFromThrowStatement ? $_.Exception.Message : 'noauth'
  }
  finally {
    Write-Verbose "Logout"
    $_ = Invoke-WebRequest -Uri 'https://my.freenom.com/logout.php' @webArgs
  }
}
catch {
  $_.Exception.WasThrownFromThrowStatement ? $_.Exception.Message : '911'
}
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
