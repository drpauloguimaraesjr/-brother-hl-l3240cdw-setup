# Brother HL-L3240CDW — Instalador automático (Windows)

Instala a impressora laser colorida **Brother HL-L3240CDW** no Windows com um único comando, usando o driver oficial da Brother (`broch20a.inf`, x64) incluído neste repositório.

## Instalação

Requisitos: Windows 10/11 x64 e [Node.js](https://nodejs.org) (para o `npx`). O instalador pedirá permissão de administrador (UAC).

### Via USB (plug and play)

```bash
npx github:SEU-USUARIO/brother-hl-l3240cdw-setup
```

Conecte o cabo USB quando o instalador pedir — o Windows detecta e cria a impressora automaticamente.

### Via rede (Wi-Fi ou cabo)

Descubra o IP da impressora (menu da impressora: Rede > WLAN > Endereço IP, ou imprima o relatório de configuração de rede) e rode:

```bash
npx github:SEU-USUARIO/brother-hl-l3240cdw-setup --ip=192.168.1.50
```

> Dica: reserve o IP da impressora no roteador (DHCP reservation) para ele não mudar.

### Desinstalar

```bash
npx github:SEU-USUARIO/brother-hl-l3240cdw-setup --uninstall
```

## O que o instalador faz

1. `pnputil /add-driver driver\broch20a.inf /install` — registra o driver oficial no repositório de drivers do Windows;
2. `Add-PrinterDriver "Brother HL-L3240CDW series"` — registra o driver de impressão;
3. Cria a impressora: via USB (detecção automática do Windows) ou via porta TCP/IP RAW no IP informado.

O driver incluído cobre toda a família: HL-L3215CW, HL-L3220CW/CDW, HL-L3228CDW, **HL-L3240CDW**, HL-L3280CDW, HL-L3288CDW, HL-L3295CDW, HL-L8230CDW e HL-L8240CDW.

## Extras opcionais (não incluídos)

- **Brother iPrint&Scan** (aplicativo de gerenciamento/scan): baixe na [página de suporte da Brother](https://support.brother.com/g/b/downloadtop.aspx?c=br&lang=pt&prod=hll3240cdw_us_eu_as).
- **Firmware**: a mesma página oferece a ferramenta de atualização de firmware.
- **Brother IPPoverUSB Driver**: instalado automaticamente pelo Windows Update na maioria dos casos; necessário apenas para recursos avançados via USB.

## Estrutura

```
bin/cli.js          Ponto de entrada do npx (eleva para administrador)
scripts/install.ps1 Lógica de instalação/remoção em PowerShell
driver/             Pacote oficial do driver Brother (broch20a.inf, x64, ~31 MB)
```

## Licença

Código do instalador sob licença MIT. Os arquivos em `driver/` são propriedade da Brother Industries, Ltd. e estão redistribuídos aqui apenas para conveniência de instalação pessoal.
