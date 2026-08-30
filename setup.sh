#!/usr/bin/env bash
set -Eeuo pipefail
REPO="KANEKIMOD/HCRCUSTOM"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
DIR="/opt/hcr"
SERVICE="hcr-server"
PORT=""
R=$'\033[0m'; C=$'\033[96m'; M=$'\033[95m'; V=$'\033[38;5;141m'; B=$'\033[1m'; G=$'\033[92m'; Y=$'\033[93m'; RED=$'\033[91m'; W=$'\033[97m'
trap 'printf "%b\n" "$R"' EXIT

banner(){
  clear 2>/dev/null || true
  printf "\n%b██╗  ██╗███╗   ██╗    ███╗   ███╗ ██████╗ ██████╗ ███████╗%b\n" "$C$B" "$R"
  printf "%b██║ ██╔╝████╗  ██║    ████╗ ████║██╔═══██╗██╔══██╗██╔════╝%b\n" "$C$B" "$R"
  printf "%b█████╔╝ ██╔██╗ ██║    ██╔████╔██║██║   ██║██║  ██║███████╗%b\n" "$M$B" "$R"
  printf "%b██╔═██╗ ██║╚██╗██║    ██║╚██╔╝██║██║   ██║██║  ██║╚════██║%b\n" "$M$B" "$R"
  printf "%b██║  ██╗██║ ╚████║    ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████║%b\n" "$V$B" "$R"
  printf "%b╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝%b\n" "$V$B" "$R"
  printf "\n%b══════════════════════════════════════════════════════════════%b\n" "$C" "$R"
  printf "%b              K N   M O D S  •  H C R%b\n" "$W$B" "$R"
  printf "%b══════════════════════════════════════════════════════════════%b\n\n" "$C" "$R"
}
progress(){ local s="$1"; printf "%b[•]%b %s " "$C" "$R" "$s"; for _ in $(seq 1 24); do printf '█'; sleep 0.02; done; printf ' %bOK%b\n' "$G" "$R"; }
need_root(){ [[ $EUID -eq 0 ]] || { echo -e "${RED}Ejecuta como root.${R}"; exit 1; }; }
install_deps(){
  export DEBIAN_FRONTEND=noninteractive
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y -qq curl ca-certificates openssh-server systemd iproute2 >/dev/null 2>&1 || true
  fi
  command -v curl >/dev/null 2>&1 || { echo -e "${RED}curl no está disponible.${R}"; exit 1; }
  command -v systemctl >/dev/null 2>&1 || { echo -e "${RED}systemd no está disponible.${R}"; exit 1; }
  command -v ss >/dev/null 2>&1 || { echo -e "${RED}ss no está disponible.${R}"; exit 1; }
}
is_free(){ ! ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${1}$"; }
choose_port(){
  while true; do
    printf "%bPuerto para HCR [8880]: %b" "$W$B" "$R"
    read -r PORT
    PORT="${PORT:-8880}"
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || ((10#$PORT < 1 || 10#$PORT > 65535)); then
      echo -e "${RED}Puerto inválido.${R}"; continue
    fi
    if ! is_free "$PORT"; then
      echo -e "${RED}El puerto $PORT ya está ocupado. Elige otro.${R}"; continue
    fi
    break
  done
}
stop_hcr(){ systemctl stop "$SERVICE" >/dev/null 2>&1 || true; pkill -TERM -x hcr-server >/dev/null 2>&1 || true; sleep 2; }
download(){
  install -d -m 0700 "$DIR"
  local a b
  a="$(mktemp "$DIR/.install.sh.XXXXXX")"
  b="$(mktemp "$DIR/.hcr-server.XXXXXX")"
  curl -fsSL --retry 3 --connect-timeout 10 -o "$a" "$BASE/install.sh"
  curl -fsSL --retry 3 --connect-timeout 10 -o "$b" "$BASE/hcr-server"
  chmod 755 "$a" "$b"
  "$b" -version >/dev/null 2>&1 || { rm -f "$a" "$b"; echo -e "${RED}hcr-server inválido.${R}"; exit 1; }
  mv -f "$a" "$DIR/install.sh"
  mv -f "$b" "$DIR/hcr-server"
  chown root:root "$DIR/install.sh" "$DIR/hcr-server"
}
main(){
  need_root
  banner
  install_deps
  progress "Preparando VPS"
  choose_port
  progress "Deteniendo HCR anterior"
  stop_hcr
  progress "Descargando HCR"
  download
  progress "Instalando servicio"
  if ! "$DIR/install.sh" --transport plain --port "$PORT" >/tmp/knmods-hcr-install.log 2>&1; then
    cat /tmp/knmods-hcr-install.log
    exit 1
  fi
  systemctl is-active --quiet "$SERVICE" || { cat /tmp/knmods-hcr-install.log; echo -e "${RED}HCR no quedó activo.${R}"; exit 1; }
  command -v ufw >/dev/null 2>&1 && ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
  banner
  echo -e "${G}${B}✓ HCR INSTALADO CORRECTAMENTE${R}\n"
  echo -e "Puerto: ${C}${B}${PORT}${R}"
  echo -e "Estado: ${G}ONLINE${R}"
  echo
  echo -e "${W}Comando de administración del servidor:${R}"
  echo "systemctl status hcr-server"
}
main "$@"
