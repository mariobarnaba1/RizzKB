# RizzKB - expose Ollama on your Windows PC to your iPhone
# Run in PowerShell AS ADMINISTRATOR:  Right-click PowerShell > Run as administrator
#   Set-ExecutionPolicy -Scope Process Bypass; .\setup-ollama-windows.ps1

$Model = "qwen2.5vl:7b"   # vision model so screenshots work

Write-Host "1/4  Letting Ollama listen on your network (not just localhost)..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "User")
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "30m", "User")
$env:OLLAMA_HOST = "0.0.0.0:11434"

Write-Host "2/4  Opening Windows Firewall port 11434 (private networks only)..." -ForegroundColor Cyan
if (-not (Get-NetFirewallRule -DisplayName "Ollama (RizzKB)" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Ollama (RizzKB)" -Direction Inbound -Protocol TCP `
        -LocalPort 11434 -Action Allow -Profile Private | Out-Null
}
# Tailscale devices only (100.64.0.0/10), any network profile
if (-not (Get-NetFirewallRule -DisplayName "Ollama (RizzKB Tailscale)" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Ollama (RizzKB Tailscale)" -Direction Inbound -Protocol TCP `
        -LocalPort 11434 -RemoteAddress 100.64.0.0/10 -Action Allow -Profile Any | Out-Null
}

Write-Host "3/4  Restarting Ollama..." -ForegroundColor Cyan
Get-Process "ollama*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$app = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama app.exe"
if (Test-Path $app) { Start-Process $app } else { Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden }
Start-Sleep -Seconds 5

Write-Host "4/4  Pulling $Model (several GB, first time only)..." -ForegroundColor Cyan
ollama pull $Model

$lan = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.PrefixOrigin -ne "WellKnown" } |
    Select-Object -ExpandProperty IPAddress
$ts = $lan | Where-Object { $_ -like "100.*" }

Write-Host ""
Write-Host "Done. Put one of these in the RizzKB app as the server URL:" -ForegroundColor Green
foreach ($ip in $lan) {
    $tag = if ($ip -like "100.*") { "(Tailscale - works anywhere)" } else { "(home Wi-Fi only)" }
    Write-Host "   http://$($ip):11434   $tag"
}
if (-not $ts) {
    Write-Host ""
    Write-Host "Tip: install Tailscale on this PC and your iPhone to use RizzKB away from home." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Make sure your Wi-Fi network is set to 'Private' in Windows settings, or the firewall rule won't apply."
