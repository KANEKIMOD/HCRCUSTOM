🚀 KN MODS - HCR CUSTOM INSTALLER

Instalador automático para HCR Server en Ubuntu, Debian y derivados.

✨ Características

- Instalación automática en VPS.
- Compatible con Ubuntu 20.04, 22.04 y 24.04.
- Soporte para:
  - Plain
  - TLS
  - Auto
- Configuración mediante menú interactivo.
- Servicio systemd automático.
- Gestión de logs.
- Reinicio rápido del servicio.
- Detección automática de certificados Let's Encrypt.

---

📦 Instalación rápida

Ejecuta:

curl -fsSL https://raw.githubusercontent.com/KANEKIMOD/HCRCUSTOM/main/setup.sh | bash -s -- --repo KANEKIMOD/HCRCUSTOM

---

⚙️ Instalación manual

git clone https://github.com/KANEKIMOD/HCRCUSTOM.git
cd HCRCUSTOM

chmod +x setup.sh
chmod +x install.sh
chmod +x hcr-server

sudo ./setup.sh

---

🔐 Modos disponibles

Plain

Instala HCR sin certificados TLS.

TLS

Instala HCR utilizando:

fullchain.pem
privkey.pem

Auto

Acepta conexiones TLS y no TLS automáticamente.

---

📊 Administración

Ver estado:

systemctl status hcr-server

Reiniciar:

systemctl restart hcr-server

Ver logs:

journalctl -u hcr-server -f

Detener:

systemctl stop hcr-server

---

🗑 Desinstalación

cd /opt/hcr

./install.sh --uninstall

---

📁 Estructura

HCRCUSTOM/
├── hcr-server
├── install.sh
├── setup.sh
├── README.md
└── assets/

---

👑 KN MODS

Desarrollado para simplificar la instalación y administración de HCR Server en VPS Linux.
