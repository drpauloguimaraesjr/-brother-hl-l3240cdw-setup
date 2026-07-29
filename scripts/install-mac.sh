#!/usr/bin/env bash
# Instalador da Brother HL-L3240CDW para macOS.
# A impressora suporta AirPrint/IPP Everywhere: nao precisa de driver da Brother.
# O script localiza a impressora na rede (Bonjour) e registra a fila no CUPS.
set -euo pipefail

PRINTER_ID="Brother_HL_L3240CDW"
PRINTER_DESC="Brother HL-L3240CDW series"

IP=""
UNINSTALL=0
DIAG=0
for arg in "$@"; do
  case "$arg" in
    --ip=*) IP="${arg#--ip=}" ;;
    --uninstall) UNINSTALL=1 ;;
    --diagnostico|--diagnose) DIAG=1 ;;
    --help|-h)
      echo "Uso: [--ip=<IP>] [--uninstall] [--diagnostico]"
      exit 0 ;;
    *) echo "Opcao desconhecida: $arg"; exit 1 ;;
  esac
done

descobrir_uri() {
  # Procura impressoras IPP anunciadas via Bonjour; Brother usa hostnames BRWxxxx
  ippfind --timeout 8 2>/dev/null | grep -i -m1 -E 'brother|brw[0-9a-f]|hl-?l?3240' || true
}

if [ "$DIAG" -eq 1 ]; then
  echo "===== DIAGNOSTICO - Brother HL-L3240CDW (macOS) ====="
  echo "Computador: $(scutil --get ComputerName 2>/dev/null || hostname) | macOS $(sw_vers -productVersion 2>/dev/null)"
  echo ""
  echo "== Filas de impressao instaladas =="
  lpstat -v 2>/dev/null || echo " - Nenhuma impressora instalada."
  echo ""
  echo "== Impressoras IPP/AirPrint na rede (Bonjour) =="
  FOUND=$(ippfind --timeout 8 2>/dev/null || true)
  if [ -n "$FOUND" ]; then echo "$FOUND"; else echo " - Nenhuma impressora IPP encontrada na rede."; fi
  echo ""
  echo "== Dispositivos USB Brother =="
  USB=$(system_profiler SPUSBDataType 2>/dev/null | grep -i -B2 -A6 'brother' || true)
  if [ -n "$USB" ]; then echo "$USB"; else echo " - Nenhum dispositivo Brother no USB."; fi
  if [ -n "$IP" ]; then
    echo ""
    echo "== Teste do IP $IP =="
    if ping -c 2 -t 3 "$IP" >/dev/null 2>&1; then echo " Ping: OK"; else echo " Ping: SEM RESPOSTA"; fi
    for porta in 631 9100 80; do
      if nc -z -G 2 "$IP" "$porta" >/dev/null 2>&1; then echo " Porta $porta: ABERTA"; else echo " Porta $porta: fechada"; fi
    done
  fi
  echo ""
  echo "===== FIM DO DIAGNOSTICO (copie tudo acima e cole no chat) ====="
  exit 0
fi

if [ "$UNINSTALL" -eq 1 ]; then
  echo "== Removendo a impressora (sera pedida a senha do Mac) =="
  sudo lpadmin -x "$PRINTER_ID" 2>/dev/null || echo "Fila $PRINTER_ID nao existia."
  echo "Remocao concluida."
  exit 0
fi

echo "== Instalando a Brother HL-L3240CDW via AirPrint/IPP =="

if [ -n "$IP" ]; then
  URI="ipp://$IP/ipp/print"
  echo "Usando o IP informado: $IP"
else
  echo "Procurando a impressora na rede (Bonjour, ate 8s)..."
  URI=$(descobrir_uri)
  if [ -z "$URI" ]; then
    echo ""
    echo "Impressora nao encontrada na rede."
    echo " - Confira se ela esta ligada e conectada ao Wi-Fi (painel: Menu > Rede > WLAN);"
    echo " - Ou rode novamente informando o IP: --ip=192.168.x.x"
    echo " - Se ela estiver no cabo USB: abra Ajustes do Sistema > Impressoras e Scanners"
    echo "   e clique em Adicionar - o macOS a instala sozinho via AirPrint."
    exit 1
  fi
  echo "Encontrada: $URI"
fi

echo "Registrando a fila no CUPS (sera pedida a senha do Mac)..."
sudo lpadmin -p "$PRINTER_ID" -D "$PRINTER_DESC" -E -v "$URI" -m everywhere -o printer-is-shared=false

echo ""
echo "Concluido! Impressora instalada como '$PRINTER_DESC'."
echo "Teste com: lpstat -p $PRINTER_ID   (ou imprima qualquer documento)"
