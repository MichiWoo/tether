---
name: Tether Web
description: Landing + panel admin — mismo mundo one-bit de la app (Dracula, dither, inversión)
colors:
  paper: "#282a36"
  ink: "#f8f8f2"
  muted: "#8b9cc9"
  gray-2: "#44475a"
typography:
  display:
    fontFamily: "Silkscreen, system-ui, sans-serif"
    fontWeight: 700
    transform: uppercase
    letterSpacing: 0.06em
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
  mono:
    fontFamily: "JetBrains Mono, ui-monospace, monospace"
rounded:
  none: "0px"
shadow:
  1bit: "3px 3px 0 var(--ink)"
  1bit-sm: "2px 2px 0 var(--ink)"
---

# Design System: Tether Web (Landing + Admin)

## Overview

La web es la **extensión pública del escritorio one-bit** de la app: mismos tokens, misma gramática. Dark-first sobre base Dracula. Nada de vidrio, gradientes por color o esquinas redondeadas — el carácter es "instrumento calmo": datos exactos, jerarquía por inversión, dither como único gris.

Fuentes cargadas **localmente** (luego @fontsource, nunca CDN): Silkscreen 400/700 (display), JetBrains Mono 400–700 (datos), system-ui (cuerpo).

Key Characteristics:

- Solo tinta y papel; dither (`.dither-25/50/75`) como único "gris" para superficies/hover; `--muted` solo texto secundario con AA ≥4.5:1.
- Bordes de 1px a ángulos rectos; sombras duras desplazadas sin blur (`.shadow-1bit`, `.shadow-1bit-sm`).
- Selección y estado activo por **inversión** (fondo tinta, texto papel), nunca por color.
- Rótulos de control en Silkscreen mayúsculas con tracking; datos en mono minúsculas.

## Named Rules

**The Two-Color Rule.** Solo `--ink` y `--paper`; cualquier "gris" proviene de dither; `--muted`/`--gray-2` solo para texto secundario/hover, jamás como acento.

**The Inversion Rule.** Lo seleccionado, activo, primario o "en línea" se marca invirtiendo (fondo `--ink`, texto `--paper`).

**The Hard-Shadow Rule.** Elevación = bloque sólido desplazado 2–3px, sin blur ni transparencia.

**The Zero-Radius Rule.** Radio de esquina 0px universal: botones, inputs, tarjetas, paneles, tablas, chips.

**The Local-Fonts Rule.** Fuentes siempre vía `@fontsource` (`@/fontsource/silkscreen/*`, `@/fontsource/jetbrains-mono/*`); ningún CDN/script de tercero.

**The Progressive-Data Rule.** Los datos vivos (releases/admin) se resuelven en runtime al API; ante fallo, la UI degrada a estados vacíos/huecos ("Próximamente"), nunca se bloquea la navegación.

## Color Tokens (de `styles/global.css`)

| Token | Valor | Uso |
|---|---|---|
| `--paper` | `#282a36` (Dracula bg) | Superficie base y fondo de lo invertido |
| `--ink` | `#f8f8f2` (Dracula fg) | Tinta: texto, bordes, y fondo de lo seleccionado |
| `--muted` | `#8b9cc9` | Solo texto secundario; AA garantizado sobre paper |
| `--gray-2` | `#44475a` | Hover/inactivo (dither o relleno plano), nunca acento |
| `--shadow` | `3px 3px 0 var(--ink)` | Ventanas/páneles |
| `shadow-1bit-sm` | `2px 2px 0 var(--ink)` | Toasts/banners/botones elevados |

## Typography (Jerarquía)

- **Display** — Silkscreen 700, caps, tracking 0.06em: h1–h4, botones (12px), chips/tabs (10–13px), números grandes de métricas.
- **Body** — system-ui 16px/1.6: párrafos de la landing.
- **Mono** — JetBrains Mono 12–14px: datos (tamaños, fechas, emails, números de tabla y inputs del panel).

## Components (reusables existentes en `global.css`)

- **`.btn`** (+ `--primary` invertido, `--outline` hover invertido, `--ghost` hover `--gray-2`, `--block`, `[disabled]` 0.45): rótulos display caps; `focus-visible` outline 2px offset 2px.
- **`.dither-25/50/75`**: grises procedurales; loading = `dither-50` como bloque skeleton.
- **`.shadow-1bit` / `.shadow-1bit-sm`**: única vía de elevación.
- **`.wrap`**: contenedor max 1120px, padding lateral `--space-2`.
- **`.visually-hidden`**: accesibilidad para labels/landmarks.
- **`Mark.astro`**: logo (cuadrado + hilo + cuadrado hueco), heredable por todo el sitio con `currentColor`.

## Patterns

- **Dashboard shell (panel /admin)**: dos columnas — sidebar de menú (brand Mark + ítems display caps con marcador cuadrado; activo invertido; acciones de sesión al pie, p.ej. "Cerrar sesión" btn--outline a bloque) + columna principal (topbar con título de sección silkscreen, chip de sesión, botón Recargar; debajo el contenido en ventanas). En <900px el sidebar colapsa a fila superior de menú horizontal. Los estilos de página van en `<style is:global>` porque el DOM del panel se genera en runtime.

- **Ventana/panel**: borde 1px + sombra `shadow-1bit`; opcionalmente una barra de título invertida (fondo tinta) con el rótulo display caps y controles a la derecha — la forma canónica de seccionar contenido denso (panel admin, tablas).
- **Tabs/menú**: ítems de menú display caps en fila; el activo invierte (papel sobre tinta); sin border-bottom moderno ni pillos.
- **Chips de estado**: borde 1px con marcador cuadrado (filled=normal, hollow=desconectado, striped=progreso); la variante "invert" marca el plan activo/seleccionado.
- **Tabla de datos**: bordes 1px, celdas mono 12px, headers display caps 10px; columnas clave a la izquierda, acciones a la derecha.
- **Barras de uso**: track borde 1px con padding 1px; fill tinta sólida; en saturación el fill pasa a rayado diagonal (hatch).

## Do's and Don'ts

### Do:
- Reusar tokens/clases de `global.css`; evadir SVG/inline-color hardcodeados.
- Marcar estados con inversión y dither; usar Silkscreen en rótulos, mono en datos.
- `focus-visible` visible y con offset; `prefers-reduced-motion` respetado.

### Don't:
- Don't introducir color de acento (ni para error), gradientes, glass o blur.
- Don't cargar fonts/JS de CDN.
- Don't usar radios ≠ 0.
- Don't usar XXX "material"/Shadcn-style componentes que se contradigan con la inversión — en la web pública no hay "cards redondeadas con gradiente púrpura"; ese es el anti-referente.
