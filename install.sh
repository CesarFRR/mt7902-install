#!/bin/bash
set -e

# ─────────────────────────────────────────────
#  mt7902 Driver Installer
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
    # Detectar headers correctos (cachyos, linux, linux-lts, etc.)
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
    # Limpiar cdrom de sources.list si existe
    sudo sed -i '/cdrom/s/^/#/' /etc/apt/sources.list 2>/dev/null

    # Reparar paquetes interrumpidos
    info "Verificando integridad del sistema de paquetes..."
    sudo dpkg --configure -a 2>/dev/null

    # Actualizar repositorios
    info "Actualizando repositorios..."
    sudo apt update -qq

    # Reparar dependencias rotas silenciosamente
    sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" -qq

    # Instalar herramientas base
    info "Instalando herramientas de compilación..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        clang git build-essential

    # Instalar headers: primero el exacto, si falla el metapaquete
    info "Instalando headers del kernel..."
    sudo apt install -y "linux-headers-$(uname -r)" 2>/dev/null || \
    sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-amd64

    # Validar que los headers coincidan con el kernel corriendo
    INSTALLED_HEADERS=$(dpkg -l | grep "linux-headers-$(uname -r | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" | awk '{print $2}' | head -n1)
    if [[ -z "$INSTALLED_HEADERS" ]]; then
        warn "Los headers instalados podrían no coincidir con el kernel actual ($(uname -r))."
        warn "Si la compilación falla, reinicia para cargar el kernel más reciente y vuelve a ejecutar el script."
    else
        success "Headers sincronizados con el kernel $(uname -r)."
    fi
fi

success "Dependencias instaladas."

# ── Clonar repositorio ───────────────────────
TMPDIR=$(mktemp -d)
info "Clonando repositorio en $TMPDIR..."
git clone --branch backport --depth 1 https://github.com/hmtheboy154/mt7902 "$TMPDIR/mt7902"
cd "$TMPDIR/mt7902"
success "Repositorio clonado."

# ── Compilar e instalar driver ───────────────
info "Compilando driver (esto puede tardar unos segundos)..."
sudo make install -j"$(nproc)" LLVM=1
success "Driver instalado."

# ── Instalar firmware ────────────────────────
info "Instalando firmware..."
sudo make install_fw
success "Firmware instalado."


# ── Verificar ────────────────────────────────
info "Cargando el módulo..."
sudo modprobe mt7902e

echo ""
if lsmod | grep -q mt7902e; then
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓  Driver cargado correctamente    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  El driver ${CYAN}mt7902e${NC} está activo ahora mismo."
    echo -e "  También cargará ${GREEN}automáticamente${NC} en cada arranque."
    echo -e "  Tu Wi-Fi debería aparecer en el sistema, REVISA!!."
else
    echo -e "${RED}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}║   ✗  No se pudo cargar el módulo     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Revisa los errores con: ${CYAN}dmesg | grep mt7902${NC}"
fi
echo ""



