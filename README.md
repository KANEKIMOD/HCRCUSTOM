# KN MODS • HCR CUSTOM

Instalador automático para HCR Server.

## Instalación

Como `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh -o setup.sh
chmod +x setup.sh
bash -x setup.sh
```

El instalador muestra el banner y solo pregunta el puerto:

```text
Puerto para HCR [8880]:
```

Pulsa ENTER para usar `8880` o escribe otro puerto libre entre `1` y `65535`.

Si el puerto está ocupado, pedirá otro automáticamente.

Después continúa solo con la instalación en modo `plain`.

## Comandos útiles

```bash
systemctl status hcr-server
systemctl restart hcr-server
journalctl -u hcr-server -f
```

Repositorio:

https://github.com/KANEKIMOD/HCRCUSTOM
