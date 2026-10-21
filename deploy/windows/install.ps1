#Requires -RunAsAdministrator
param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$AppDir = "/opt/miller",
    [int]$HttpPort = 80
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$deployDir = Split-Path -Parent $here

function Invoke-Wsl([string]$Command) {
    wsl.exe -d $Distro -u root -- bash -lc $Command
    if ($LASTEXITCODE -ne 0) { throw "WSL command failed: $Command" }
}

$envFile = Join-Path $deployDir ".env"
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $deployDir ".env.example") $envFile
    Write-Host "Created $envFile - set POSTGRES_PASSWORD, DJANGO_SECRET_KEY and DUMP_* values, then run this script again."
    exit 0
}

$installed = (wsl.exe -l -q 2>$null) -replace "`0", "" | Where-Object { $_.Trim() -eq $Distro }
if (-not $installed) {
    Write-Host "Installing WSL and $Distro..."
    wsl.exe --install -d $Distro --no-launch
    Write-Host "Restart Windows, open $Distro once from the Start menu to create a user, then run this script again."
    exit 0
}

$build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
$mirrored = $build -ge 22621
$wslConfig = Join-Path $env:USERPROFILE ".wslconfig"
$config = "[wsl2]`r`nvmIdleTimeout=-1`r`n"
if ($mirrored) { $config += "networkingMode=mirrored`r`n" }
Set-Content -Path $wslConfig -Value $config -Encoding ascii
wsl.exe --shutdown

Write-Host "Enabling systemd and installing Docker Engine inside $Distro..."
Invoke-Wsl "printf '[boot]\nsystemd=true\n' > /etc/wsl.conf"
wsl.exe --terminate $Distro
Invoke-Wsl "command -v docker >/dev/null || (curl -fsSL https://get.docker.com | sh)"
Invoke-Wsl "systemctl enable --now docker"

Write-Host "Copying deploy files to $AppDir..."
$wslDeploy = (wsl.exe -d $Distro -- wslpath -a ($deployDir -replace '\', '/')).Trim()
Invoke-Wsl "mkdir -p $AppDir && cp '$wslDeploy/docker-compose.yml' '$wslDeploy/init.sql' $AppDir/ && cp '$wslDeploy/start.sh' /usr/local/bin/miller-start && chmod +x /usr/local/bin/miller-start"
Invoke-Wsl "test -f $AppDir/.env || cp '$wslDeploy/.env' $AppDir/.env"

Write-Host "Docker Hub login (account with access to the private image repo):"
wsl.exe -d $Distro -u root -- docker login

Invoke-Wsl "cd $AppDir && docker compose pull && docker compose up -d"

$taskName = "Miller Server"
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d $Distro -u root -- /usr/local/bin/miller-start"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
$cred = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message "Windows password for the startup task (runs without login)"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
    -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest | Out-Null

New-NetFirewallRule -DisplayName "Miller HTTP" -Direction Inbound -Protocol TCP -LocalPort $HttpPort -Action Allow -ErrorAction SilentlyContinue | Out-Null
if ($mirrored) {
    Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
} else {
    $refresh = Join-Path $here "portproxy.ps1"
    $proxyAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$refresh`" -Distro $Distro -Port $HttpPort"
    Unregister-ScheduledTask -TaskName "Miller Port Proxy" -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName "Miller Port Proxy" -Action $proxyAction -Trigger $trigger -Settings $settings `
        -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest | Out-Null
    & $refresh -Distro $Distro -Port $HttpPort
}

powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setactive SCHEME_CURRENT

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "vEthernet|Loopback" -and $_.PrefixOrigin -ne "WellKnown" } | Select-Object -First 1).IPAddress
Write-Host "Done. Miller: http://$ip`:$HttpPort (starts automatically after every boot, no login needed)"
