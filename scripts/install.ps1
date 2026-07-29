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
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: pnputil retornou codigo $LASTEXITCODE" -ForegroundColor Red
        Done $LASTEXITCODE
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
        $found = Get-Printer -Name "*HL-L3240CDW*" -ErrorAction SilentlyContinue
        if ($found) {
            Write-Host "Impressora ja presente: $($found.Name) (porta $($found.PortName))." -ForegroundColor Green
        } else {
            Write-Host 'Conecte o cabo USB da impressora agora. Aguardando o Windows detecta-la (ate 60s)...'
            $found = $null
            for ($i = 0; $i -lt 12 -and -not $found; $i++) {
                Start-Sleep -Seconds 5
                $found = Get-Printer -Name "*HL-L3240CDW*" -ErrorAction SilentlyContinue
            }
            if ($found) {
                Write-Host "Impressora detectada e instalada: $($found.Name)." -ForegroundColor Green
            } else {
                Write-Host 'O driver foi instalado, mas a impressora nao foi detectada via USB.' -ForegroundColor Yellow
                Write-Host 'Conecte o cabo USB e o Windows a instalara automaticamente,'
                Write-Host 'ou rode novamente com --ip=<IP> para instalar via rede.'
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
