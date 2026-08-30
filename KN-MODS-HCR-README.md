# KN MODS • HCR CUSTOM

Instalador automático para HCR Server en VPS Ubuntu/Debian con menú interactivo.

## Características

- Instalación automática de HCR Server.
- Selección de puerto personalizada durante la instalación.
- Soporte para modo Plain, TLS y Auto.
- Verificación automática de dependencias.
- Diagnóstico básico del servicio.
- Reinicio rápido del servidor.
- Visualización de estado y logs.
- Menú KN MODS personalizado.

## Instalación rápida

Ejecuta como **root**:

```bash
curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh | bash
```

## Instalación manual

```bash
git clone https://github.com/KANEKIMOD/HCRCUSTOM.git
cd HCRCUSTOM
chmod +x setup.sh
./setup.sh
```

## Selección del puerto

Durante la instalación se solicitará el puerto para HCR.

Ejemplos:

```text
80
443
8080
8880
2095
9000
```

Puedes elegir cualquier puerto libre entre `1` y `65535`.

## Menú principal

```text
KN MODS • HCR AUTO INSTALLER

[1] Instalar HCR
[2] Estado del servicio
[3] Reiniciar HCR
[4] Ver logs
[5] Mostrar configuración
[6] Desinstalar HCR
[0] Salir
```

## Comandos útiles

### Estado

```bash
systemctl status hcr-server
```

### Reiniciar

```bash
systemctl restart hcr-server
```

### Logs

```bash
journalctl -u hcr-server -f
```

## Archivos

```text
/opt/hcr/
├── hcr-server
├── install.sh
└── hcr-server.service
```

## Requisitos

- Ubuntu 20.04+
- Debian 11+
- Acceso root
- Conexión a Internet

## Proyecto

Repositorio:

https://github.com/KANEKIMOD/HCRCUSTOM

## Autor

KN MODS
