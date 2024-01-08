Function ConvertTo-OpenSSHKey {
<#
.SYNOPSIS
Converts an RSA SSH Public key from PuTTY format to OpenSSH format.

.DESCRIPTION
Converts an RSA SSH Public key from PuTTY format to OpenSSH format.

.PARAMETER path
The path to a PuTTY SSH Public key.

.PARAMETER backupPath
The path to a save a backup of the original PuTTY SSH Public key.

.EXAMPLE
ConvertTo-OpenSSHKey -path $env:USERPROFILE\.ssh\id_rsa.pub

Backs up original PuTTY SSH Public key file to the original location with a .bak extension and changes the original file content to match OpenSSH requirements.

.INPUTS
All parameters can be piped by property name.

.OUTPUTS
Original file is overwritten with new data.
New backup file created.
#>
	[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-Path -Path $($_).trim('"') -PathType Leaf})]
        [string] $path = "$HOME/.ssh/id_rsa.pub",
        [Parameter(Mandatory=$false)]
        [string] $backupPath = "$HOME/.ssh/id_rsa.pub.bak"
    )

    Begin {}

    Process {
        $regex = "(---- (BEGIN|END) SSH2 PUBLIC KEY ---|Comment: *.)"
        $keyContent = Get-Content $path

        If ($keyContent -match $regex) {
            Write-Debug "Creating backup of $path"
            Try {
                Copy-Item -Path $path -Destination "$backupPath"
                Write-Debug "Backed up public key file to $backupPath"
            }
            Catch {
                Write-Error "Failed to backup public key file. Cannot continue."
                break
            }

            $key = ""
            $keyContent -notmatch $regex | ForEach-Object {
                $key += "$_"
            }

            Write-Output "Writing new file to $path"
            Try {
                "ssh-rsa $key" | Out-File -FilePath $path -Encoding utf8 -Force
                Write-Debug "Successfully wrote new file."
            }
            Catch {
                Write-Error "Failed to write new file.  Attempting rollback."
                Try {
                    Move-Item -Path "$backupPath" -Destination $path
                    Write-Debug "Successfully reverted original file."
                }

                Catch
                {
                    Write-Error "Failed to rollback! Original file is still available at $backupPath"
                    break
                }
                break
            }
        } Else {
            Write-Error "Incorrect public key format - cannot continue"
        }
    }

    End {}
}