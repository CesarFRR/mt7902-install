# mt7902 Driver Installer

Automatic installer for the [MT7902 Wi-Fi driver](https://github.com/hmtheboy154/mt7902/tree/backport) on Linux.

## Requirements

- Kernel **6.6 to 6.19**
- Arch / CachyOS / Manjaro **or** Ubuntu / Debian
- Internet connection
- `sudo` access

## Installation

Run this single command in any shell (bash, zsh, fish, etc.):

```sh
curl -s https://raw.githubusercontent.com/CesarFRR/mt7902-install/main/install.sh | bash
```

The script will automatically:
1. Detect your distro and install required dependencies
2. Check your kernel version is compatible
3. Clone the driver source and compile it using LLVM/Clang
4. Install the firmware
5. Ask if you want to reboot

## After reboot

Verify the driver loaded correctly:

```sh
lsmod | grep mt7902
```

You should see `mt7902e` in the output.

## Notes

- The kernel compiled with Clang (e.g. CachyOS) requires building the module with `LLVM=1`. The script handles this automatically.
- Only the PCIe version of MT7902 is supported. For SDIO, refer to the [upstream repo](https://github.com/hmtheboy154/mt7902).
- For Bluetooth support, check the [bluetooth_backport branch](https://github.com/hmtheboy154/mt7902/tree/bluetooth_backport).

---

# Instalador del driver mt7902

Instalador automático del [driver Wi-Fi MT7902](https://github.com/hmtheboy154/mt7902/tree/backport) para Linux.

## Requisitos

- Kernel **6.6 a 6.19**
- Arch / CachyOS / Manjaro **o** Ubuntu / Debian
- Conexión a internet
- Acceso a `sudo`

## Instalación

Ejecuta este único comando desde cualquier shell (bash, zsh, fish, etc.):

```sh
curl -s https://raw.githubusercontent.com/CesarFRR/mt7902-install/main/install.sh | bash
```

El script automáticamente:
1. Detecta tu distro e instala las dependencias necesarias
2. Verifica que tu versión de kernel sea compatible
3. Clona el código fuente del driver y lo compila con LLVM/Clang
4. Instala el firmware
5. Pregunta si deseas reiniciar

## Después del reinicio

Verifica que el driver cargó correctamente:

```sh
lsmod | grep mt7902
```

Deberías ver `mt7902e` en la salida.

## Notas

- Los kernels compilados con Clang (como CachyOS) requieren compilar el módulo con `LLVM=1`. El script lo maneja automáticamente.
- Solo se soporta la versión PCIe del MT7902. Para SDIO, consulta el [repo original](https://github.com/hmtheboy154/mt7902).
- Para soporte de Bluetooth, revisa la [rama bluetooth_backport](https://github.com/hmtheboy154/mt7902/tree/bluetooth_backport).
