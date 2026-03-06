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
    # 1. Limpieza de CD-ROM
    sudo sed -i '/cdrom/s/^/#/' /etc/apt/sources.list 2>/dev/null

    # 2. Reparación preventiva de DPKG
    info "Verificando integridad del sistema de paquetes..."
    sudo dpkg --configure -a 2>/dev/null

    # 3. Actualización de repositorios
    info "Actualizando repositorios..."
    sudo apt update -qq

    # 4. Reparación profunda y silenciosa (Evita cuadros azules)
    info "Reparando posibles dependencias rotas y estabilizando el sistema..."
    sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qq

    # 5. Instalación de herramientas base
    info "Instalando herramientas de compilación..."
    if ! sudo DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" clang git build-essential; then
        warn "Fallo inicial. Intentando forzar actualización de librerías base..."
        sudo DEBIAN_FRONTEND=noninteractive apt install -y libc6 libc6-dev
    fi

    # 6. Instalación de headers (Lógica universal)
    info "Instalando headers del kernel..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "linux-headers-$(uname -r)" 2>/dev/null || \
    sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-generic 2>/dev/null || \
    sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-amd64

    # ── VALIDACIÓN DE KERNEL (Sincronización necesaria) ─────────────────────
    # Extraemos la versión de los headers instalados vs kernel actual
    # ── VALIDACIÓN DE KERNEL (Sincronización robusta) ─────────────────────
    # 1. Extraemos solo los números de los headers instalados (ej: 6.18.12)
    LATEST_HEADERS=$(dpkg -l | grep linux-headers- | grep amd64 | awk '{print $3}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    
    # 2. Extraemos solo los números del kernel en ejecución (ej: 6.12.38)
    # Esto elimina el "+kali-amd64" o cualquier otro sufijo de distro
    CURRENT_KERNEL=$(uname -r | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

    info "Versión Headers: $LATEST_HEADERS | Versión Kernel: $CURRENT_KERNEL"

    if [[ -n "$LATEST_HEADERS" && "$LATEST_HEADERS" != "$CURRENT_KERNEL" ]]; then
        echo -e "\n${YELLOW}╔══════════════════════ ATENCIÓN ══════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC} Se han instalado headers para el kernel ${GREEN}$LATEST_HEADERS${NC}    ${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC} Pero tu sistema aún corre con el kernel ${RED}$CURRENT_KERNEL${NC}      ${YELLOW}║${NC}"
        echo -e "${YELLOW}╟──────────────────────────────────────────────────────╢${NC}"
        echo -e "${YELLOW}║${NC} IMPORTANTE: Para que el driver compile, el Kernel   ${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC} y sus Headers deben ser la misma versión.           ${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC} Es obligatorio actualizar y REINICIAR el equipo.     ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════╝${NC}\n"

        # Forzamos lectura desde la terminal (/dev/tty) para saltar el pipe del curl
        read -rp "$(echo -e "${CYAN}[?]${NC} ¿Deseas aplicar el Kernel nuevo y reiniciar ahora? [s/N]: ")" RESP </dev/tty
        
        if [[ "$RESP" =~ ^[Ss]$ ]]; then
            info "Forzando la actualización del Kernel a la última versión disponible..."
            # Instalamos explícitamente la imagen del kernel junto con el upgrade
            sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-image-amd64 linux-headers-amd64 -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
            sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
            
            success "Kernel actualizado. Reiniciando en 5 segundos..."
            echo -e "${YELLOW}Al volver, el sistema usará el kernel $LATEST_HEADERS y el driver podrá compilar.${NC}"
            sleep 5
            sudo reboot
        else
            error "Cancelado. Debes reiniciar manualmente con el kernel nuevo para continuar."
        fi
    fi
    # ────────────────────────────────────────────────────────────────────────
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



