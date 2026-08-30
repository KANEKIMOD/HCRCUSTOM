#!/usr/bin/env bash
set -Eeuo pipefail

# KN MODS • HCR AUTO INSTALLER
# Fixed one-command installer for KANEKIMOD/HCRCUSTOM.

REPO="KANEKIMOD/HCRCUSTOM"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
INSTALL_DIR="/opt/hcr"
SERVICE="hcr-server"
TRANSPORT="plain"
PORT=""
NO_MENU="false"

R=$'\033[0m'; B=$'\033[1m'; C=$'\033[96m'; M=$'\033[95m'; V=$'\033[38;5;141m'; P=$'\033[38;5;213m'; G=$'\033[92m'; Y=$'\033[93m'; W=$'\033[97m'; X=$'\033[91m'; D=$'\033[2m'

die(){ printf "\n%b✗%b %s\n" "$X" "$R" "$*" >&2; exit 1; }
info(){ printf "%b[•]%b %s\n" "$C" "$R" "$*"; }
ok(){ printf "%b[✓]%b %s\n" "$G" "$R" "$*"; }
warn(){ printf "%b[!]%b %s\n" "$Y" "$R" "$*"; }
pause(){ read -r -p "ENTER para continuar..." _ || true; }

banner(){
  clear 2>/dev/null || true
  printf '\n'
  printf "%b██╗  ██╗███╗   ██╗    ███╗   ███╗ ██████╗ ██████╗ ███████╗%b\n" "$C$B" "$R"
  printf "%b██║ ██╔╝████╗  ██║    ████╗ ████║██╔═══██╗██╔══██╗██╔════╝%b\n" "$C$B" "$R"
  printf "%b█████╔╝ ██╔██╗ ██║    ██╔████╔██║██║   ██║██║  ██║███████╗%b\n" "$M$B" "$R"
  printf "%b██╔═██╗ ██║╚██╗██║    ██║╚██╔╝██║██║   ██║██║  ██║╚════██║%b\n" "$M$B" "$R"
  printf "%b██║  ██╗██║ ╚████║    ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████║%b\n" "$V$B" "$R"
  printf "%b╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝%b\n" "$C$B" "$R"
  printf '\n%b══════════════════════════════════════════════════════════════%b\n' "$C" "$R"
  printf '%b              H C R   A U T O   I N S T A L L E R%b\n' "$P$B" "$R"
  printf '%b══════════════════════════════════════════════════════════════%b\n\n' "$C" "$R"
}

usage(){ cat <<TXT
Uso:
  curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh | bash

Opciones avanzadas (cuando se descarga primero):
  bash setup.sh --transport plain --port 8880 --no-menu
  bash setup.sh --transport tls --port 443 --no-menu
  bash setup.sh --transport auto --port 443 --no-menu
TXT
}

parse(){
  while (($#)); do
    case "$1" in
      --transport) [[ $# -ge 2 ]] || die "--transport requiere plain, tls o auto"; TRANSPORT="$2"; shift 2;;
      --port) [[ $# -ge 2 ]] || die "--port requiere un número"; PORT="$2"; shift 2;;
      --no-menu) NO_MENU=true; shift;;
      -h|--help) usage; exit 0;;
      --repo|--branch) shift 2;;
      *) die "Opción desconocida: $1";;
    esac
  done
}

validate(){
  [[ $EUID -eq 0 ]] || die "Ejecuta este instalador como root."
  case "$TRANSPORT" in plain|tls|auto) ;; *) die "Transport inválido.";; esac
  if [[ -n "$PORT" ]]; then
    [[ "$PORT" =~ ^[0-9]+$ ]] || die "El puerto debe ser numérico."
    ((10#$PORT>=1 && 10#$PORT<=65535)) || die "El puerto debe estar entre 1 y 65535."
    PORT=$((10#$PORT))
  fi
}

install_deps(){
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y curl ca-certificates openssl procps iproute2 openssh-server
  else
    command -v curl >/dev/null || die "curl no está instalado."
    command -v systemctl >/dev/null || die "systemd no está disponible."
  fi
}

choose_port(){
  if [[ -z "$PORT" ]]; then
    while true; do
      read -r -p "Puerto para HCR (ejemplo 8880): " p
      [[ "$p" =~ ^[0-9]+$ ]] && ((10#$p>=1 && 10#$p<=65535)) || { warn "Puerto inválido. Usa 1-65535."; continue; }
      if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -Eq ":${p}\b"; then
        warn "El puerto $p ya está ocupado."; continue
      fi
      PORT=$((10#$p)); break
    done
  fi
}

stop_hcr(){
  if systemctl cat "$SERVICE" >/dev/null 2>&1; then
    info "Deteniendo HCR antes de actualizar..."
    systemctl stop "$SERVICE" 2>/dev/null || true
    sleep 1
  fi
  if pgrep -x hcr-server >/dev/null 2>&1; then
    pkill -TERM -x hcr-server 2>/dev/null || true
    sleep 1
    pkill -KILL -x hcr-server 2>/dev/null || true
    sleep 1
  fi
}

download_atomic(){
  install -d -o root -g root -m 0700 "$INSTALL_DIR"
  local new_inst="$INSTALL_DIR/.install.sh.new"
  local new_bin="$INSTALL_DIR/.hcr-server.new"
  rm -f "$new_inst" "$new_bin"

  info "Descargando install.sh..."
  curl -fL --retry 4 --connect-timeout 10 --max-time 180 -o "$new_inst" "$RAW_BASE/install.sh" || die "No se pudo descargar install.sh desde GitHub."
  info "Descargando hcr-server..."
  curl -fL --retry 4 --connect-timeout 10 --max-time 180 -o "$new_bin" "$RAW_BASE/hcr-server" || die "No se pudo descargar hcr-server desde GitHub."

  chown root:root "$new_inst" "$new_bin"
  chmod 0755 "$new_inst" "$new_bin"

  # Atomic rename avoids writing directly over a running executable (Text file busy).
  mv -f "$new_inst" "$INSTALL_DIR/install.sh"
  mv -f "$new_bin" "$INSTALL_DIR/hcr-server"

  "$INSTALL_DIR/hcr-server" -version >/dev/null 2>&1 || die "El hcr-server descargado no supera la prueba -version."
  ok "Archivos descargados y validados."
}

setup_tls(){
  local cert='' key='' d=''
  if [[ -d /etc/letsencrypt/live ]]; then
    while IFS= read -r -d '' d; do
      if [[ -f "$d/fullchain.pem" && -f "$d/privkey.pem" ]]; then cert="$d/fullchain.pem"; key="$d/privkey.pem"; break; fi
    done < <(find /etc/letsencrypt/live -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  fi
  if [[ -n "$cert" ]]; then
    ok "Certificados Let's Encrypt detectados."
    cp -f "$cert" "$INSTALL_DIR/fullchain.pem"
    cp -f "$key" "$INSTALL_DIR/privkey.pem"
  else
    warn "No se encontraron certificados Let's Encrypt automáticamente."
    read -r -p "Ruta de fullchain.pem (ENTER = cancelar TLS): " cert
    [[ -n "$cert" ]] || { TRANSPORT=plain; warn "Continuando en plain."; return; }
    read -r -p "Ruta de privkey.pem: " key
    [[ -f "$cert" && -f "$key" ]] || die "No existen ambos archivos TLS."
    cp -f "$cert" "$INSTALL_DIR/fullchain.pem"
    cp -f "$key" "$INSTALL_DIR/privkey.pem"
  fi
  chown root:root "$INSTALL_DIR/fullchain.pem" "$INSTALL_DIR/privkey.pem"
  chmod 0644 "$INSTALL_DIR/fullchain.pem"
  chmod 0600 "$INSTALL_DIR/privkey.pem"
}

install_hcr(){
  choose_port
  if [[ "$TRANSPORT" == tls || "$TRANSPORT" == auto ]]; then setup_tls; fi
  stop_hcr
  download_atomic
  info "Instalando HCR en puerto $PORT..."
  "$INSTALL_DIR/install.sh" --transport "$TRANSPORT" --port "$PORT" || true

  if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
    ok "HCR está ONLINE en el puerto $PORT."
    return 0
  fi

  warn "HCR no quedó activo. Diagnóstico automático:"
  systemctl status "$SERVICE" --no-pager --full 2>/dev/null || true
  journalctl -u "$SERVICE" -n 100 --no-pager 2>/dev/null || true
  echo
  info "Arquitectura: $(uname -m)"
  "$INSTALL_DIR/hcr-server" -version 2>&1 || true
  command -v file >/dev/null 2>&1 && file "$INSTALL_DIR/hcr-server" || true
  echo
  info "Listeners relevantes:"
  ss -ltnp 2>/dev/null | grep -E ':22\b|:'"$PORT"'\b' || true
  die "No fue posible mantener HCR activo."
}

menu(){
  while true; do
    banner
    printf "%b[1]%b Instalar / actualizar HCR\n" "$W$B" "$R"
    printf "%b[2]%b Estado\n" "$W$B" "$R"
    printf "%b[3]%b Reiniciar\n" "$W$B" "$R"
    printf "%b[4]%b Logs\n" "$W$B" "$R"
    printf "%b[5]%b Mostrar puerto\n" "$W$B" "$R"
    printf "%b[0]%b Salir\n\n" "$W$B" "$R"
    read -r -p "> " c || exit 0
    case "$c" in
      1)
        PORT=""; choose_port
        read -r -p "Transporte [plain/tls/auto] (plain): " t; [[ -n "$t" ]] && TRANSPORT="$t"
        validate; install_hcr; pause;;
      2) banner; systemctl status "$SERVICE" --no-pager || true; pause;;
      3) systemctl restart "$SERVICE"; ok "HCR reiniciado."; sleep 1;;
      4) banner; journalctl -u "$SERVICE" -n 100 --no-pager || true; pause;;
      5) banner; echo -e "Puerto configurado: ${G}$(systemctl cat "$SERVICE" 2>/dev/null | grep -oE -- '--listen :[0-9]+' | tail -n1 | sed 's/.*://')${R}"; pause;;
      0) clear; exit 0;;
      *) warn "Opción inválida."; sleep 1;;
    esac
  done
}

main(){
  parse "$@"
  validate
  banner
  install_deps
  if [[ "$NO_MENU" == true ]]; then
    [[ -n "$PORT" ]] || die "Con --no-menu debes indicar --port."
    install_hcr
  else
    choose_port
    printf '\n%bPuerto seleccionado:%b %s\n' "$G" "$R" "$PORT"
    read -r -p "¿Continuar? [S/n]: " a
    [[ -z "$a" || "$a" =~ ^[sSyY]$ ]] || exit 0
    install_hcr
    echo
    ok "Instalación completada."
    menu
  fi
}
main "$@"
