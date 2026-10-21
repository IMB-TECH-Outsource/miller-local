param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$AppDir = "/opt/miller",
    [int]$Port = 80,
    [string]$PortProxy = "False"
)

wsl.exe -d $Distro -u root -- sh -c "until docker info >/dev/null 2>&1; do sleep 2; done; cd $AppDir && docker compose up -d"

if ($PortProxy -eq "True") {
    $ip = $null
    for ($i = 0; $i -lt 30 -and -not $ip; $i++) {
        $ip = ((wsl.exe -d $Distro -u root -- hostname -I) -split " ")[0].Trim()
        if (-not $ip) { Start-Sleep -Seconds 5 }
    }
    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 | Out-Null
    netsh interface portproxy add v4tov4 listenport=$Port listenaddress=0.0.0.0 connectport=$Port connectaddress=$ip | Out-Null
}

wsl.exe -d $Distro -u root -- sleep infinity
