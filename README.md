# KN MODS • HCR Auto Installer

Instalador automatizado para el **HCR Server** incluido en este repositorio.

## Estructura

```text
.
├── setup.sh       # Bootstrap para instalar desde GitHub
├── install.sh     # Instalador original HCR
└── hcr-server     # Binario HCR
```

### Instalación con un solo comando

Después de subir los archivos a GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/setup.sh | bash -s -- --repo OWNER/REPO
```

Ejemplo:

```bash
curl -fsSL https://raw.githubusercontent.com/knmods/hcr-installer/main/setup.sh | bash -s -- --repo knmods/hcr-installer
```

El script mostrará un menú y permitirá seleccionar:

```text
[1] Instalar / actualizar HCR
[2] Estado del servicio
[3] Reiniciar HCR
[4] Ver logs
[5] Mostrar configuración
[6] Desinstalar HCR
[0] Salir
```

## Instalación directa

Plain:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/setup.sh | bash -s -- --repo OWNER/REPO --transport plain --port 8880 --no-menu
```

TLS:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/setup.sh | bash -s -- --repo OWNER/REPO --transport tls --port 8880 --no-menu
```

Auto:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/setup.sh | bash -s -- --repo OWNER/REPO --transport auto --port 8880 --no-menu
```

## TLS

`tls` y `auto` necesitan:

```text
fullchain.pem
privkey.pem
```

El `setup.sh` busca primero certificados Let's Encrypt en:

```text
/etc/letsencrypt/live/*/
```

Si no los encuentra, los solicita mediante rutas locales.

**Nunca subas `privkey.pem` a un repositorio público.**

## Administración

Tras instalar puedes consultar:

```bash
systemctl status hcr-server
journalctl -u hcr-server -f
systemctl restart hcr-server
```

## Arquitectura

El binario `hcr-server` incluido es el archivo proporcionado para este paquete. Antes de usarlo en otra arquitectura, utiliza un binario HCR compilado para la arquitectura de ese VPS.

El bootstrap detecta la arquitectura y advierte si no es `x86_64`.

## Seguridad

- Ejecuta el instalador únicamente desde un repositorio que controles.
- Revisa los scripts antes de ejecutarlos en un VPS.
- No publiques claves privadas TLS.
- El instalador original crea un servicio systemd como `root`, escucha en el puerto seleccionado y usa `127.0.0.1:22` como destino, según su propia configuración.


## 🔧 Recuperación automática

Si `hcr-server` no permanece activo, `setup.sh` muestra el estado y los logs, verifica el binario, arquitectura y SSH en `127.0.0.1:22` y aplica un perfil de compatibilidad de systemd antes de volver a intentarlo.

La unidad original se conserva como:

```text
/opt/hcr/hcr-server.service.knmods-backup
```

Después de una instalación correcta:

```bash
knmods-hcr
```


## Selección del puerto

Al ejecutar el instalador con menú, el puerto NO está fijado. El instalador pregunta:

```text
Puerto para HCR [ejemplo 8880]:
```

Acepta cualquier puerto TCP válido entre `1` y `65535`, comprueba que el formato sea correcto y pide confirmación antes de instalar.

Ejemplo:

```text
Puerto para HCR [ejemplo 8880]: 8880
Puerto seleccionado: 8880
¿Confirmar instalación en el puerto 8880? [S/n]:
```

En modo no interactivo (`--no-menu`) puedes especificar el puerto explícitamente:

```bash
... setup.sh --repo OWNER/REPO --transport plain --port 8880 --no-menu
```
