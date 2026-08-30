# KN MODS • HCR CUSTOM

Instalador automático para HCR Server en Ubuntu/Debian.

## Instalación rápida

Como `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh | bash
```

El instalador **no necesita `--repo`**. El repositorio está incorporado en `setup.sh`.

Durante la instalación pregunta el puerto que quieres usar. Ejemplo:

```text
Puerto para HCR (ejemplo 8880): 8880
```

También puedes elegir `80`, `443`, `8080`, `8880` u otro puerto libre entre `1` y `65535`.

## Instalación no interactiva

Para pasar argumentos, primero descarga el script y después ejecútalo; no uses `bash --transport ...` directamente sobre un pipe:

```bash
curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh -o /tmp/knmods-hcr.sh
bash /tmp/knmods-hcr.sh --transport plain --port 8880 --no-menu
```

## TLS / Auto

```bash
curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh -o /tmp/knmods-hcr.sh
bash /tmp/knmods-hcr.sh --transport auto --port 443 --no-menu
```

`tls` y `auto` necesitan `fullchain.pem` y `privkey.pem`. El script busca primero Let's Encrypt en `/etc/letsencrypt/live/`.

## Actualización

El instalador detiene HCR antes de actualizar el binario y descarga primero a archivos temporales. Luego hace un `mv` atómico para evitar el error:

```text
Text file busy
```

## Administración

```bash
systemctl status hcr-server
systemctl restart hcr-server
journalctl -u hcr-server -f
```

## Requisitos

- Ubuntu/Debian con systemd.
- Acceso root.
- Internet.
- El `hcr-server` incluido en este repositorio es el binario proporcionado para `x86_64`.

## Seguridad

No subas `privkey.pem` ni otros secretos a un repositorio público.

## Repositorio

https://github.com/KANEKIMOD/HCRCUSTOM
