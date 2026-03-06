#!/bin/bash
set -e

# ─────────────────────────────────────────────
#  mt7902 Driver Installer (WiFi + Bluetooth)
#  Compatible: Arch/CachyOS/Manjaro | Ubuntu/Debian
# ─────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           MT7902 Driver Installer, por CesarFRR          ║${NC}"
echo -e "${CYAN}║  basado en el repositorio github.com/hmtheboy154/mt7902  ║${NC}"
echo -e "${CYAN}║  Créditos también para él, yo solo automatizo el proceso ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Detectar distro ──────────────────────────
if command -v pacman &>/dev/null; then
    DISTRO="arch"
elif command -v apt &>/dev/null; then
    DISTRO="debian"
else
    error "Distro no soportada. Usa Arch/Manjaro/CachyOS o Ubuntu/Debian."
fi
info "Distro detectada: $DISTRO"

# ── Verificar kernel compatible ──────────────
KERNEL_VER=$(uname -r)
KERNEL_MAJOR=$(echo "$KERNEL_VER" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL_VER" | cut -d. -f2)

if [[ "$KERNEL_MAJOR" -lt 6 ]] || { [[ "$KERNEL_MAJOR" -eq 6 ]] && [[ "$KERNEL_MINOR" -lt 6 ]]; }; then
    error "Kernel $KERNEL_VER no soportado. Se requiere 6.6 o superior."
fi
success "Kernel $KERNEL_VER compatible."

# ── Instalar dependencias ────────────────────
info "Instalando dependencias..."

if [[ "$DISTRO" == "arch" ]]; then
    HEADERS_PKG=""
    for pkg in linux-cachyos-headers linux-zen-headers linux-lts-headers linux-headers; do
        if pacman -Qi "$pkg" &>/dev/null || pacman -Si "$pkg" &>/dev/null 2>/dev/null; then
            HEADERS_PKG="$pkg"
            break
        fi
    done
    [[ -z "$HEADERS_PKG" ]] && error "No se encontró paquete de headers del kernel."
    sudo pacman -S --needed --noconfirm "$HEADERS_PKG" clang git base-devel

elif [[ "$DISTRO" == "debian" ]]; then
    sudo sed -i '/cdrom/s/^/#/' /etc/apt/sources.list 2>/dev/null

    info "Verificando integridad del sistema de paquetes..."
    sudo dpkg --configure -a 2>/dev/null

    info "Actualizando repositorios..."
    sudo apt update -qq

    sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" -qq

    info "Instalando herramientas de compilación..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        clang git build-essential

    info "Instalando headers del kernel..."
    sudo apt install -y "linux-headers-$(uname -r)" 2>/dev/null || \
    sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-amd64

    if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
        echo -e "\n${YELLOW}Los headers instalados requieren reiniciar para sincronizar con el kernel.${NC}"
        echo -e "${YELLOW}Esto es normal en Kali Linux. Reinicia y vuelve a ejecutar el script.${NC}\n"
        read -rp "¿Reiniciar ahora? [s/N]: " RESP </dev/tty
        if [[ "$RESP" =~ ^[Ss]$ ]]; then
            sudo reboot
        else
            error "Cancelado. Reinicia manualmente y vuelve a ejecutar el script."
        fi
    fi

    success "Headers sincronizados con el kernel $(uname -r)."
fi

success "Dependencias instaladas."

# ── Detectar compilador del kernel ──────────
if grep -q "clang" /proc/version 2>/dev/null; then
    info "Kernel compilado con Clang, usando LLVM=1..."
    MAKE_FLAGS="LLVM=1"
else
    info "Kernel compilado con GCC, compilando sin LLVM..."
    MAKE_FLAGS=""
fi

TMPDIR=$(mktemp -d)

# ════════════════════════════════════════════
#  WiFi
# ════════════════════════════════════════════
info "Clonando driver WiFi..."
git clone --branch backport --depth 1 https://github.com/hmtheboy154/mt7902 "$TMPDIR/mt7902"
cd "$TMPDIR/mt7902"
success "Repositorio WiFi clonado."

info "Compilando driver WiFi..."
sudo make install -j"$(nproc)" $MAKE_FLAGS
success "Driver WiFi instalado."

info "Instalando firmware WiFi..."
sudo make install_fw
success "Firmware WiFi instalado."

# ════════════════════════════════════════════
#  Bluetooth
# ════════════════════════════════════════════
info "Clonando driver Bluetooth..."
git clone --branch bluetooth_backport --depth 1 https://github.com/hmtheboy154/mt7902 "$TMPDIR/btusb_mt7902"
cd "$TMPDIR/btusb_mt7902"
success "Repositorio Bluetooth clonado."

info "Compilando driver Bluetooth..."
sudo make install -j"$(nproc)" $MAKE_FLAGS
success "Driver Bluetooth instalado."

info "Instalando firmware Bluetooth..."
sudo make install_fw

# El Makefile del repo instala el firmware en un subdirectorio incorrecto
if [[ -d "/lib/firmware/mediatek/btusb_mt7902" ]]; then
    info "Corrigiendo ruta del firmware Bluetooth..."
    sudo mv /lib/firmware/mediatek/btusb_mt7902/* /lib/firmware/mediatek/
    sudo rmdir /lib/firmware/mediatek/btusb_mt7902
fi
success "Firmware Bluetooth instalado."

# btusb y btmtk del kernel conflictúan con btusb_mt7902
info "Aplicando blacklist de btusb y btmtk..."
echo -e "blacklist btusb\nblacklist btmtk" | sudo tee /etc/modprobe.d/blacklist_btusb.conf > /dev/null
success "Blacklist aplicado."

# ════════════════════════════════════════════
#  Verificar
# ════════════════════════════════════════════
info "Cargando módulos..."
sudo modprobe mt7902e
sudo modprobe -r btusb btmtk 2>/dev/null
sudo modprobe btusb_mt7902 2>/dev/null || warn "Bluetooth requiere reinicio para cargar."

echo ""
WIFI_OK=false
BT_OK=false
lsmod | grep -q mt7902e      && WIFI_OK=true
lsmod | grep -q btusb_mt7902 && BT_OK=true

# --- Optimización de Bluetooth para MT7902 ---
BT_CONF="/etc/bluetooth/main.conf"

if [ -f "$BT_CONF" ]; then
    echo -e "\e[1;34m[INFO]\e[0m Optimizando parámetros de Bluetooth para TWS..."
    
    # Hacer copia de seguridad por si acaso
    sudo cp "$BT_CONF" "$BT_CONF.bak"

    # Habilitar AutoEnable (Enciende el BT al arrancar)
    sudo sed -i 's/^#AutoEnable=false/AutoEnable=true/' "$BT_CONF"
    sudo sed -i 's/^AutoEnable=false/AutoEnable=true/' "$BT_CONF"
    sudo sed -i 's/^#AutoEnable=true/AutoEnable=true/' "$BT_CONF"

    # Habilitar FastConnectable (Mejora la respuesta con audífonos baratos)
    sudo sed -i 's/^#FastConnectable = false/FastConnectable = true/' "$BT_CONF"
    sudo sed -i 's/^FastConnectable = false/FastConnectable = true/' "$BT_CONF"
    sudo sed -i 's/^#FastConnectable = true/FastConnectable = true/' "$BT_CONF"

    # Reiniciar el servicio para que CachyOS/Ubuntu tome los cambios
    sudo systemctl restart bluetooth
    echo -e "\e[1;32m[OK]\e[0m Configuración de Bluetooth aplicada."
else
    echo -e "\e[1;33m[WARN]\e[0m No se encontró /etc/bluetooth/main.conf. Saltando optimización."
fi
# --------------------------------------------

if $WIFI_OK && $BT_OK; then
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓  WiFi y Bluetooth cargados, revisa!! ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
elif $WIFI_OK; then
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓  WiFi cargado correctamente          ║${NC}"
    echo -e "${YELLOW}║   !  Bluetooth requiere reinicio         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   ✗  No se pudo cargar el módulo WiFi    ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Revisa los errores con: ${CYAN}dmesg | grep mt7902${NC}"
fi

echo ""
echo -e "  Los drivers cargarán ${GREEN}automáticamente${NC} en cada arranque."
echo -e "  Si el Bluetooth no funciona, reinicia el sistema."
echo ""
