# Diagnostico da impressora Brother HL-L3240CDW
# Nao precisa de administrador. Gera um relatorio para colar no chat.
[CmdletBinding()]
param(
    [string]$Ip,
    [switch]$Pause
)

$ErrorActionPreference = 'Continue'

function Section($t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }

Write-Host '===== DIAGNOSTICO - Brother HL-L3240CDW =====' -ForegroundColor Green
$os = Get-CimInstance Win32_OperatingSystem
Write-Host ("Computador: {0} | {1} | {2}" -f $env:COMPUTERNAME, $os.Caption, $os.OSArchitecture)
Write-Host ("Data: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))

Section 'Impressoras instaladas'
$printers = Get-Printer -ErrorAction SilentlyContinue
$brPrinters = $printers | Where-Object { $_.Name -match 'Brother|HL-L3240' -or $_.DriverName -match 'Brother' }
if ($brPrinters) {
    $brPrinters | ForEach-Object { Write-Host (" - {0} | driver: {1} | porta: {2} | status: {3}" -f $_.Name, $_.DriverName, $_.PortName, $_.PrinterStatus) }
} else {
    Write-Host ' - Nenhuma impressora Brother instalada.'
}

Section 'Driver Brother no sistema'
$drv = Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Brother' }
if ($drv) { $drv | ForEach-Object { Write-Host (" - {0}" -f $_.Name) } } else { Write-Host ' - Nenhum driver Brother registrado.' }

Section 'Dispositivos USB Brother detectados'
$usb = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'Brother|HL-L3240' -or $_.InstanceId -match 'BROTHER' }
if ($usb) {
    $usb | ForEach-Object { Write-Host (" - {0} [{1}] status: {2}" -f $_.FriendlyName, $_.Class, $_.Status) }
} else {
    Write-Host ' - Nenhum dispositivo Brother no USB (cabo desconectado ou impressora desligada).'
}

Section 'Rede local'
$nets = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|Tailscale' -and $_.PrefixOrigin -in @('Dhcp','Manual') -and $_.PrefixLength -le 24 }
if (-not $nets) { Write-Host ' - Nenhuma rede IPv4 ativa encontrada.' }

$candidates = @()
foreach ($n in $nets) {
    Write-Host (" Interface: {0} | IP local: {1}/{2}" -f $n.InterfaceAlias, $n.IPAddress, $n.PrefixLength)
    if ($n.PrefixLength -lt 22) { Write-Host '   (sub-rede maior que /22; varredura pulada)'; continue }

    # Calcula o intervalo de IPs da sub-rede (/22 a /24 = ate 1022 hosts)
    $bytes = ([System.Net.IPAddress]::Parse($n.IPAddress)).GetAddressBytes()
    [Array]::Reverse($bytes)
    $ipInt = [int64][BitConverter]::ToUInt32($bytes, 0)
    $hostBits = 32 - $n.PrefixLength
    $network = $ipInt -band (-bnot ([int64][math]::Pow(2, $hostBits) - 1))
    $first = $network + 1
    $last  = $network + [int64][math]::Pow(2, $hostBits) - 2
    Write-Host ("   Varrendo {0} hosts na porta 9100 (impressao RAW)..." -f ($last - $first + 1))

    # Varre em blocos de 256 conexoes simultaneas
    for ($start = $first; $start -le $last; $start += 256) {
        $end = [math]::Min($start + 255, $last)
        $jobs = @()
        for ($a = $start; $a -le $end; $a++) {
            $b = [BitConverter]::GetBytes([uint32]$a)
            [Array]::Reverse($b)
            $addr = [System.Net.IPAddress]::new($b).ToString()
            $c = New-Object System.Net.Sockets.TcpClient
            $jobs += [PSCustomObject]@{ Ip = $addr; Client = $c; Async = $c.BeginConnect($addr, 9100, $null, $null) }
        }
        Start-Sleep -Seconds 3
        foreach ($j in $jobs) {
            if ($j.Async.IsCompleted -and $j.Client.Connected) { $candidates += $j.Ip }
            $j.Client.Close()
        }
    }
}

if ($candidates) {
    Write-Host ''
    Write-Host ' Dispositivos com porta 9100 aberta (possiveis impressoras):'
    foreach ($c in $candidates) {
        $id = ''
        try {
            $resp = Invoke-WebRequest -Uri "http://$c/" -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
            if ($resp.Content -match 'Brother')      { $id = 'BROTHER' }
            elseif ($resp.Content -match '<title>\s*([^<]+)') { $id = $Matches[1].Trim() }
        } catch { $id = 'sem resposta HTTP' }
        Write-Host ("  - {0}  ({1})" -f $c, $id)
        if ($id -eq 'BROTHER') {
            Write-Host ("    >>> Provavel Brother! Instale com: --ip={0}" -f $c) -ForegroundColor Green
        }
    }
} else {
    Write-Host ' - Nenhum dispositivo com porta 9100 aberta na(s) rede(s) varrida(s).'
    Write-Host '   Se a impressora estiver so no USB, isso e normal.'
}

if ($Ip) {
    Section "Teste do IP informado: $Ip"
    $ping = Test-Connection -ComputerName $Ip -Count 2 -Quiet -ErrorAction SilentlyContinue
    Write-Host (" Ping: {0}" -f $(if ($ping) { 'OK' } else { 'SEM RESPOSTA' }))
    foreach ($port in @(9100, 80, 631)) {
        $c = New-Object System.Net.Sockets.TcpClient
        $async = $c.BeginConnect($Ip, $port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne(2000) -and $c.Connected
        $c.Close()
        $label = switch ($port) { 9100 { 'RAW/impressao' } 80 { 'painel web' } 631 { 'IPP' } }
        Write-Host (" Porta {0} ({1}): {2}" -f $port, $label, $(if ($ok) { 'ABERTA' } else { 'fechada' }))
    }
}

Write-Host ''
Write-Host '===== FIM DO DIAGNOSTICO (copie tudo acima e cole no chat) =====' -ForegroundColor Green
if ($Pause) { Read-Host 'Pressione ENTER para fechar' | Out-Null }
