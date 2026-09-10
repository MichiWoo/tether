---
version: 1
slug: "apps-tether-tauri-src-app-vue"
primary_target: "apps/tether_tauri/src/App.vue"
related_targets: ["apps/tether_tauri/src/features/shell/HomeShell.vue","apps/tether_tauri/src/features/auth/AuthScreen.vue","apps/tether_tauri/src/features/devices/DevicesScreen.vue","apps/tether_tauri/src/features/clipboard/ClipboardScreen.vue","apps/tether_tauri/src/features/files/FilesScreen.vue","apps/tether_tauri/src/features/files/SharesTab.vue"]
---

# Direction contract — Tether (one-bit desktop)

Seed key: 75e107a6

THESIS: Tether es tu pasteboard y estante de archivos estirado a través de todos tus dispositivos — un solo escritorio, en todas partes. Rechaza el arreglo por defecto de la categoría: dashboard "cloud sync" con tarjetas redondeadas, gradiente púrpura e iconos de sincronización.

OWN-WORLD: Solo píxeles negros y blancos; dither ordenado (stipple) para grises; la selección invierte a negro sólido sobre dither al 50%. Títulos en pixel-caps estilo Chicago, etiquetas estilo Geneva, cromo negro de un píxel, iconos de 32px en dos colores. Las ventanas se superponen en un solo plano de escritorio.

STORY: Ves dispositivos y archivos como un único escritorio. Copias en un equipo y el ítem aparece en el pasteboard del otro, marcado "de X". Un archivo compartido aparece como ítem del escritorio con sello de estado; lo abres (vista previa) o lo guardas. Todo tiene estado claro: dispositivos online invertidos, transferencias en curso con marching-ants.

FIRST VIEWPORT: Ventana de 1px bordeada, título "Tether" en Chicago caps con barra de menú. Izquierda: ventana "Dispositivos" (icono + nombre + punto de estado; el actual invertido). Centro: ventana "Portapapeles" con el último ítem y una línea de entrada "enviar texto…" con botón Enviar. La acción primaria (enviar texto / soltar archivo) vive en el pasteboard.

FORM: medium-native-one-bit-desktop (challenger ganador en ambos ejes). Seed 75e107a6.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## Update — Mobile navigation (2026-09-10)
La barra inferior de iconos se elimina. En pointer:coarse, la barra de título de la ventana se vuelve selector de secciones: tap abre un panel invertido con las secciones, y el swipe horizontal (≥72px, <700ms, dx ≥ 2.2×dy) cicla entre las 4 secciones. Desktop conserva la barra de menú.

## Update — Dock inferior móvil (2026-09-10, segunda ronda)
El usuario optó por un dock fijo abajo inspirado en el patrón "FAB central" (a estilo 1-bit, sin círculos ni color): barra de tinta h-20 con 2 secciones a la izquierda (Inicio, Equipos), el botón primario sobresaliente **cuadrado papel 56px** central = Portapapeles, y 2 a la derecha (Archivos, Perfil). Rótulos silkscreen 9px; activo por inversión; safe-area-inset-bottom respetado; main recupera pb 5.25rem en coarse. El selector en title bar y el swipe siguen como acceso secundario.
