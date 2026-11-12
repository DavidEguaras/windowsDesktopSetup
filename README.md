# windowsDesktop setup

Mi escritorio de Windows 11, reproducible con un solo script: barra superior estilo macOS con **YASB**, barra de tareas / menú inicio / centro de notificaciones retocados con **Windhawk**, cursores **macOS Tahoe**, fuentes y wallpapers.

![Escritorio](screenshots/escritorio.png)

## Capturas

| Menú inicio (Windhawk) | Selector de salida de audio (YASB) |
|---|---|
| ![Menú inicio](screenshots/inicio.png) | ![Volumen](screenshots/volumen.png) |

| Widget de media (YASB) | Con otro fondo |
|---|---|
| ![Media](screenshots/media.png) | ![Otro fondo](screenshots/otro-fondo.png) |

La barra superior es YASB: botón de inicio a la izquierda, reloj en el centro y, a la derecha, bandeja del sistema, uso de MEM/CPU, idioma de teclado, canción en reproducción, volumen, notificaciones y menú de apagado. Abajo, la barra de tareas de Windows centrada y flotante gracias a los mods de Windhawk.

## Instalación

```powershell
git clone https://github.com/DavidEguaras/windowsDesktop-setup.git
cd windowsDesktop-setup
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

El script se relanza como administrador (Windhawk guarda sus mods en `HKLM` y `ProgramData`). Antes de sobrescribir nada, hace una copia en `%USERPROFILE%\windowsDesktop-setup-backup\<fecha>`.

Durante la instalación pregunta si quieres descargar la carpeta de wallpapers.

Para saltarte pasos:

```powershell
.\install.ps1 -Skip apps,wallpapers
```

Pasos disponibles: `apps`, `fonts`, `yasb`, `windhawk`, `cursors`, `wallpapers`, `theme`.

## Qué hace

| Paso | Detalle |
|---|---|
| `apps` | Instala [YASB](https://github.com/amnweb/yasb), [Windhawk](https://windhawk.net) y Git con `winget` |
| `fonts` | Instala **Figtree** (incluida en el repo) y **JetBrainsMono Nerd Font** (descargada de nerd-fonts) para el usuario actual |
| `yasb` | Copia `config.yaml` y `styles.css` a `~/.config/yasb` y añade YASB al inicio de Windows |
| `windhawk` | Restaura el código de los mods, los binarios compilados y sus ajustes (`mods.reg`) |
| `cursors` | Copia los cursores macOS Tahoe, los aplica y los registra como esquema "macOS Tahoe" |
| `wallpapers` | Pregunta y, si aceptas, clona [DavidEguaras/wallpapers](https://github.com/DavidEguaras/wallpapers) en `Imágenes\wallpapers` y pone el fondo |
| `theme` | Modo oscuro + transparencia |

## Mods de Windhawk

| Mod | Estado |
|---|---|
| Windows 11 Taskbar Styler | activado |
| Windows 11 Start Menu Styler | activado |
| Windows 11 Notification Center Styler | activado |
| Taskbar height and icon size | activado |
| Taskbar auto-hide speed | activado |
| Slick Window Arrangement | desactivado |

## Estructura

```
install.ps1                 script de instalación
yasb/                       config.yaml + styles.css
windhawk/mods-source/       código de los mods (.wh.cpp)
windhawk/compiled/          mods compilados (32 y 64 bits)
windhawk/mods.reg           ajustes de cada mod
cursors/macos-tahoe/        cursores (.cur / .ani)
fonts/figtree/              fuente Figtree
screenshots/                capturas del README
```

## Notas

- El widget del tiempo de YASB lee `YASB_WEATHER_API_KEY` y `YASB_WEATHER_LOCATION` de variables de entorno; defínelas si quieres usarlo.
- Si algún mod de Windhawk no carga tras instalar (por ejemplo, después de actualizar Windhawk), abre Windhawk y vuelve a compilarlo desde la página del mod.
- Los cursores son del pack *macOS Tahoe Cursor (With Shadow)*, de su autor; se incluyen solo para facilitar la reinstalación.
