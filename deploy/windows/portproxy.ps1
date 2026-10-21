param([string]$Distro = "Ubuntu-24.04", [int]$Port = 80)

for ($i = 0; $i -lt 30; $i++) {
    $ip = (wsl.exe -d $Distro -u root -- hostname -I).Trim().Split(" ")[0]
    if ($ip) { break }
    Start-Sleep -Seconds 5
}
netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 | Out-Null
netsh interface portproxy add v4tov4 listenport=$Port listenaddress=0.0.0.0 connectport=$Port connectaddress=$ip | Out-Null
