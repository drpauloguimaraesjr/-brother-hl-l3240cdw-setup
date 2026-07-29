# Instalador da impressora Brother HL-L3240CDW (Windows x64)
# Instala o driver oficial (broch20a.inf) via pnputil e configura a impressora.
# Ordem de deteccao: IP informado > fila USB existente > busca na rede > espera USB.
[CmdletBinding()]
param(
    [string]$Ip,
    [switch]$Uninstall,
    [switch]$Pause
)

$ErrorActionPreference = 'Stop'
$DriverName  = 'Brother HL-L3240CDW series'
$PrinterName = 'Brother HL-L3240CDW series'
$InfPath     = Join-Path (Split-Path $PSScriptRoot -Parent) 'driver\broch20a.inf'

function Done($code) {
    if ($Pause) { Read-Host 'Pressione ENTER para fechar' | Out-Null }
    exit $code
}

# Filas locais reais da HL-L3240CDW (ignora redirecionamentos de Area de Trabalho Remota)
function Get-LocalQueues {
    Get-Printer -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like '*HL-L3240CDW*' -and
        $_.DriverName -ne 'Remote Desktop Easy Print' -and
        $_.PortName -notlike 'TS*'
    }
}

# Cria/atualiza a impressora apontando para um IP (porta RAW 9100)
function Install-ViaIp([string]$addr) {
    $portName = "IP_$addr"
    if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
        Add-PrinterPort -Name $portName -PrinterHostAddress $addr
    }
    $existing = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($existing) {
        Set-Printer -Name $PrinterName -PortName $portName -DriverName $DriverName
    } else {
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $portName
    }
    Write-Host "Impressora '$PrinterName' configurada no IP $addr." -ForegroundColor Green
}

# Varre as sub-redes locais (/22 a /30) procurando uma Brother com porta 9100 aberta
function Find-BrotherIps {
    $hits = @()
    $nets = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|Tailscale' -and
                       $_.PrefixOrigin -in @('Dhcp','Manual') -and
                       $_.PrefixLength -ge 22 -and $_.PrefixLength -le 30 }
    foreach ($n in $nets) {
        $bytes = ([System.Net.IPAddress]::Parse($n.IPAddress)).GetAddressBytes()
        [Array]::Reverse($bytes)
        $ipInt = [int64][BitConverter]::ToUInt32($bytes, 0)
        $hostBits = 32 - $n.PrefixLength
        $network = $ipInt -band (-bnot ([int64][math]::Pow(2, $hostBits) - 1))
        $first = $network + 1
        $last  = $network + [int64][math]::Pow(2, $hostBits) - 2
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
                if ($j.Async.IsCompleted -and $j.Client.Connected) { $hits += $j.Ip }
                $j.Client.Close()
            }
        }
    }
    # Confirma quais candidatos sao Brother pelo painel web
    $brother = @()
    foreach ($h in $hits) {
        try {
            $r = Invoke-WebRequest -Uri "http://$h/" -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
            if ($r.Content -match 'Brother') { $brother += $h }
        } catch { }
    }
    return $brother
}

try {
    $identity = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'ERRO: execute este script como administrador.' -ForegroundColor Red
        Done 1
    }

    if ($Uninstall) {
        Write-Host '== Removendo a impressora Brother HL-L3240CDW =='
        Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue | Remove-Printer
        Get-PrinterPort -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'IP_*' -and $_.Description -eq 'Brother HL-L3240CDW' } |
            ForEach-Object { Remove-PrinterPort -Name $_.Name -ErrorAction SilentlyContinue }
        try { Remove-PrinterDriver -Name $DriverName -ErrorAction Stop } catch {
            Write-Host "Aviso: driver nao removido ($($_.Exception.Message))"
        }
        $pkg = Get-WindowsDriver -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.OriginalFileName -like '*broch20a.inf' } | Select-Object -First 1
        if ($pkg) { pnputil /delete-driver $pkg.Driver /uninstall | Out-Null }
        Write-Host 'Remocao concluida.' -ForegroundColor Green
        Done 0
    }

    if (-not (Test-Path $InfPath)) {
        Write-Host "ERRO: driver nao encontrado em $InfPath" -ForegroundColor Red
        Done 1
    }

    Write-Host '== 1/3 Instalando o driver no repositorio do Windows (pnputil) =='
    pnputil /add-driver "$InfPath" /install
    # Codigos de sucesso do pnputil: 0, 259 (nada mais a fazer, dispositivo ja
    # atualizado) e 3010 (sucesso, requer reinicializacao)
    if ($LASTEXITCODE -notin @(0, 259, 3010)) {
        Write-Host "ERRO: pnputil retornou codigo $LASTEXITCODE" -ForegroundColor Red
        Done $LASTEXITCODE
    }
    if ($LASTEXITCODE -eq 3010) {
        Write-Host 'Aviso: o Windows pediu reinicializacao para concluir o driver.' -ForegroundColor Yellow
    }

    Write-Host '== 2/3 Registrando o driver de impressao =='
    if (-not (Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue)) {
        Add-PrinterDriver -Name $DriverName
    }
    Write-Host "Driver '$DriverName' registrado."

    Write-Host '== 3/3 Configurando a impressora =='
    if ($Ip) {
        Install-ViaIp $Ip
    } else {
        $queues = @(Get-LocalQueues)
        if ($queues) {
            foreach ($q in $queues) {
                if ($q.DriverName -ne $DriverName) {
                    # O Windows costuma criar a fila com o driver generico (Microsoft IPP Class
                    # Driver); troca para o driver oficial da Brother
                    Set-Printer -Name $q.Name -DriverName $DriverName
                    Write-Host "Fila '$($q.Name)' (porta $($q.PortName)): driver trocado de '$($q.DriverName)' para o oficial da Brother." -ForegroundColor Green
                } else {
                    Write-Host "Fila '$($q.Name)' (porta $($q.PortName)) ja usa o driver oficial da Brother." -ForegroundColor Green
                }
            }
        } else {
            Write-Host 'Impressora nao encontrada no USB. Procurando na rede local...'
            $ips = @(Find-BrotherIps)
            if ($ips.Count -gt 0) {
                if ($ips.Count -gt 1) {
                    Write-Host ("Mais de uma Brother na rede ({0}); usando a primeira." -f ($ips -join ', ')) -ForegroundColor Yellow
                }
                Write-Host "Brother encontrada na rede: $($ips[0])"
                Install-ViaIp $ips[0]
            } else {
                Write-Host 'Nada na rede. Conecte o cabo USB da impressora agora. Aguardando (ate 60s)...'
                for ($i = 0; $i -lt 12 -and -not $queues; $i++) {
                    Start-Sleep -Seconds 5
                    $queues = @(Get-LocalQueues)
                }
                if ($queues) {
                    foreach ($q in $queues) {
                        if ($q.DriverName -ne $DriverName) {
                            Set-Printer -Name $q.Name -DriverName $DriverName
                        }
                        Write-Host "Impressora instalada via USB: $($q.Name)." -ForegroundColor Green
                    }
                } else {
                    Write-Host 'O driver foi instalado, mas a impressora nao foi encontrada nem no USB nem na rede.' -ForegroundColor Yellow
                    Write-Host 'Verifique se ela esta ligada. Para rede, configure o Wi-Fi no painel dela'
                    Write-Host '(Menu > Rede > WLAN > Assistente Config.) e rode novamente.'
                }
            }
        }
    }

    Write-Host ''
    Write-Host 'Concluido!' -ForegroundColor Green
    Done 0
}
catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Done 1
}
