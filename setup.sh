#!/usr/bin/env bash
set -Eeuo pipefail

# KN MODS HCR - GitHub bootstrap installer
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/setup.sh) --repo OWNER/REPO
#
# Optional:
#   --transport plain|tls|auto
#   --port 1-65535
#   --no-menu
#
# The repository must contain:
#   setup.sh
#   install.sh
#   hcr-server
#
# IMPORTANT: never commit private TLS keys to a public GitHub repository.

REPO=""
BRANCH="main"
TRANSPORT="plain"
PORT="8080"
NO_MENU="false"
INSTALL_DIR="/opt/hcr"
SERVICE="hcr-server"
RAW_BASE=""

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_CYAN=$'\033[96m'
C_MAGENTA=$'\033[95m'
C_BLUE=$'\033[94m'
C_PINK=$'\033[38;5;213m'
C_VIOLET=$'\033[38;5;141m'
C_WHITE=$'\033[97m'
C_DIM=$'\033[2m'
C_GREEN=$'\033[92m'
C_RED=$'\033[91m'
C_YELLOW=$'\033[93m'

die(){ printf "\n%bError:%b %s\n" "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
info(){ printf "%b[•]%b %s\n" "$C_CYAN" "$C_RESET" "$*"; }
ok(){ printf "%b[✓]%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn(){ printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$*"; }

banner() {
  clear 2>/dev/null || true
  printf "\n"
  printf "%b%s%b\n" "$C_CYAN$C_BOLD" "██╗  ██╗███╗   ██╗    ███╗   ███╗ ██████╗ ██████╗ ███████╗" "$C_RESET"
  printf "%b%s%b\n" "$C_CYAN$C_BOLD" "██║ ██╔╝████╗  ██║    ████╗ ████║██╔═══██╗██╔══██╗██╔════╝" "$C_RESET"
  printf "%b%s%b\n" "$C_MAGENTA$C_BOLD" "█████╔╝ ██╔██╗ ██║    ██╔████╔██║██║   ██║██║  ██║███████╗" "$C_RESET"
  printf "%b%s%b\n" "$C_MAGENTA$C_BOLD" "██╔═██╗ ██║╚██╗██║    ██║╚██╔╝██║██║   ██║██║  ██║╚════██║" "$C_RESET"
  printf "%b%s%b\n" "$C_VIOLET$C_BOLD" "██║  ██╗██║ ╚████║    ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████║" "$C_RESET"
  printf "%b%s%b\n" "$C_BLUE$C_BOLD" "╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝" "$C_RESET"
  printf "\n%b══════════════════════════════════════════════════════════════%b\n" "$C_CYAN" "$C_RESET"
  printf "%b              H C R   A U T O   I N S T A L L E R%b\n" "$C_PINK$C_BOLD" "$C_RESET"
  printf "%b══════════════════════════════════════════════════════════════%b\n\n" "$C_CYAN" "$C_RESET"
}

usage() {
  cat <<EOF
KN MODS HCR Installer

Usage:
  bash setup.sh --repo OWNER/REPO [options]

Options:
  --repo OWNER/REPO       GitHub repository containing this installer
  --branch NAME           Git branch (default: main)
  --transport MODE        plain, tls or auto (default: plain)
  --port PORT             Listening port (default: 8080)
  --no-menu               Install directly without interactive menu
  -h, --help              Show help
EOF
}

parse() {
  while (($#)); do
    case "$1" in
      --repo) [[ $# -ge 2 ]] || die "--repo requires OWNER/REPO"; REPO="$2"; shift 2;;
      --branch) [[ $# -ge 2 ]] || die "--branch requires a value"; BRANCH="$2"; shift 2;;
      --transport) [[ $# -ge 2 ]] || die "--transport requires plain, tls or auto"; TRANSPORT="$2"; shift 2;;
      --port) [[ $# -ge 2 ]] || die "--port requires a number"; PORT="$2"; shift 2;;
      --no-menu) NO_MENU="true"; shift;;
      -h|--help) usage; exit 0;;
      *) die "Unknown option: $1";;
    esac
  done
}

validate() {
  [[ $EUID -eq 0 ]] || die "Ejecuta el instalador como root."
  [[ "$REPO" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || die "Repositorio inválido. Usa OWNER/REPO."
  [[ "$BRANCH" =~ ^[A-Za-z0-9._/-]+$ ]] || die "Branch inválida."
  case "$TRANSPORT" in plain|tls|auto) ;; *) die "Transport debe ser plain, tls o auto.";; esac
  [[ "$PORT" =~ ^[0-9]+$ ]] || die "El puerto debe ser numérico."
  (( 10#$PORT >= 1 && 10#$PORT <= 65535 )) || die "Puerto fuera de rango."
  PORT=$((10#$PORT))
  RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
}

install_deps() {
  local id=""
  if [[ -r /etc/os-release ]]; then . /etc/os-release; id="${ID:-}"; fi
  case "$id" in
    ubuntu|debian|linuxmint|pop)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get install -y curl ca-certificates openssl coreutils systemd
      ;;
    *)
      command -v curl >/dev/null || die "Esta distribución no tiene curl instalado."
      command -v systemctl >/dev/null || die "systemd es requerido por install.sh."
      ;;
  esac
}

download_file() {
  local name="$1"
  curl -fL --retry 3 --connect-timeout 10 --max-time 120 \
    -o "${INSTALL_DIR}/${name}" "${RAW_BASE}/${name}" ||
    die "No se pudo descargar ${name} desde GitHub."
}

check_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) ok "Arquitectura detectada: x86_64";;
    *)
      warn "Tu VPS reporta arquitectura ${arch}. El hcr-server entregado parece ser x86-64."
      warn "La instalación puede fallar si el binario no coincide con tu arquitectura."
      read -r -p "¿Continuar de todos modos? [s/N] " ans
      [[ "$ans" =~ ^[sS]$ ]] || exit 0
      ;;
  esac
}

download_bundle() {
  install -d -m 0700 "$INSTALL_DIR"
  download_file "install.sh"
  download_file "hcr-server"
  chown root:root "$INSTALL_DIR/install.sh" "$INSTALL_DIR/hcr-server"
  chmod 0755 "$INSTALL_DIR/install.sh" "$INSTALL_DIR/hcr-server"

  info "Comprobando binario..."
  "$INSTALL_DIR/hcr-server" -version >/dev/null 2>&1 ||
    die "El binario descargado no supera la comprobación -version."
  ok "Bundle descargado y validado."
}

find_tls() {
  CERT=""
  KEY=""
  # Search common Let's Encrypt layout.
  if [[ -d /etc/letsencrypt/live ]]; then
    local d
    while IFS= read -r -d '' d; do
      if [[ -f "$d/fullchain.pem" && -f "$d/privkey.pem" ]]; then
        CERT="$d/fullchain.pem"
        KEY="$d/privkey.pem"
        break
      fi
    done < <(find /etc/letsencrypt/live -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  fi
}

setup_tls() {
  find_tls
  if [[ -n "${CERT:-}" && -n "${KEY:-}" ]]; then
    ok "Certificado Let's Encrypt detectado: $CERT"
    install -m 0644 "$CERT" "$INSTALL_DIR/fullchain.pem"
    install -m 0600 "$KEY" "$INSTALL_DIR/privkey.pem"
    return
  fi

  warn "No encontré un par Let's Encrypt automáticamente."
  printf "\n%bTLS necesita:%b\n  fullchain.pem\n  privkey.pem\n\n" "$C_WHITE$C_BOLD" "$C_RESET"
  read -r -p "Ruta de fullchain.pem (Enter para cancelar TLS): " cert
  [[ -n "$cert" ]] || { TRANSPORT="plain"; warn "Continuando en plain."; return; }
  read -r -p "Ruta de privkey.pem: " key
  [[ -f "$cert" && -f "$key" ]] || die "No se encontraron ambos certificados."
  cp -- "$cert" "$INSTALL_DIR/fullchain.pem"
  cp -- "$key" "$INSTALL_DIR/privkey.pem"
  chown root:root "$INSTALL_DIR/fullchain.pem" "$INSTALL_DIR/privkey.pem"
  chmod 0644 "$INSTALL_DIR/fullchain.pem"
  chmod 0600 "$INSTALL_DIR/privkey.pem"
  ok "Certificados copiados de forma segura."
}

install_hcr() {
  if [[ "$TRANSPORT" == "tls" || "$TRANSPORT" == "auto" ]]; then
    setup_tls
  fi

  info "Ejecutando instalador HCR..."
  "$INSTALL_DIR/install.sh" --transport "$TRANSPORT" --port "$PORT"
  ok "HCR Server instalado."
}

install_menu() {
  local menu_choice
  while true; do
    banner
    printf "%b[1]%b Instalar / actualizar HCR\n" "$C_WHITE$C_BOLD" "$C_RESET"
    printf "%b[2]%b Estado del servicio\n" "$C_WHITE$C_BOLD" "$C_RESET"
    printf "%b[3]%b Reiniciar HCR\n" "$C_WHITE$C_BOLD" "$C_RESET"
    printf "%b[4]%b Ver logs\n" "$C_WHITE$C_BOLD" "$C_RESET"
    printf "%b[5]%b Mostrar configuración\n" "$C_WHITE$C_BOLD" "$C_RESET"
    printf "%b[6]%b Desinstalar HCR\n" "$C_WHITE$C_BOLD" "$C_RESET"
    printf "%b[0]%b Salir\n\n" "$C_WHITE$C_BOLD" "$C_RESET"
    read -r -p "  > " menu_choice

    case "$menu_choice" in
      1)
        read -r -p "Puerto [8080]: " p; [[ -n "$p" ]] && PORT="$p"
        read -r -p "Transporte [plain/tls/auto] (plain): " t; [[ -n "$t" ]] && TRANSPORT="$t"
        validate
        check_arch
        download_bundle
        install_hcr
        read -r -p "ENTER para volver al menú..." _
        ;;
      2) banner; systemctl status "$SERVICE" --no-pager || true; read -r -p "ENTER..." _;;
      3) systemctl restart "$SERVICE"; ok "Servicio reiniciado."; sleep 1;;
      4) banner; journalctl -u "$SERVICE" -n 100 --no-pager || true; read -r -p "ENTER..." _;;
      5)
        banner
        systemctl show "$SERVICE" --property=ActiveState,SubState,MainPID,WorkingDirectory,ExecStart 2>/dev/null || true
        ss -ltnp 2>/dev/null | grep -E ":(${PORT}|8080)\b" || true
        read -r -p "ENTER..." _
        ;;
      6)
        banner
        read -r -p "Escribe DESINSTALAR para confirmar: " confirm
        if [[ "$confirm" == "DESINSTALAR" ]]; then
          if [[ -x "$INSTALL_DIR/install.sh" ]]; then
            "$INSTALL_DIR/install.sh" --uninstall || true
          else
            systemctl disable --now "$SERVICE" 2>/dev/null || true
          fi
          rm -f /usr/local/bin/knmods-hcr
          ok "Servicio desinstalado. Los archivos de /opt/hcr se conservaron."
          exit 0
        fi
        ;;
      0) clear 2>/dev/null || true; exit 0;;
      *) warn "Opción no válida."; sleep 1;;
    esac
  done
}

main() {
  parse "$@"
  validate
  banner

  if [[ "$NO_MENU" != "true" && -t 0 ]]; then
    install_menu
  else
    check_arch
    download_bundle
    install_hcr
  fi
}

main "$@"
