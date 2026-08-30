#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${KNMODS_REPO:-KANEKIMOD/HCRCUSTOM}"
BRANCH="${KNMODS_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
DIR=/opt/hcr
UNIT="$DIR/hcr-server.service"
SERVICE=hcr-server

C='\033[96m'; M='\033[95m'; V='\033[38;5;141m'; B='\033[94m'; P='\033[38;5;213m'; G='\033[92m'; W='\033[97m'; Y='\033[93m'; R='\033[0m'

banner(){ clear 2>/dev/null || true; printf "\n%b██╗  ██╗███╗   ██╗    ███╗   ███╗ ██████╗ ██████╗ ███████╗%b\n" "$C" "$R"; printf "%b██║ ██╔╝████╗  ██║    ████╗ ████║██╔═══██╗██╔══██╗██╔════╝%b\n" "$C" "$R"; printf "%b█████╔╝ ██╔██╗ ██║    ██╔████╔██║██║   ██║██║  ██║███████╗%b\n" "$M" "$R"; printf "%b██╔═██╗ ██║╚██╗██║    ██║╚██╔╝██║██║   ██║██║  ██║╚════██║%b\n" "$M" "$R"; printf "%b██║  ██╗██║ ╚████║    ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████║%b\n" "$V" "$R"; printf "%b╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝%b\n" "$B" "$R"; printf "\n%b══════════════════════════════════════════════════════════════%b\n" "$C" "$R"; printf "%b              H C R   A U T O   I N S T A L L%b\n" "$P" "$R"; printf "%b══════════════════════════════════════════════════════════════%b\n\n" "$C" "$R"; }

need_root(){ [[ $EUID -eq 0 ]] || { echo 'Ejecuta como root.'; exit 1; }; }
port_free(){ ! ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])$1$"; }
ask_port(){ while :; do read -r -p $'Puerto HCR [8880]: ' PORT; PORT=${PORT:-8880}; [[ $PORT =~ ^[0-9]+$ ]] && ((10#$PORT>=1 && 10#$PORT<=65535)) || { echo -e "${Y}Puerto inválido.${R}"; continue; }; port_free "$PORT" && break; echo -e "${Y}El puerto $PORT ya está ocupado. Elige otro.${R}"; done; }
ask_transport(){ echo; echo 'Transporte:'; echo '  1) plain'; echo '  2) tls'; echo '  3) auto'; read -r -p 'Opción [1]: ' x; case ${x:-1} in 1) TRANSPORT=plain;;2) TRANSPORT=tls;;3) TRANSPORT=auto;;*) TRANSPORT=plain;;esac; }
ask_advanced(){
  echo; echo 'Configuración HCR (solo opciones realmente soportadas por el binario):';
  read -r -p 'Máx. conexiones globales [2048]: ' MAXC; MAXC=${MAXC:-2048};
  read -r -p 'Máx. sesiones globales [32]: ' MAXS; MAXS=${MAXS:-32};
  read -r -p 'Máx. sesiones por IP [16]: ' MAXIP; MAXIP=${MAXIP:-16};
  read -r -p 'Máx. bytes por frame de descarga [6144]: ' FRAME; FRAME=${FRAME:-6144};
  read -r -p 'Espera de descarga [8s]: ' POLL; POLL=${POLL:-8s};
  read -r -p 'Intervalo estadísticas por sesión [0=off]: ' STATS; STATS=${STATS:-0};
  [[ $MAXC =~ ^[0-9]+$ && $MAXS =~ ^[0-9]+$ && $MAXIP =~ ^[0-9]+$ && $FRAME =~ ^[0-9]+$ ]] || { echo 'Valor inválido.'; exit 1; }
}

install_deps(){ export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y -qq curl ca-certificates openssh-server iproute2 openssl >/dev/null; }
stop_hcr(){ systemctl stop "$SERVICE" >/dev/null 2>&1 || true; pkill -TERM -x hcr-server >/dev/null 2>&1 || true; sleep 2; }
download(){
  mkdir -p "$DIR"; chmod 700 "$DIR"; stop_hcr;
  local ti tb; ti=$(mktemp "$DIR/.install.XXXXXX"); tb=$(mktemp "$DIR/.bin.XXXXXX");
  curl -fsSL --retry 3 -o "$ti" "$RAW/install.sh"; curl -fsSL --retry 3 -o "$tb" "$RAW/hcr-server";
  chmod 755 "$ti" "$tb"; "$tb" -version >/dev/null 2>&1 || { rm -f "$ti" "$tb"; echo 'Binario inválido.'; exit 1; }
  mv -f "$ti" "$DIR/install.sh"; mv -f "$tb" "$DIR/hcr-server"; chown root:root "$DIR/install.sh" "$DIR/hcr-server";
}

install_hcr(){
  stop_hcr;
  # Use the original installer for secure unit generation. First install, then tune flags in the generated unit.
  "$DIR/install.sh" --transport "$TRANSPORT" --port "$PORT" || true;
  [[ -f "$UNIT" ]] || { echo 'No se generó el servicio HCR.'; exit 1; }
  cp -a "$UNIT" "$UNIT.knmods-backup";
  # The original service already contains max-download-frame/download-poll-timeout. Replace/add supported tuning flags.
  sed -i -E "s#--max-download-frame[[:space:]]+[0-9]+#--max-download-frame ${FRAME}#" "$UNIT";
  sed -i -E "s#--download-poll-timeout[[:space:]]+[^[:space:]]+#--download-poll-timeout ${POLL}#" "$UNIT";
  if grep -q -- '--max-connections' "$UNIT"; then sed -i -E "s#--max-connections[[:space:]]+[0-9]+#--max-connections ${MAXC}#" "$UNIT"; else sed -i -E "s#(--target[[:space:]]+[^[:space:]]+)#\1 --max-connections ${MAXC}#" "$UNIT"; fi
  if grep -q -- '--max-sessions' "$UNIT"; then sed -i -E "s#--max-sessions[[:space:]]+[0-9]+#--max-sessions ${MAXS}#" "$UNIT"; else sed -i -E "s#(--target[[:space:]]+[^[:space:]]+)#\1 --max-sessions ${MAXS}#" "$UNIT"; fi
  if grep -q -- '--max-sessions-per-ip' "$UNIT"; then sed -i -E "s#--max-sessions-per-ip[[:space:]]+[0-9]+#--max-sessions-per-ip ${MAXIP}#" "$UNIT"; else sed -i -E "s#(--target[[:space:]]+[^[:space:]]+)#\1 --max-sessions-per-ip ${MAXIP}#" "$UNIT"; fi
  if [[ "$STATS" != 0 && "$STATS" != off ]]; then
    if grep -q -- '--session-stats-interval' "$UNIT"; then sed -i -E "s#--session-stats-interval[[:space:]]+[^[:space:]]+#--session-stats-interval ${STATS}#" "$UNIT"; else sed -i -E "s#(--target[[:space:]]+[^[:space:]]+)#\1 --session-stats-interval ${STATS}#" "$UNIT"; fi
  fi
  systemd-analyze verify "$UNIT"; systemctl daemon-reload; systemctl enable "$SERVICE" >/dev/null; systemctl restart "$SERVICE";
  sleep 2; systemctl is-active --quiet "$SERVICE" || { echo; echo 'HCR no quedó activo. Últimos logs:'; journalctl -u "$SERVICE" -n 50 --no-pager; exit 1; }
  ufw allow "$PORT/tcp" >/dev/null 2>&1 || true;
}

main(){ need_root; banner; install_deps; ask_port; ask_transport; ask_advanced; banner; echo -e "${C}Puerto:${R} $PORT"; echo -e "${C}Transporte:${R} $TRANSPORT"; echo; echo 'Instalando...'; sleep 1; download; install_hcr; echo; echo -e "${G}✓ HCR instalado y activo${R}"; echo -e "${W}Puerto: ${C}$PORT${R}"; echo; echo -e "${P}Panel de administración:${R} /usr/local/bin/knmods"; install_admin; }

install_admin(){
  cat > /usr/local/bin/knmods <<'ADMIN'
#!/usr/bin/env bash
set -Eeuo pipefail
UNIT=/opt/hcr/hcr-server.service; SERVICE=hcr-server; DB=/etc/knmods/users.db; BANNER=/etc/knmods/banner.txt; BK=/etc/knmods/backups
R=$'\033[0m'; C=$'\033[96m'; M=$'\033[95m'; G=$'\033[92m'; P=$'\033[38;5;213m'; W=$'\033[97m'; Y=$'\033[93m'
mkdir -p /etc/knmods "$BK"; chmod 700 /etc/knmods; touch "$DB"; chmod 600 "$DB"
header(){ clear; echo -e "${C}${B:=\033[1m}██╗  ██╗███╗   ██╗    ███╗   ███╗ ██████╗ ██████╗ ███████╗${R}"; echo -e "${C}██║ ██╔╝████╗  ██║    ████╗ ████║██╔═══██╗██╔══██╗██╔════╝${R}"; echo -e "${M}█████╔╝ ██╔██╗ ██║    ██╔████╔██║██║   ██║██║  ██║███████╗${R}"; echo -e "${M}██╔═██╗ ██║╚██╗██║    ██║╚██╔╝██║██║   ██║██║  ██║╚════██║${R}"; echo -e "${P}██║  ██╗██║ ╚████║    ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████║${R}"; echo -e "${P}╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝${R}"; echo; echo -e "${C}══════════════════════════════════════════════════════════${R}"; echo -e "${W}                 HCR ADMIN PANEL${R}"; echo -e "${C}══════════════════════════════════════════════════════════${R}\n"; }
port(){ grep -oE -- '--listen[[:space:]]+:[0-9]+' "$UNIT" 2>/dev/null | tail -n1 | sed -E 's/.*://' || echo '?'; }
pause(){ read -r -p 'ENTER...' _; }
create(){ header; read -r -p 'Usuario: ' u; [[ $u =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return; id "$u" >/dev/null 2>&1 && { echo 'Ya existe.'; pause; return; }; read -r -s -p 'Contraseña: ' p; echo; read -r -p 'Días [30]: ' d; d=${d:-30}; useradd -m -s /bin/bash "$u"; echo "$u:$p"|chpasswd; chage -E "$(date -d "+$d days" +%F)" "$u"; printf '%s|%s\n' "$u" "$(date -d "+$d days" +%s)" >> "$DB"; echo -e "${G}✓ Creado${R}"; pause; }
list(){ header; printf '%-20s %-20s %-10s\n' USUARIO EXPIRA ESTADO; while IFS='|' read -r u e; do [[ -z ${u:-} ]] && continue; id "$u" >/dev/null 2>&1 || continue; s=ACTIVO; (( ${e:-0} <= $(date +%s) )) && s=EXPIRADO; printf '%-20s %-20s %-10s\n' "$u" "$(date -d @${e:-0} +%Y-%m-%d 2>/dev/null || echo '?')" "$s"; done < "$DB"; pause; }
renew(){ header; read -r -p 'Usuario: ' u; id "$u" >/dev/null 2>&1 || return; read -r -p 'Días [30]: ' d; d=${d:-30}; chage -E "$(date -d "+$d days" +%F)" "$u"; echo -e "${G}✓ Renovado${R}"; pause; }
remove(){ header; read -r -p 'Usuario: ' u; id "$u" >/dev/null 2>&1 || return; read -r -p 'Escribe ELIMINAR: ' x; [[ $x == ELIMINAR ]] || return; pkill -TERM -u "$u" 2>/dev/null || true; userdel -r "$u" 2>/dev/null || userdel "$u" 2>/dev/null || true; sed -i -E "/^${u}\|/d" "$DB"; echo -e "${G}✓ Eliminado${R}"; pause; }
portmenu(){ header; echo "Puerto actual: $(port)"; read -r -p 'Nuevo puerto: ' p; [[ $p =~ ^[0-9]+$ ]] && ((10#$p>=1&&10#$p<=65535)) || return; ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])$p$" && { echo 'Puerto ocupado.'; pause; return; }; cp -a "$UNIT" "$BK/$(date +%Y%m%d-%H%M%S).service"; sed -i -E "s#--listen[[:space:]]+:[0-9]+#--listen :$p#" "$UNIT"; systemd-analyze verify "$UNIT"; systemctl daemon-reload; systemctl restart "$SERVICE"; sleep 2; systemctl is-active --quiet "$SERVICE" && echo -e "${G}✓ Puerto cambiado a $p${R}" || { cp -a "$(ls -1t "$BK"/*.service|head -n1)" "$UNIT"; systemctl daemon-reload; systemctl restart "$SERVICE"; }; pause; }
settings(){ header; echo "Flags HCR actuales:"; grep -oE -- '--(listen|transport|max-connections|max-sessions|max-sessions-per-ip|max-download-frame|download-poll-timeout|session-stats-interval)([[:space:]]+[^ ]+)?' "$UNIT" 2>/dev/null || true; echo; echo '[1] Cambiar límites/frame/timeout'; echo '[0] Volver'; read -r -p '> ' x; [[ $x == 1 ]] || return; read -r -p 'max-connections [2048]: ' a; a=${a:-2048}; read -r -p 'max-sessions [32]: ' b; b=${b:-32}; read -r -p 'max-sessions-per-ip [16]: ' c; c=${c:-16}; read -r -p 'max-download-frame [6144]: ' d; d=${d:-6144}; read -r -p 'download-poll-timeout [8s]: ' e; e=${e:-8s}; cp -a "$UNIT" "$BK/$(date +%Y%m%d-%H%M%S).service"; sed -i -E "s#--max-connections[[:space:]]+[0-9]+#--max-connections $a#; s#--max-sessions[[:space:]]+[0-9]+#--max-sessions $b#; s#--max-sessions-per-ip[[:space:]]+[0-9]+#--max-sessions-per-ip $c#; s#--max-download-frame[[:space:]]+[0-9]+#--max-download-frame $d#; s#--download-poll-timeout[[:space:]]+[^ ]+#--download-poll-timeout $e#" "$UNIT"; systemd-analyze verify "$UNIT"; systemctl daemon-reload; systemctl restart "$SERVICE"; pause; }
banner_menu(){ header; echo '[1] Ver banner'; echo '[2] Editar banner'; read -r -p '> ' x; case $x in 1) cat "$BANNER" 2>/dev/null || echo '(sin banner)'; pause;; 2) mkdir -p /etc/knmods; nano "$BANNER"; grep -qE '^[[:space:]]*Banner[[:space:]]+' /etc/ssh/sshd_config && sed -i -E "s#^[[:space:]]*Banner[[:space:]].*#Banner $BANNER#" /etc/ssh/sshd_config || echo "Banner $BANNER" >> /etc/ssh/sshd_config; sshd -t && (systemctl restart ssh 2>/dev/null || systemctl restart sshd);; esac; }
main(){ while true; do header; echo -e "${G}●${R} HCR: $(systemctl is-active "$SERVICE" 2>/dev/null || echo offline)   Puerto: $(port)"; echo; echo '[1] Crear usuario'; echo '[2] Usuarios/expiración'; echo '[3] Renovar usuario'; echo '[4] Eliminar usuario'; echo '[5] Online'; echo '[6] Desconectar usuario'; echo '[7] Cambiar puerto'; echo '[8] Banner'; echo '[9] Configuración HCR'; echo '[10] Estado/logs'; echo '[0] Salir'; read -r -p '> ' x; case $x in 1)create;;2)list;;3)renew;;4)remove;;5)header; who 2>/dev/null || true; ss -tnp 2>/dev/null|grep -E 'sshd|hcr-server'|head -50; pause;;6)header; read -r -p 'Usuario: ' u; pkill -TERM -u "$u" 2>/dev/null||true; pause;;7)portmenu;;8)banner_menu;;9)settings;;10)header; systemctl status "$SERVICE" --no-pager; echo; journalctl -u "$SERVICE" -n 40 --no-pager; pause;;0)exit;;esac; done; }
main
ADMIN
  chmod 0755 /usr/local/bin/knmods
}

main "$@"
