# Instalador da impressora Brother HL-L3240CDW (Windows x64)
# Instala o driver oficial (broch20a.inf) via pnputil e configura a impressora.
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
        $portName = "IP_$Ip"
        if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
            Add-PrinterPort -Name $portName -PrinterHostAddress $Ip
        }
        $existing = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($existing) {
            Set-Printer -Name $PrinterName -PortName $portName -DriverName $DriverName
        } else {
            Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $portName
        }
        Write-Host "Impressora '$PrinterName' configurada no IP $Ip." -ForegroundColor Green
    } else {
        # Filas locais reais da HL-L3240CDW (ignora redirecionamentos de Area de Trabalho Remota)
        function Get-LocalQueues {
            Get-Printer -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -like '*HL-L3240CDW*' -and
                $_.DriverName -ne 'Remote Desktop Easy Print' -and
                $_.PortName -notlike 'TS*'
            }
        }

        $queues = @(Get-LocalQueues)
        if (-not $queues) {
            Write-Host 'Conecte o cabo USB da impressora agora. Aguardando o Windows detecta-la (ate 60s)...'
            for ($i = 0; $i -lt 12 -and -not $queues; $i++) {
                Start-Sleep -Seconds 5
                $queues = @(Get-LocalQueues)
            }
        }

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
            Write-Host 'O driver foi instalado, mas a impressora nao foi detectada via USB.' -ForegroundColor Yellow
            Write-Host 'Conecte o cabo USB e o Windows a instalara automaticamente,'
            Write-Host 'ou rode novamente com --ip=<IP> para instalar via rede.'
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
