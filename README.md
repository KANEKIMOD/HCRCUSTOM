# KN MODS • HCR CUSTOM

Instalador de un solo comando para el HCR Server incluido en este repositorio.

## Instalación

```bash
curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh | bash
```

El instalador muestra el banner KN MODS y te deja elegir:

- Puerto HCR (1–65535). Si está ocupado, pide otro.
- Transporte: `plain`, `tls` o `auto`.
- Máximo de conexiones globales.
- Máximo de sesiones globales.
- Máximo de sesiones por IP.
- Máximo de bytes por frame de descarga.
- Tiempo de espera de una conexión de descarga.
- Intervalo opcional de estadísticas por sesión.

## Parámetros reales del binario

El `hcr-server` entregado soporta estos flags:

```text
-listen
-target
-transport
-tls-cert
-tls-key
-max-connections
-max-sessions
-max-sessions-per-ip
-max-download-frame
-download-poll-timeout
-session-stats-interval
-version
```

No se inventan parámetros `upload.chunk_size`, `upload.connections` ni `download.chunk_size`: esos campos no están expuestos por este binario.

## Administración

Después de instalar:

```bash
knmods
```

El panel permite crear/renovar/eliminar usuarios SSH, ver sesiones, desconectar usuarios, cambiar el puerto, editar el banner SSH, cambiar los límites HCR soportados y consultar estado/logs.

## Actualización

El instalador detiene el servicio y descarga el binario a un archivo temporal antes de reemplazar `/opt/hcr/hcr-server`. Esto evita el error `Text file busy`.

## Seguridad

No publiques `privkey.pem` ni credenciales en un repositorio público.
