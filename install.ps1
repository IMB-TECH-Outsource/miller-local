#Requires -RunAsAdministrator
param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$AppDir = "/opt/miller"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Wsl([string]$Command) {
    wsl.exe -d $Distro -u root -- bash -lc $Command
    if ($LASTEXITCODE -ne 0) { throw "WSL command failed: $Command" }
}

function New-Secret([int]$Length) {
    $chars = [char[]]"abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

Write-Host "== 1/7 .env"
$envFile = Join-Path $here ".env"
if (-not (Test-Path $envFile)) {
    $text = Get-Content (Join-Path $here ".env.example") -Raw
    $text = $text -replace "(?m)^POSTGRES_PASSWORD=change-me", "POSTGRES_PASSWORD=$(New-Secret 24)"
    $text = $text -replace "(?m)^DJANGO_SECRET_KEY=change-me", "DJANGO_SECRET_KEY=$(New-Secret 50)"
    Set-Content -Path $envFile -Value $text -Encoding ascii -NoNewline
    Write-Host "Created .env with random passwords. Fill DUMP_BOT_TOKEN / DUMP_CHAT_ID in it later if needed."
}
$httpPort = 80
$portLine = Select-String -Path $envFile -Pattern "^HTTP_PORT=(\d+)" | Select-Object -First 1
if ($portLine) { $httpPort = [int]$portLine.Matches[0].Groups[1].Value }

Write-Host "== 2/7 WSL + $Distro"
$installed = (wsl.exe -l -q 2>$null) -replace "`0", "" | Where-Object { $_.Trim() -eq $Distro }
if (-not $installed) {
    wsl.exe --install -d $Distro --no-launch
    Write-Host ""
    Write-Host "WSL is being installed. Restart Windows, open '$Distro' once from the Start menu,"
    Write-Host "create a Linux user when it asks, close it, then run install.cmd again."
    exit 0
}

Write-Host "== 3/7 WSL settings"
$build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
$mirrored = $build -ge 22621
$config = "[wsl2]`r`nvmIdleTimeout=-1`r`n"
if ($mirrored) { $config += "networkingMode=mirrored`r`n" }
Set-Content -Path (Join-Path $env:USERPROFILE ".wslconfig") -Value $config -Encoding ascii
wsl.exe --shutdown
Start-Sleep -Seconds 3
Invoke-Wsl "printf '[boot]\nsystemd=true\n' > /etc/wsl.conf"
wsl.exe --terminate $Distro
Start-Sleep -Seconds 3

Write-Host "== 4/7 Docker Engine"
Invoke-Wsl "command -v docker >/dev/null || (curl -fsSL https://get.docker.com | sh)"
Invoke-Wsl "systemctl enable --now docker"

Write-Host "== 5/7 Miller files and Docker Hub login"
$wslHere = (wsl.exe -d $Distro -u root -- wslpath -a ($here -replace '\', '/')).Trim()
Invoke-Wsl "mkdir -p $AppDir && cp '$wslHere/docker-compose.yml' '$wslHere/.env' $AppDir/"
Write-Host "Docker Hub login (account with access to imbtechdev/imb_hr):"
wsl.exe -d $Distro -u root -- docker login
if ($LASTEXITCODE -ne 0) { throw "docker login failed" }
Invoke-Wsl "cd $AppDir && docker compose pull && docker compose up -d"

Write-Host "== 6/7 Start on boot"
Copy-Item (Join-Path $here "start.ps1") "C:\ProgramData\miller-start.ps1" -Force
$cred = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message "Windows password of this account (the startup task runs as you, without login)"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\ProgramData\miller-start.ps1 -Distro $Distro -AppDir $AppDir -Port $httpPort -PortProxy $(-not $mirrored)"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Unregister-ScheduledTask -TaskName "Miller Server" -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName "Miller Server" -Action $action -Trigger $trigger -Settings $settings `
    -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest | Out-Null

Write-Host "== 7/7 Network, firewall, power"
Remove-NetFirewallRule -DisplayName "Miller HTTP" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Miller HTTP" -Direction Inbound -Protocol TCP -LocalPort $httpPort -Action Allow -Profile Any | Out-Null
if ($mirrored) {
    Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
} else {
    Set-Service iphlpsvc -StartupType Automatic
    Start-Service iphlpsvc
}
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setactive SCHEME_CURRENT

Start-ScheduledTask -TaskName "Miller Server"
Start-Sleep -Seconds 20

$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch "vEthernet|Loopback|WSL" -and $_.IPAddress -notlike "169.254*" } |
    Select-Object -ExpandProperty IPAddress
$suffix = if ($httpPort -eq 80) { "" } else { ":$httpPort" }
Write-Host ""
Write-Host "Miller is installed and starts automatically when this laptop is turned on."
foreach ($ip in $ips) { Write-Host "  Open on the same Wi-Fi:  http://$ip$suffix" }
Write-Host "Tip: reserve this IP for the laptop in the Wi-Fi router so the address never changes."
