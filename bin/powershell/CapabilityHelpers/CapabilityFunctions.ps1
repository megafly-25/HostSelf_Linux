function Add-CapabilityFromApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName)

    Write-Host "Checking for application: '$ApplicationName'"
    $application =
        Get-Command -Name $ApplicationName -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1
    if (!$application) {
        Write-Host "Not found."
        return
    }

    Write-Capability -Name $Name -Value $application.Path
}

function Add-CapabilityFromEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$VariableName,

        [ref]$Value)

    $path = "env:$VariableName"
    Write-Host "Checking: '$path'"
    $val = (Get-Item -LiteralPath $path -ErrorAction Ignore).Value
    if (!$val) {
        Write-Host "Value not found or is empty."
        return
    }

    Write-Capability -Name $Name -Value $val
    if ($Value) {
        $Value.Value = $val
    }
}

function Add-CapabilityFromRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,

        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,

        [ref]$Value)

    $val = Get-RegistryValue -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName
    if ($val -eq $null) {
        return $false
    }

    if ($val -is [string] -and $val -eq '') {
        return $false
    }

    Write-Capability -Name $Name -Value $val
    if ($Value) {
        $Value.Value = $val
    }

    return $true
}


function Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey {
    <#
        .SYNOPSIS
            Retrieves capability from registry for specified key and subkey. Considers that subkey has semver format
    #>
    [CmdletBinding()]
    param(
        # Prefix name of capability
        [Parameter(Mandatory = $true)]
        [string]$PrefixName,
        # Postfix name of capability
        [Parameter(Mandatory = $false)]
        [string]$PostfixName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,
        # Registry key
        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,
        
        # Registry subkey
        [Parameter(Mandatory = $true)]
        [string]$Subkey,
        
        # Regkey subdirectory inside particular version
        [Parameter(Mandatory = $false)]
        [string]$VersionSubdirectory,

        # Major version of tool to be added as capability
        [Parameter(Mandatory = $true)]
        [int]$MajorVersion,
        
        # Minimum major version of tool to be added as capability. All versions detected less than this version - will be ignored. 
        # This is helpful for backward compatibility with already existing logic for previous versions
        [Parameter(Mandatory = $false)]
        [int]$MinimumMajorVersion,

        [ref]$Value)
    try {
        Write-Host $MajorVersion $MinimumMajorVersion
        if ($MajorVersion -lt $MinimumMajorVersion) {
            return $false
        }

        $wholeKey = ""
        if ( -not [string]::IsNullOrEmpty($VersionSubdirectory)) {
            $versionDir = Join-Path -Path $KeyName -ChildPath $Subkey
            $wholeKey = Join-Path -Path $versionDir -ChildPath $VersionSubdirectory
        } else {
            $wholeKey = Join-Path -Path $KeyName -ChildPath $Subkey
        }
 
        $capabilityValue = Get-RegistryValue -Hive $Hive -View $View -KeyName $wholeKey -ValueName $ValueName

        if ([string]::IsNullOrEmpty($capabilityValue)) {
            return $false
        }
   
        $capabilityName = $PrefixName + $MajorVersion + $PostfixName

        Write-Capability -Name $capabilityName -Value $capabilityValue
        if ($Value) {
            $Value.Value = $capabilityValue
        }

        return $true
    } catch {
        return $false
    }
}

function Add-CapabilityFromRegistryWithLastVersionAvailable {
    <#
        .SYNOPSIS
            Retrieves capability from registry with last version. Considers that subkeys for specified key name are versions (in semver format like 1.2.3)
            This is useful to detect last version of tools as agent capabilities

        .EXAMPLE
            If KeyName = 'SOFTWARE\JavaSoft\JDK', and this registry key contains subkeys: 14.0.1, 16.0 - it will write the last one as specified capability
    #>
    [CmdletBinding()]
    param(
        # Prefix name of capability
        [Parameter(Mandatory = $true)]
        [string]$PrefixName,
        # Postfix name of capability
        [Parameter(Mandatory = $false)]
        [string]$PostfixName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,
        # Registry key
        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        # Regkey subdirectory inside particular version
        [Parameter(Mandatory = $false)]
        [string]$VersionSubdirectory,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,
        # Minimum major version of tool to be added as capability. All versions detected less than this version - will be ignored. 
        # This is helpful for backward compatibility with already existing logic for previous versions
        [Parameter(Mandatory = $false)]
        [string]$MinimumMajorVersion,

        [ref]$Value)

    try {
        $subkeys = Get-RegistrySubKeyNames -Hive $Hive -View $View -KeyName $KeyName | Sort-Object

        $versionSubkeys = $subkeys | ForEach {[tuple]::Create((Parse-Version -Version $_), $_)} | Where { ![string]::IsNullOrEmpty($_.Item1)}

        $sortedVersionSubkeys = $versionSubkeys | Sort-Object -Property @{Expression = {$_.Item1}; Descending = $False}
        Write-Host $sortedVersionSubkeys[-1].Item1.Major
        $res = Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey -PrefixName $PrefixName -PostfixName $PostfixName -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName -Subkey $sortedVersionSubkeys[-1].Item2 -VersionSubdirectory $VersionSubdirectory -MajorVersion $sortedVersionSubkeys[-1].Item1.Major -Value $Value  -MinimumMajorVersion $MinimumMajorVersion

        if (!$res) {
            Write-Host "An error occured while trying to get last available version for capability: " $PrefixName + "<version>" + $PostfixName
            Write-Host $_ 

            $major = (Parse-Version -Version $subkeys[-1]).Major

            $res = Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey -PrefixName $PrefixName -PostfixName $PostfixName -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName -Subkey $subkeys[-1] -MajorVersion $major -Value $Value -MinimumMajorVersion $MinimumMajorVersion

            if(!$res) {
                Write-Host "An error occured while trying to set capability for first found subkey: " $subkeys[-1]
                Write-Host $_

                return $false
            }
        }

        return $true
    } catch {
        Write-Host "An error occured while trying to sort subkeys for capability as versions: " $PrefixName + "<version>" + $PostfixName
        Write-Host $_ 

        return $false
    }
}


function Write-Capability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Value)

    $escapeMappings = @( # TODO: WHAT ABOUT "="? WHAT ABOUT "%"?
        New-Object psobject -Property @{ Token = ';' ; Replacement = '%3B' }
        New-Object psobject -Property @{ Token = "`r" ; Replacement = '%0D' }
        New-Object psobject -Property @{ Token = "`n" ; Replacement = '%0A' }
    )
    $formattedName = "$Name"
    $formattedValue = "$Value"
    foreach ($mapping in $escapeMappings) {
        $formattedName = $formattedName.Replace($mapping.Token, $mapping.Replacement)
        $formattedValue = $formattedValue.Replace($mapping.Token, $mapping.Replacement)
    }

    Write-Host "##vso[agent.capability name=$formattedName]$formattedValue"
}

# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB8u+qHvsL0YWty
# yVMcOUz9odqvzdZISk5xplsK7P0ER6CCDXYwggX0MIID3KADAgECAhMzAAADrzBA
# DkyjTQVBAAAAAAOvMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwOTAwWhcNMjQxMTE0MTkwOTAwWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOS8s1ra6f0YGtg0OhEaQa/t3Q+q1MEHhWJhqQVuO5amYXQpy8MDPNoJYk+FWA
# hePP5LxwcSge5aen+f5Q6WNPd6EDxGzotvVpNi5ve0H97S3F7C/axDfKxyNh21MG
# 0W8Sb0vxi/vorcLHOL9i+t2D6yvvDzLlEefUCbQV/zGCBjXGlYJcUj6RAzXyeNAN
# xSpKXAGd7Fh+ocGHPPphcD9LQTOJgG7Y7aYztHqBLJiQQ4eAgZNU4ac6+8LnEGAL
# go1ydC5BJEuJQjYKbNTy959HrKSu7LO3Ws0w8jw6pYdC1IMpdTkk2puTgY2PDNzB
# tLM4evG7FYer3WX+8t1UMYNTAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQURxxxNPIEPGSO8kqz+bgCAQWGXsEw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMTgyNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAISxFt/zR2frTFPB45Yd
# mhZpB2nNJoOoi+qlgcTlnO4QwlYN1w/vYwbDy/oFJolD5r6FMJd0RGcgEM8q9TgQ
# 2OC7gQEmhweVJ7yuKJlQBH7P7Pg5RiqgV3cSonJ+OM4kFHbP3gPLiyzssSQdRuPY
# 1mIWoGg9i7Y4ZC8ST7WhpSyc0pns2XsUe1XsIjaUcGu7zd7gg97eCUiLRdVklPmp
# XobH9CEAWakRUGNICYN2AgjhRTC4j3KJfqMkU04R6Toyh4/Toswm1uoDcGr5laYn
# TfcX3u5WnJqJLhuPe8Uj9kGAOcyo0O1mNwDa+LhFEzB6CB32+wfJMumfr6degvLT
# e8x55urQLeTjimBQgS49BSUkhFN7ois3cZyNpnrMca5AZaC7pLI72vuqSsSlLalG
# OcZmPHZGYJqZ0BacN274OZ80Q8B11iNokns9Od348bMb5Z4fihxaBWebl8kWEi2O
# PvQImOAeq3nt7UWJBzJYLAGEpfasaA3ZQgIcEXdD+uwo6ymMzDY6UamFOfYqYWXk
# ntxDGu7ngD2ugKUuccYKJJRiiz+LAUcj90BVcSHRLQop9N8zoALr/1sJuwPrVAtx
# HNEgSW+AKBqIxYWM4Ev32l6agSUAezLMbq5f3d8x9qzT031jMDT+sUAoCw0M5wVt
# CUQcqINPuYjbS1WgJyZIiEkBMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGZ8wghmbAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKwGEk2KSyFauS+PvJDzbJt9
# PYsltgzO4ay2GTclUrzLMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAxIXbd4HO0uuOdgw69RJ77821fTPgH4xv7FWFG/ePtWh/2gH0I9dvvtWX
# ibcrFPU2tWtgnsH4hX6C2jJ4ylLzpmgbpkHN1IqxMINnvwpni5Xk2blLbjTiYKCE
# dcLcwFrQiY7Fm5tz0dhwu2d/jv+jI2CMhQvCyQTnTeG1y68ldLciXKBts/p6xIpL
# 1ToX4jX/hmuTsqQgi7bie8Zdc1AMxvfmw/QCj39oIebuhG+Jc82194o+prOwjMqu
# +YZBpeOCrGo1gOQG1Lo2GhH0pfueHG0NM4dcyM3c0uaXP3s2Mm2VpO9qVmFj7x3D
# 8NG7sqr+yBkhPdAPaGIlNCY8AXyf5qGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCB2zjgqPgPo42Ij3ce7E2G5m8vBH8x78rZf09wX2x0kgwIGZdYHaGHd
# GBMyMDI0MDIyODEzMjcwNS4wMTRaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# OjE3OUUtNEJCMC04MjQ2MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHg1PwfExUffl0AAQAAAeAwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjMx
# MDEyMTkwNzE5WhcNMjUwMTEwMTkwNzE5WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjoxNzlFLTRC
# QjAtODI0NjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKyHnPOhxbvRATnGjb/6fuBh
# h3ZLzotAxAgdLaZ/zkRFUdeSKzyNt3tqorMK7GDvcXdKs+qIMUbvenlH+w53ssPa
# 6rYP760ZuFrABrfserf0kFayNXVzwT7jarJOEjnFMBp+yi+uwQ2TnJuxczceG5FD
# HrII6sF6F879lP6ydY0BBZkZ9t39e/svNRieA5gUnv/YcM/bIMY/QYmd9F0B+ebF
# Yi+PH4AkXahNkFgK85OIaRrDGvhnxOa/5zGL7Oiii7+J9/QHkdJGlfnRfbQ3QXM/
# 5/umBOKG4JoFY1niZ5RVH5PT0+uCjwcqhTbnvUtfK+N+yB2b9rEZvp2Tv4ZwYzEd
# 9A9VsYMuZiCSbaFMk77LwVbklpnw4aHWJXJkEYmJvxRbcThE8FQyOoVkSuKc5OWZ
# 2+WM/j50oblA0tCU53AauvUOZRoQBh89nHK+m5pOXKXdYMJ+ceuLYF8h5y/cXLQM
# OmqLJz5l7MLqGwU0zHV+MEO8L1Fo2zEEQ4iL4BX8YknKXonHGQacSCaLZot2kyJV
# RsFSxn0PlPvHVp0YdsCMzdeiw9jAZ7K9s1WxsZGEBrK/obipX6uxjEpyUA9mbVPl
# jlb3R4MWI0E2xI/NM6F4Ac8Ceax3YWLT+aWCZeqiIMLxyyWZg+i1KY8ZEzMeNTKC
# EI5wF1wxqr6T1/MQo+8tAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUcF4XP26dV+8S
# usoA1XXQ2TDSmdIwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAMATzg6R/A0ldO7M
# qGxD1VJji5yVA1hHb0Hc0Yjtv7WkxQ8iwfflulX5Us64tD3+3NT1JkphWzaAWf2w
# KdAw35RxtQG1iON3HEZ0X23nde4Kg/Wfbx5rEHkZ9bzKnR/2N5A16+w/1pbwJzdf
# RcnJT3cLyawr/kYjMWd63OP0Glq70ua4WUE/Po5pU7rQRbWEoQozY24hAqOcwuRc
# m6Cb0JBeTOCeRBntEKgjKep4pRaQt7b9vusT97WeJcfaVosmmPtsZsawgnpIjbBa
# 55tHfuk0vDkZtbIXjU4mr5dns9dnanBdBS2PY3N3hIfCPEOszquwHLkfkFZ/9bxw
# 8/eRJldtoukHo16afE/AqP/smmGJh5ZR0pmgW6QcX+61rdi5kDJTzCFaoMyYzUS0
# SEbyrDZ/p2KOuKAYNngljiOlllct0uJVz2agfczGjjsKi2AS1WaXvOhgZNmGw42S
# FB1qaloa8Kaux9Q2HHLE8gee/5rgOnx9zSbfVUc7IcRNodq6R7v+Rz+P6XKtOgyC
# qW/+rhPmp/n7Fq2BGTRkcy//hmS32p6qyglr2K4OoJDJXxFs6lwc8D86qlUeGjUy
# o7hVy5VvyA+y0mGnEAuA85tsOcUPlzwWF5sv+B5fz35OW3X4Spk5SiNulnLFRPM5
# XCsSHqvcbC8R3qwj2w1evPhZxDuNMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
# mQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
# dGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1
# WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjK
# NVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhg
# fWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJp
# rx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/d
# vI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka9
# 7aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKR
# Hh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9itu
# qBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyO
# ArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItb
# oKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6
# bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6t
# AgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQW
# BBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacb
# UzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYz
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnku
# aHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIA
# QwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2
# VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwu
# bWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEw
# LTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/q
# XBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6
# U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVt
# I1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis
# 9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTp
# kbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0
# sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138e
# W0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJ
# sWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7
# Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0
# dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQ
# tB1VM1izoXBm8qGCAtQwggI9AgEBMIIBAKGB2KSB1TCB0jELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxh
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjox
# NzlFLTRCQjAtODI0NjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAbfPR1fBX6HxYfyPx8zYzJU5fIQyggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOmJFk4wIhgPMjAyNDAyMjgxMDE3NTBaGA8yMDI0MDIyOTEwMTc1MFowdDA6Bgor
# BgEEAYRZCgQBMSwwKjAKAgUA6YkWTgIBADAHAgEAAgIaCDAHAgEAAgJFEDAKAgUA
# 6YpnzgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAEnXAPETMUZDtE0BpenI
# /NEAmIJ54O2KtSf1EfUS69X4Az+lFg+j18mFK0gKjiFdxb/AeozwbND9wRJK+wm5
# qusbXdQMD8+2bGbQ13Fqyk+X9DBgy+ww6edKaTZo0ORTG7m9P5sNZOu+OdNNCPk7
# SugDO1mCqO/ybsBbOIkZni7qMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTACEzMAAAHg1PwfExUffl0AAQAAAeAwDQYJYIZIAWUDBAIB
# BQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQx
# IgQgEUP5ZHCIgjnuoKVABJ927Yw4SQ5Cqm7EOALijnarc4EwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCDj7lK/8jnlbTjPvc77DCCSb4TZApY9nJm5whsK/2kK
# wTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB4NT8
# HxMVH35dAAEAAAHgMCIEIJTdGuA++QREm07GEZDV9Tx8t8gso1Kuc5Nj0uFURwcN
# MA0GCSqGSIb3DQEBCwUABIICAEYnmC1uk4k7i8jSQa1xhFcfMA/ntyXKLccUaKTr
# vcL2/1OsENpRTvhHMbrSkHWBAjp0nIJtlV61wslOxNWgoAriZRY8V9R8vnbmGYvn
# rv4LA8rHesLGcEHxUKdfvGC0Xpv1xM6TEon+YANh/eKKthCn2/8LEg/1Su4Fg+mA
# lNviGkLxRxOwQxfikhoihH1rZ1h7yZqLeh8R+lvvA7UKmM9R4UQMd93DhGK+BrIT
# TlrrtD+bwiqZ6ihRSmolkYJaM39bSkVyacR7rFEEgmHRuz4zlltu6zNW4fewZbHe
# tnVkPn3zJ7oEqyn9fJJAtWwKpT1Y81BLS+aBfwsMg2Z9WfK3ICly6IRUZRIYMK/N
# gmPoS06pm/v7quajq+jAvS0FQ2dula1iuoUXAYy9YaYGu2+peNTwoxDiTfSuGb7I
# 41I6a467qT9yPnAtP869hvVtBC2QwzbOzyIOrcq6m413M+wln/8K+P0Q+paY6gAp
# 9MkFTC99nkDXwjC9Wqfp2L0lLV2jAxTjbptBYrXpnDiEsI19350lOhQr6D7cCwD4
# 0vwZSFLpkfq+dBQQd9akDJDhpHcT1RUSTwBTYGW9FWgoFXCV7NhrGzIN2GllXGU0
# B6G2HEY/mD54aga+5h8Wx5qv0PcdasOtwf4fYfIBYsyiX8dh1oAZ8qqrAEHcM+t0
# azuj
# SIG # End signature block
