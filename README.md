# Brother HL-L3240CDW — Instalador automático (Windows)

Instala a impressora laser colorida **Brother HL-L3240CDW** no Windows com um único comando, usando o driver oficial da Brother (`broch20a.inf`, x64) incluído neste repositório.

## Instalação

Requisitos: Windows 10/11 x64 e [Node.js](https://nodejs.org) (para o `npx`). O instalador pedirá permissão de administrador (UAC).

### Não tem Node.js? Instale primeiro

O Windows 10/11 já traz o `winget`. Em um PowerShell ou Prompt de Comando, rode:

```bash
winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
```

Depois **feche e abra o terminal novamente** (para o `npx` entrar no PATH) e siga para o comando de instalação abaixo.

### Via USB (plug and play)

```bash
npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup
```

Conecte o cabo USB quando o instalador pedir — o Windows detecta e cria a impressora automaticamente.

### Via rede (Wi-Fi ou cabo)

Descubra o IP da impressora (menu da impressora: Rede > WLAN > Endereço IP, ou imprima o relatório de configuração de rede) e rode:

```bash
npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup --ip=192.168.1.50
```

> Dica: reserve o IP da impressora no roteador (DHCP reservation) para ele não mudar.

### Desinstalar

```bash
npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup --uninstall
```

### Diagnóstico (não instala nada)

Gera um relatório do computador: impressoras e drivers Brother presentes, detecção USB e varredura da rede local procurando a impressora (porta 9100). Não precisa de administrador.

```bash
npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup --diagnostico
```

Se encontrar uma Brother na rede, o relatório já indica o comando `--ip=...` pronto para usar. Também dá para testar um IP específico: `--diagnostico --ip=192.168.1.50`.

## Impressora para toda a rede (recomendado)

A HL-L3240CDW tem Wi-Fi próprio — ela não precisa ficar "presa" a um computador. Configure uma única vez e **qualquer** computador da rede instala com um comando, sem nenhum PC intermediário ligado.

**Passo 1 — Conectar a impressora ao Wi-Fi (uma única vez, no painel dela):**

1. No painel da impressora: **Menu → Rede → WLAN (Wi-Fi) → Localizar Rede Wi-Fi** (Assistente de Configuração);
2. Escolha a sua rede e digite a senha do Wi-Fi;
3. Ao final, imprima o relatório de configuração de rede (**Menu → Impr.relat → Config de rede**) para ver o IP que ela recebeu.

**Passo 2 — (opcional, mas recomendado) Fixar o IP no roteador:** acesse o painel do roteador e crie uma reserva de DHCP para o MAC da impressora, para o IP nunca mudar.

**Passo 3 — Em cada computador da rede, rode:**

```bash
npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup
```

O instalador procura a Brother na rede automaticamente (varredura na porta 9100 + confirmação pelo painel web) e configura tudo sozinho. Se preferir apontar direto, use `--ip=<IP do relatório>`.

## O que o instalador faz

1. `pnputil /add-driver driver\broch20a.inf /install` — registra o driver oficial no repositório de drivers do Windows;
2. `Add-PrinterDriver "Brother HL-L3240CDW series"` — registra o driver de impressão;
3. Configura a impressora, nesta ordem de detecção: IP informado com `--ip` → fila USB já existente (trocando o driver genérico da Microsoft pelo oficial, se preciso) → busca automática na rede local → espera de 60s pela conexão USB.

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
