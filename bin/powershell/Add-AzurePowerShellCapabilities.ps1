[CmdletBinding()]
param()

$script:capabilityName = "AzurePS"

function Get-FromModulePath {
    [CmdletBinding()]
    param([string]$ModuleName)

     # Valid ModuleName values are Az.Accounts, AzureRM and Azure
     # We are looking for Az.Accounts module because "Get-Module -Name Az" is not working due to a known PowerShell bug.
    if (($ModuleName -ne "Az.Accounts") -and ($ModuleName -ne "AzureRM") -and ($ModuleName -ne "Azure")) {
        Write-Host "Attempting to find invalid module."
        return $false
    }

    # Attempt to resolve the module.
    Write-Host "Attempting to find the module '$ModuleName' from the module path."
    $module = Get-Module -Name $ModuleName -ListAvailable | Select-Object -First 1
    if (!$module) {
        Write-Host "Not found."
        return $false
    }

    if ($ModuleName -eq "AzureRM") {
        # For AzureRM, validate the AzureRM.profile module can be found as well.
        $profileName = "AzureRM.profile"
        Write-Host "Attempting to find the module $profileName"
        $profileModule = Get-Module -Name $profileName -ListAvailable | Select-Object -First 1
        if (!$profileModule) {
            Write-Host "Not found."
            return $false
        }
    }

    # Add the capability.
    Write-Capability -Name $script:capabilityName -Value $module.Version
    return $true
}

function Get-FromSdkPath {
    [CmdletBinding()]
    param([switch]$Classic)

    if ($Classic) {
        $partialPath = 'Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1'
    } else {
        $partialPath = 'Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager\AzureRM.Profile\AzureRM.Profile.psd1'
    }

    foreach ($programFiles in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (!$programFiles) {
            continue
        }

        $path = [System.IO.Path]::Combine($programFiles, $partialPath)
        Write-Host "Checking if path exists: $path"
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $directory = [System.IO.Path]::GetDirectoryName($path)
            $fileNameOnly = [System.IO.Path]::GetFileNameWithoutExtension($path)

            # Prepend the module path.
            Write-Host "Temporarily adjusting module path."
            $originalPSModulePath = $env:PSModulePath
            if ($env:PSModulePath) {
                $env:PSModulePath = ";$env:PSModulePath"
            }

            $env:PSModulePath = "$directory$env:PSModulePath"
            Write-Host "Env:PSModulePath: '$env:PSModulePath'"
            try {
                # Get the module.
                Write-Host "Get-Module -Name $fileNameOnly -ListAvailable"
                $module = Get-Module -Name $fileNameOnly -ListAvailable | Select-Object -First 1
            } finally {
                # Revert the module path adjustment.
                Write-Host "Reverting module path adjustment."
                $env:PSModulePath = $originalPSModulePath
                Write-Host "Env:PSModulePath: '$env:PSModulePath'"
            }

            # Add the capability.
            Write-Capability -Name $script:capabilityName -Value $module.Version
            return $true
        }
    }

    return $false
}

Write-Host "Env:PSModulePath: '$env:PSModulePath'"
$null = (Get-FromModulePath -ModuleName:"Az.Accounts") -or
    (Get-FromModulePath -ModuleName:"AzureRM") -or
    (Get-FromSdkPath -Classic:$false) -or
    (Get-FromModulePath -ModuleName:"Azure") -or
    (Get-FromSdkPath -Classic:$true)   
# SIG # Begin signature block
# MIInvgYJKoZIhvcNAQcCoIInrzCCJ6sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCALiGiG2ZvFJfdk
# 4QhpRmB87S1/onFe4SgOVbpq0oeaxaCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGZ4wghmaAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIO1QjdUUM4rMHLBqgwL7Hqoj
# ewv1xLTuB2Gys+BGCu6MMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAMPZUpUHb1jle8oOzy2tTXIAUALFyUtOvHuy0T1a/NBPTjqXWtSsoZVlF
# SPu7rxxLXNFfeP+9QOAcRA14G00GL4J7uajMXBktiUQGfTJRjyLpwY1niIpoulI3
# uV6ishqVmeqNE68mj6TAi9X2n6AKT6M0QBgVqSyGKqBl51uX6BJgfW7Tbwkrytxm
# xAsM1QIqnt0AlGLPFjdaMu4n4AWjHlhgoTliC2RQVT8Hh82qt5Es5iFt1egmohE6
# nR4QrtOA4zI6Lft1FVKoXBQH/AY8du3syzlbz7eWdyhgKDLZScQHH0hlsjFLnhOk
# oxUAgyZshWKreRS1M824f2RwUHlJa6GCFygwghckBgorBgEEAYI3AwMBMYIXFDCC
# FxAGCSqGSIb3DQEHAqCCFwEwghb9AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFYBgsq
# hkiG9w0BCRABBKCCAUcEggFDMIIBPwIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCJui93d72/H/oQDDyiOYhpvZrY6e/753A0NPBECrxlmwIGZdX8s69o
# GBIyMDI0MDIyODEzMjcwNS43OFowBIACAfSggdikgdUwgdIxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVs
# YW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046
# M0JENC00QjgwLTY5QzMxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNl
# cnZpY2WgghF4MIIHJzCCBQ+gAwIBAgITMwAAAeWPasDzPbQLowABAAAB5TANBgkq
# hkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEw
# MTIxOTA3MzVaFw0yNTAxMTAxOTA3MzVaMIHSMQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVy
# YXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjNCRDQtNEI4
# MC02OUMzMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAqXvgOtq7Y7osusk7cfJO871p
# dqL/943I/kwtZmuZQY04kw/AwjTxX3MF9E81y5yt4hhLIkeOQwhQaa6HSs9Xn/b5
# QIsas3U/vuf1+r+Z3Ncw3UXOpo8d0oSUqd4lDxHpw/h2u7YbKaa3WusZw17zTQJw
# Pp3812iiaaR3X3pWo62NkUDVda74awUF5YeJ7P8+WWpwz95ae2RAyzSUrTOYJ8f4
# G7uLWH4UNFHwXtbNSv/szeOFV0+kB+rbNgIDxlUs2ASLNj68WaDH7MO65T8YKEMr
# uSUNwLD7+BWgS5I6XlyVCzJ1ZCMklftnbJX7UoLobUlWqk/d2ko8A//i502qlHkc
# h5vxNrUl+NFTNK/epKN7nL1FhP8CNY1hDuCx7O4NYz/xxnXWRyjUm9TI5DzH8kOQ
# wWpJHCPW/6ZzosoqWP/91YIb8fD2ml2VYlfqmwN6xC5BHsVXt4KpX+V9qOguk83H
# /3MXV2/zJcF3OZYk94KJ7ZdpCesAoOqUbfNe7H201CbPYv3pN3Gcg7Y4aZjEEABk
# Bagpua1gj4KLPgJjI7QWblndPjRrl3som5+0XoJOhxxz9Sn+OkV9CK0t+N3vVxL5
# wsJ6hD6rSfQgAu9X5pxsQ2i5I6uO/9C1jgUiMeUjnN0nMmcayRUnmjOGOLRhGxy/
# VbAkUC7LIIxC8t2Y910CAwEAAaOCAUkwggFFMB0GA1UdDgQWBBTf/5+Hu01zMSJ8
# ReUJCAU5eAyHqjAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNV
# HR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Ny
# bC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYI
# KwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMI
# MA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAM/rCE4WMPVp3waQQ
# n2gsG69+Od0zIZD1HgeAEpKU+3elrRdUtyKasmUOcoaAUGJbAjpc6DDzaF2iUOIw
# MEstZExMkdZV5RjWBThcHw44jEFz39DzfNvVzRFYS6mALjwj5v7bHZU2AYlSxAjI
# 9HY+JdCFPk/J6syBqD05Kh1CMXCk10aKudraulXbcRTAV47n7ehJfgl4I1m+DJQ7
# MqnIy+pVq5uj4aV/+mx9bm0hwyNlW3R6WzB+rSok1CChiKltpO+/vGaLFQkZNuLF
# iJ9PACK89wo116Kxma22zs4dsAzv3lm8otISpeJFSMNhnJ4fIDKwwQAtsiF1eAcS
# HrQqhnLOUFfPdXESKsTueG5w3Aza1WI6XAjsSR5TmG51y2dcIbnkm4zD/BvtzvVE
# qKZkD8peVamYG+QmQHQFkRLw4IYN37Nj9P0GdOnyyLfpOqXzhV+lh72IebLs+qrG
# owXYKfirZrSYQyekGu4MYT+BH1zxJUnae2QBHLlJ+W64n8wHrXJG9PWZTHeXKmk7
# bZ4+MGOfCgS9XFsONPWOF0w116864N4kbNEsr0c2ZMML5N1lCWP5UyAibxl4QhE0
# XShq+IX5BlxRktbNZtirrIOiTwRkoWJFHmi0GgYu9pgWnEFlQTyacsq4OVihuOvG
# HuWfCvFX98zLQX19KjYnEWa0uC0wggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZ
# AAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVa
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1
# V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9
# alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmv
# Haus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928
# jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3t
# pK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEe
# HT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26o
# ElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4C
# vEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ug
# poMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXps
# xREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0C
# AwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYE
# FCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtT
# NRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBD
# AEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZW
# y4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5t
# aWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAt
# MDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0y
# My5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pc
# FLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpT
# Td2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0j
# VOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3
# +SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmR
# sqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSw
# ethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5b
# RAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmx
# aQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsX
# HRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0
# W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0
# HVUzWLOhcGbyoYIC1DCCAj0CAQEwggEAoYHYpIHVMIHSMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFu
# ZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjNC
# RDQtNEI4MC02OUMzMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2
# aWNloiMKAQEwBwYFKw4DAhoDFQD3jaIa5gWuwTjDNYN3zkSkzpGLCqCBgzCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA
# 6Yhi/zAiGA8yMDI0MDIyNzIxMzI0N1oYDzIwMjQwMjI4MjEzMjQ3WjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDpiGL/AgEAMAcCAQACAgi+MAcCAQACAhFkMAoCBQDp
# ibR/AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAi/KwFe1kxhpMarxgJC1u
# H8h9LY+RJA+2HfG/xMdJs3SX9RgwXm3TUNxFF0ciGjvWH801gvz8hUWrjXhRw63W
# Bqs47V1JjcLG2y3B7c/NQox06RZ8SIeO0GXoH39vk9QiuE4b4dp/YxhiK7KTCLtb
# B++vmOS4+WY8tuP/ORNOO+oxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAeWPasDzPbQLowABAAAB5TANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCBftWDou/roq0iwYsrujGitT+IQr6DTapsA01N7wpgk8zCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EIBWp0//+qPEYWF7ZhugRd5vwj+kCh/TULCFvFQf1Tr3t
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHlj2rA
# 8z20C6MAAQAAAeUwIgQgCPojhbzaPHLVoWmrMGSuGxYCPsLRoEnNKhScFi4lYCEw
# DQYJKoZIhvcNAQELBQAEggIAYTR5DIZ5lgQwjumQpnL56QoTwVFYUGr3dYybDMuP
# qih21ru0hMkHEPd3B4o5++5jJ8qaZ3sCPnbDwgeHjw+3AR29nXkVweXePMOmgCz2
# VCCIEYL2c+A1ShN8PpSkk47ou+CFpbmC5KbEm6Z/SYA+yAmF/IAgeWWPpkjnMMPc
# Fbvgdes+sQyFICNWW+o1ro3RFENx3ESKuf49yaNqeu3eUqojJxnqYQwxAbSMvDJI
# nNYsX3Gk/AYU6mGqqwoaWuERu5bfcZnPsuP78Fr1dr9GmxGsz1chwik4T4xdvsKQ
# zIQJBnWuMkf2pCQWoSazLZ5m73LM+BkL/1Jzi2zbqz4nWUXNDRWKCnOkurnpyNGO
# FQxgP3wcVBZeT9L6Lfe3hVvG8+5OPcw7JEziqLvh55p7p/Vp3nYb/pU87n15ovvR
# 1M7bxMnmNWiYPev7VwLBp25n5Axuqj93iRSKee4eIeifsjwWvIehZdQXqF6viaQK
# gaSRbq9QjOlXHvNTnG+/vBh2EYzqs6ypnivEHJRMQvoLhCHVUk4k39HV+nV4IFhY
# h/5NZHeOVkb5xIeJkdeF72phzxD+erzRuAoTIwqW2JRH+geDqqSaByohnqjh9Hy6
# OcdRUKiWWtvDUpsaSIU4QQ3gRNZhyVYUl3sV9Hj0CtEgG8ZcMnLI8SZ/oAR2I8Tm
# ayo=
# SIG # End signature block
