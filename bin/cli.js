#!/usr/bin/env node
/*
 * Instalador da Brother HL-L3240CDW para Windows.
 * Uso:
 *   npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup             (USB)
 *   npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup --ip=<IP>   (rede)
 *   npx github:drpauloguimaraesjr/-brother-hl-l3240cdw-setup --uninstall
 */
'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const os = require('os');

function help() {
  console.log(`
Instalador da impressora Brother HL-L3240CDW (Windows)

Uso:
  brother-hl-l3240cdw-setup               Instala via USB (plug and play)
  brother-hl-l3240cdw-setup --ip=<IP>     Instala via rede (Wi-Fi/cabo), ex.: --ip=192.168.1.50
  brother-hl-l3240cdw-setup --uninstall   Remove a impressora e o driver
  brother-hl-l3240cdw-setup --diagnostico Gera relatorio (USB, rede, drivers) sem instalar nada
  brother-hl-l3240cdw-setup --help        Mostra esta ajuda

Para instalar/remover será solicitada elevação de administrador (UAC).
O diagnóstico não precisa de administrador.
`);
}

if (os.platform() !== 'win32') {
  console.error('Este instalador funciona apenas no Windows.');
  process.exit(1);
}

const args = process.argv.slice(2);
const psArgs = [];
let diagnose = false;

for (const a of args) {
  if (a === '--help' || a === '-h') {
    help();
    process.exit(0);
  } else if (a === '--diagnostico' || a === '--diagnose') {
    diagnose = true;
  } else if (a.startsWith('--ip=')) {
    const ip = a.slice(5).trim();
    if (!/^[0-9]{1,3}(\.[0-9]{1,3}){3}$/.test(ip)) {
      console.error(`IP inválido: ${ip}`);
      process.exit(1);
    }
    psArgs.push('-Ip', ip);
  } else if (a === '--uninstall') {
    psArgs.push('-Uninstall');
  } else {
    console.error(`Opção desconhecida: ${a}`);
    help();
    process.exit(1);
  }
}

const ps1 = path.join(__dirname, '..', 'scripts', diagnose ? 'diagnose.ps1' : 'install.ps1');

if (diagnose) {
  // Diagnóstico não precisa de administrador — roda direto no console atual
  const r = spawnSync('powershell.exe', [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1, ...psArgs
  ], { stdio: 'inherit' });
  process.exit(r.status === null ? 1 : r.status);
}

// Verifica se já estamos com privilégios de administrador
const adminCheck = spawnSync('powershell.exe', [
  '-NoProfile', '-Command',
  '[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)'
], { encoding: 'utf8' });

const isAdmin = (adminCheck.stdout || '').trim() === 'True';

let result;
if (isAdmin) {
  result = spawnSync('powershell.exe', [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1, ...psArgs
  ], { stdio: 'inherit' });
} else {
  console.log('Solicitando permissão de administrador (UAC)...');
  // Abre uma janela elevada; o script pausa no final para o resultado ficar visível
  const inner = `-NoProfile -ExecutionPolicy Bypass -File "${ps1}" -Pause ${psArgs.join(' ')}`.trim();
  const cmd = `$p = Start-Process -FilePath powershell -Verb RunAs -Wait -PassThru -ArgumentList '${inner.replace(/'/g, "''")}'; exit $p.ExitCode`;
  result = spawnSync('powershell.exe', ['-NoProfile', '-Command', cmd], { stdio: 'inherit' });
}

process.exit(result.status === null ? 1 : result.status);
