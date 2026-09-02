# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Individuos con varios dispositivos propios (MacBook, iPhone, PC Windows/Linux) que necesitan mover texto y archivos entre *sus* dispositivos sin cables, correos a sí mismos ni fricción. Uso personal, no colaborativo: una sola cuenta, varios equipos de la misma persona.

## Product Purpose

Copiar texto o arrastrar un archivo en un dispositivo y pegarlo/recibirlo en otro, vía cuenta + servidor central. Existe para eliminar la fricción de "pasar algo de un equipo mío a otro". Éxito = el usuario olvida cómo se transfiere y solo lo hace: copia aquí, pega allá.

## Positioning

El servidor nunca actúa de buffer de bytes: los archivos van directo cliente↔S3/MinIO con URLs presignadas. Roadmap: transferencia P2P por red local (mDNS/WebRTC) y sin internet (BLE/WiFi Direct). Un competidor no puede copiar "tus datos van directo a tu almacenamiento, no por nuestro servidor" sin rehacer la arquitectura.

## Operating Context

- App de escritorio siempre disponible (bandeja del sistema), que detecta y reacciona en tiempo real (WebSocket) a lo que ocurre en los otros dispositivos.
- En móvil, la entrada es el share sheet nativo y el guardado a archivos.
- El usuario alterna entre equipos a lo largo del día; el estado online/offline de cada dispositivo es información permanente de la interfaz.

## Capabilities and Constraints

- Auth JWT con refresh rotativo (revocación por reuso).
- Dispositivos: CRUD + estado online/offline (heartbeat + WebSocket).
- Portapapeles: push/pull de texto, historial, dedupe por contenido y auto-copia en el destino.
- Archivos: subida/descarga directa a S3/MinIO con URLs presignadas y progreso; shares con ciclo de vida (CREATED/ACCEPTED/DOWNLOADED/EXPIRED) y TTL.
- Realtime Socket.IO con rooms por usuario y por dispositivo.
- **Lenguaje de diseño único y compartido** en desktop (macOS/Windows/Linux) y móvil (iOS/Android); no se adapta por SO. La UI se renderiza en el webview de Tauri (HTML/CSS).
- Terminología del producto: "dispositivos", "portapapeles", "archivos", "shares".
- Cliente actual en Tauri + Vue; existe un cliente Flutter equivalente (referencia funcional, no de diseño).

## Brand Commitments

- Nombre: **Tether**.
- Concepto: **"conecta tus dispositivos"** (el hilo que une tus equipos).
- El look visual actual (tema Dracula, fondo de constelación) es reemplazable; no es compromiso de marca.

## Evidence on Hand

- `README.md`, `docs/API.md` (API completa y ambientes), `docs/ROADMAP.md` (visión y fases).
- `apps/tether_app/` (cliente Flutter funcional: referencia de comportamiento y flujos).
- No hay testimonios, casos de estudio ni métricas de clientes; el trabajo futuro no debe inventarlos.

## Product Principles

1. **La transferencia debe sentirse instantánea**: copiar aquí → pegar allá, sin fricción ni pasos extra.
2. **Tus datos son tuyos**: los bytes van directo a tu almacenamiento, nunca buffereados por el servidor.
3. **Mismo lenguaje en todos tus equipos**: una sola experiencia compartida en desktop y móvil.
4. **Calma y confianza**: el estado de cada dispositivo (online/offline) y de cada transferencia siempre es claro.
5. **Seguridad por defecto**: tokens con rotación, archivos privados por usuario, expiración automática.

## Accessibility & Inclusion

- Respetar la preferencia de movimiento reducido del sistema (`prefers-reduced-motion`).
- Navegación por teclado y etiquetas accesibles en controles y estados (ya presente en el cliente actual).
