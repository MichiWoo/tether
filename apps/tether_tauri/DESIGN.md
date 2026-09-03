---
name: Tether
description: Portapapeles y transferencia de archivos entre tus dispositivos
colors:
  ink: "#000000"
  paper: "#ffffff"
  muted: "#787878"
  gray-2: "#dadada"
typography:
  display:
    fontFamily: "Silkscreen, system-ui, sans-serif"
    fontWeight: 700
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI, system-ui, sans-serif"
  mono:
    fontFamily: "'JetBrains Mono', ui-monospace, monospace"
rounded:
  none: "0px"
spacing:
  sm: "12px"
  md: "20px"
  lg: "28px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    padding: "10px 14px"
  button-secondary:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    padding: "10px 14px"
---

# Design System: Tether

## Overview

**Creative North Star: "El escritorio de un solo bit"**

Tether es un escritorio Macintosh clásico de un solo bit, estirado a través de todos tus dispositivos. La interfaz habla en la gramática nativa de "copiar y pegar": el portapapeles es el *pasteboard*, los archivos son ítems del escritorio, los dispositivos son una barra de menú con estado. Todo se dibuja con tinta y papel: píxeles negros y blancos únicamente, con el *dither* ordenado ocupando el lugar del gris, como en un Mac clásico.

La identidad rechaza explícitamente el "dashboard cloud sync" genérico: sin tarjetas redondeadas, sin gradientes púrpura, sin iconos de sincronización, sin vidrio. La personalidad es calma de instrumento y oficio de terminal: estado siempre legible, jerarquía por inversión en vez de color.

**Key Characteristics:**
- Monocromo estricto: tinta y papel, nada más.
- Selección y activo por **inversión**, no por color.
- Dither ordenado como único "gris" (excepto dos grises planos para texto secundario y hover).
- Bordes de 1px a ángulos rectos; sombras duras sin desenfoque.
- Tipografía pixel (Silkscreen) para títulos, monoespaciada (JetBrains Mono) para datos.

## Colors

Una paleta de dos colores: tinta sobre papel. El gris es *dither*, no un tercer color.

### Neutral
- **Tinta** (`#000000` / `--ink`): texto, bordes, iconos, y el fondo de toda selección o acción primaria. Es el color de dibujo; en modo oscuro pasa a `#f8f8f2` (foreground de Dracula).
- **Papel** (`#ffffff` / `--paper`): el fondo de la superficie. En modo oscuro pasa a `#282a36` (background de Dracula).
- **Gris atenuado** (`#787878` / `--muted`): solo texto secundario (marcas de tiempo, plataformas). El único gris plano permitido para texto. En modo oscuro pasa a `#6272a4` (comment de Dracula).
- **Gris de relleno** (`#dadada` / `--gray-2`): solo el hover/inactivo de superficies. Nunca un color de acento. En modo oscuro pasa a `#44475a` (current line de Dracula).

### Dark Mode (Dracula)
El modo oscuro no invierte a negro/blanco; adopta la paleta base de Dracula manteniendo la misma lógica de dos colores (tinta sobre papel, dither e inversión). Los acentos de Dracula (púrpura, cian, verde, rosa, naranja, rojo) no se usan: la selección y el activo siguen marcándose por inversión, no por color.

### Named Rules
**The Two-Color Rule.** Solo tinta y papel. Todo "gris" se produce por dither ordenado (`dither-25`, `dither-50`, `dither-75`); los grises planos `muted` y `gray-2` existen únicamente para legibilidad de texto secundario y para hover, y jamás actúan como acento.

**The Inversion Rule.** Lo seleccionado, activo o primario se invierte (fondo de tinta, texto de papel). Nunca un tercer color marca la selección.

## Typography

**Display Font:** Silkscreen (con fallback a system-ui) — la voz pixel de títulos.
**Body Font:** system-ui stack (`-apple-system`, Segoe UI, …) — la etiqueta "Geneva" limpia.
**Label/Mono Font:** JetBrains Mono — para datos, nombres de archivo, fechas y tamaños.

**Character:** Silkscreen da el sabor bitmap del Mac clásico en ventanas, menú y botones; el mono fija el carácter de "terminal de datos"; el system-ui mantiene legibles las etiquetas largas.

### Hierarchy
- **Display** (Silkscreen 700, 12–14px, uppercase, tracking-wide): títulos de ventana, barra de menú, botones, chips y encabezados de sección.
- **Title** (Silkscreen 700, 14px, uppercase): nombres de ítems destacados.
- **Body** (system-ui, 14px): etiquetas y descripciones.
- **Label** (JetBrains Mono, 12px): datos, fechas, tamaños, estados, ID.

### Named Rules
**The Uppercase-Pixel Rule.** Todo rótulo de control (botón, chip, título de ventana, ítem de menú) se compone en Silkscreen mayúsculas con tracking; los datos en mono van en minúsculas.

## Layout

Estructura de "escritorio": una **barra de menú** invertida arriba (tinta sobre papel, borde inferior de 1px) con la marca, las tres secciones como ítems de menú, el estado realtime y el menú de usuario; debajo, una **ventana** con borde de 1px, sombra dura y barra de título invertida que aloja la sección activa.

La ventana vive en un marco con padding de 12px (`p-3`) sobre el papel. El contenido respira con un ritmo de 12px / 20px / 28px (`p-3` / `p-5` / `p-7`) y un margen lateral de contenido de 20px (`px-5`). En pantallas estrechas la barra de menú colapsa y las secciones se apilan; el mundo nunca introduce un grid de píxeles fijo.

## Elevation & Depth

Profundidad por **inversión y sombra dura**, no por desenfoque. No hay sombras ambientales suaves.

### Shadow Vocabulary
- **Sombra 1-bit** (`box-shadow: 3px 3px 0 var(--ink)`): ventanas y diálogos. La sombra es un bloque de tinta desplazado, no un fundido.
- **Sombra 1-bit sm** (`box-shadow: 2px 2px 0 var(--ink)`): banners de error y toasts.

### Named Rules
**The Hard-Shadow Rule.** Cualquier elevación es un desplazamiento sólido de tinta (2–3px, sin blur). Nunca `blur-radius` distinto de cero, nunca sombra translúcida.

## Shapes

Ángulos rectos en todas partes. Radio de esquina **cero** (0px) de forma universal: botones, campos, tarjetas, chips, diálogos. Los marcos usan borde sólido de 1px; las ventanas y diálogos suben a 2px. El único "recorte" decorativo es el dither.

## Components

### Buttons
- **Shape:** rectángulo de borde 1px, esquinas 0px.
- **Primary:** fondo de tinta, texto de papel, borde de tinta; en hover invierte a papel/tinta.
- **Secondary / Outline:** fondo de papel, texto de tinta, borde de tinta; en hover invierte.
- **Ghost:** sin borde, texto de tinta; hover rellena `gray-2`.
- **Destructive:** igual que primary; el peligro se comunica por icono + etiqueta, no por color.
- **Focus:** anillo de 1px de tinta. Rótulo en Silkscreen mayúsculas 12px.

### Chips
- **Style:** borde de 1px de tinta, rótulo Silkscreen mayúsculas 10px.
- **State:** `invert` (tinta/papel) para "este equipo"; `outline` con cuadrado relleno para "en línea"; `dim` con cuadrado hueco para "desconectado"; indicador rayado animado para "en progreso".

### Cards / Containers
- **Corner Style:** 0px.
- **Background:** papel.
- **Shadow Strategy:** sin sombra (el borde de 1px es la separación).
- **Border:** 1px de tinta.
- **Hover:** relleno `gray-2`. **Selected:** inversión completa (tinta/papel).

### Inputs / Fields
- **Style:** borde de 1px de tinta, fondo de papel, texto mono 14px; etiqueta en Silkscreen mayúsculas 11px.
- **Focus:** el borde se mantiene; el campo se marca con un inset de 1px.
- **Error / Disabled:** el error se marca con un cuadrado de tinta + texto; deshabilitado baja la opacidad al 40%.

### Navigation
- **Style:** barra de menú invertida; el ítem activo invierte dentro de la barra (papel/tinta). Ítems en Silkscreen mayúsculas.

### Signature: Progress Bar
- Pista con borde de 1px y padding de 1px; relleno de tinta sólida; en error el relleno se vuelve rayado diagonal (`hatch`); el trabajo en curso puede usar rayas de barbero animadas (`stripes`).

## Do's and Don'ts

### Do:
- **Do** usar borde de 1px de tinta para toda separación y control; 2px solo en marcos de ventana/diálogo.
- **Do** marcar selección/activo con inversión (tinta sobre papel).
- **Do** representar gris con dither ordenado; usar `muted`/`gray-2` solo para texto secundario y hover.
- **Do** componer títulos, botones, chips y menú en Silkscreen mayúsculas con tracking.
- **Do** usar sombra dura desplazada (2–3px, sin blur) para elevación.
- **Do** respetar `prefers-reduced-motion` en las rayas animadas y la constelación.

### Don't:
- **Don't** usar radio de esquina distinto de cero.
- **Don't** introducir un color distinto de tinta/papel (ni para error, ni para acento).
- **Don't** usar gradientes, glassmorphism, blur o sombras suaves translúcidas.
- **Don't** usar más de un icono decorativo por ítem; el color no es señal, la forma y la inversión sí.
- **Don't** volver a la tarjeta redondeada con gradiente púrpura del dashboard "cloud sync" — es el anti-referente de la categoría.
