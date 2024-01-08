<#
To get the libraries needed for this example, run the following commands:
    dotnet new console
    dotnet add package Microsoft.Extensions.Logging.Abstractions
    dotnet add package Novell.Directory.Ldap.NETStandard
#>
Add-Type -Path "~/.nuget/packages/novell.directory.ldap.netstandard/3.6.0/lib/net5.0/Novell.Directory.Ldap.NETStandard.dll"
Add-Type -Path "~/.nuget/packages/microsoft.extensions.logging.abstractions/5.0.0/lib/net461/Microsoft.Extensions.Logging.Abstractions.dll"

$filter="(uid=testuser)"
$baseDN="o=domain.local"
$scope=[Novell.Directory.Ldap.LdapConnection]::ScopeSub

#Connects to LDAP
$LDAPConn = New-Object Novell.Directory.Ldap.LdapConnection
$LDAPConn.SecureSocketLayer=$true
$LDAPConn.Connect("lsapserver.domain.local", 636)
$LDAPConn.Bind($null, $null)
$Results=$LDAPConn.Search($baseDN,$scope,$filter,$Null,$false)
$LDAPEntries = @()
do {
    [Novell.Directory.Ldap.LdapEntry] $Entry = $Results.next()
    $ldapEntries += $Entry
} while (
    $Results.hasMore()
)
foreach ($ldapEntry in $ldapEntries) {
    # Access the properties of each search result
    $dn = $ldapEntry.DN
    $cn = $ldapEntry.getAttribute("cn")
    Write-Output "DN: $dn"
    Write-Output "CN: $cn"
    # Process other properties as needed
}
$LDAPConn.Disconnect()