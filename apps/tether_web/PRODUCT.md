# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Visitante público** (en la landing): personas con varios dispositivos propios (MacBook, iPhone, Windows/Linux, Android/iOS) que evalúan Tether, consultan cómo funciona y descargan el cliente para su plataforma. Usan el modo lectura de la landing, de forma clara y sin fricción, con foco en entender el mecanismo (portapapeles + archivos directos a S3, sin buffer del servidor).
- **Operador/administrador** (en `/admin`): el propietario del servicio y operadores en que decida delegar el mantenimiento. Tareas: revisar planes y sus límites, ajustarlos sin redeploy, cambiar plan de usuarios concretos (soporte/activación manual), y vigilar métricas de uso (storage, traspaso mensual, dispositivos activos, shares). Uso esporádico, de escritorio mayormente, con foco en precisión de datos y velocidad de gestión.

## Product Purpose

La web cumple dos misiones: 1) **Vender/comunicar Tether** — landing estática que explica el producto, muestra el demo y rutea las descargas por plataforma (leidas del registro de releases registrado por CI vía API), y 2) **Gestionar el servicio** — panel administrativo para planes/cuotas, usuarios y métricas, sin conversar por terminal.

Éxito de la landing = el visitante entiende el valor (copiar aquí → pegar allá) y llega a la descarga correcta para su OS. Éxito del panel = mutar la configuración de planes o el plan de un usuario en <1 minuto sin tocar backend.

## Positioning

- La landing **promociona la app**; hoy no vende suscripciones (no hay Stripe). Los **planes aparecen como feature** y la sección de **precios con CTA de compra queda como objetivo cercano** del área web, para actuar cuando el billing exista (documento aquí, no se ha inventado UI ni precios).
- El backend nunca buferagea bytes: la landing comunica este diferenciador (archivos directo cliente↔S3/MinIO).
- El cliente móvil/desktop es el producto; la web debe hablar el **mismo lenguaje visual** (one-bit) para que la marca se reconozca de una mano en cada superficie.

## Operating Context

- Deploy: imagen Docker (nginx estático) única y ampliable para deploy single-tenant: sirve la landing y proxía la API (incl. `/admin`, `/releases`) y WebSocket (`/realtime`) al backend en la red interna.
- Dev local: `NUXT_PUBLIC_API_BASE_URL=http://localhost:3100 pnpm --filter @tether/web dev` (Nuxt 4 + Nuxt UI + Nuxt Charts, SSG); panel en `/admin`.
- Los datos publicados (versión, tamaños, badges) se resuelven en runtime contra el registro de releases; si el API no responde, la landing degrada a "Próximamente" por plataforma (progresiva, no rota).
- Panel: acceso por `X-Plan-Admin-Key` (compartida, en el `.env` del backend). No hay multi-tenant ni roles distintos: **people la comparten** en producción; hacia el futuro se evaluó cuentas propia/audit — fuera de alcance por ahora.
- Ci registra cada release en Postgres vía `POST /releases` (API key de servicio distinta de la de admin).

## Capabilities and Constraints

- Nuxt 4 SSG (`nuxt generate`): HTML prerenderizado (SEO) + Vue hidratado donde aporta (demo, releases, panel). Nuxt UI themed one-bit; gráficas con Nuxt Charts. Datos se piden en runtime cuando dan valor fresco (releases, admin).
- El panel es un componente Vue (composables reactivos), pero la página sigue siendo estática al build; la key viaja por header y vive en sessionStorage, nunca en el bundle.
- Nginx no debe exponer el backend sin necesidad: solo proxía rutas del API (ver `nginx.conf`); la página admin vive en la raíz estática y la key viaja por header, nunca en query/cookie.
- Accesibilidad: `--muted` calibrado ≥4.5:1 sobre `--paper` (AA en 10–13px); foco visible 2px; landings con landmarks correctos. Respecto de `prefers-reduced-motion`.
- Sin cookies, analytics o terceros por ahora: la landing no carga JS de terceros (fuentes via @fontsource locales).

## Brand Commitments

- Nombre: **Tether** ("conecta tus dispositivos": el hilo que une tus equipos).
- Mundo visual: **one-bit** — solo tinta y papel sobre base Dracula, dither como único gris, inversión como señal de selección, esquinas 0px, sombras duras desplazadas (sin blur). Tipografías: Silkscreen (display), JetBrains Mono (datos), system ui (cuerpo).
- La constelación de la landing y el logo (cuadrado + hilo + cuadrado) son el corazón de la marca; son reutilizables, no reemplazables en este momento.

## Evidence on Hand

- `README.md` raíz (stack, despliegue, variables), `docs/API.md`, `docs/RELEASES.md`, `docs/ROADMAP.md`.
- `apps/tether_web/src/styles/global.css` (tokens/mundo incumbent), `Mark.astro` (logo), `Constellation.astro`, `DemoWindow.astro`.
- Endpoints que la web consume: `GET /releases/latest`, `/health` (deg), panel: `GET/PUT /admin/[plans|users|metrics]` con `X-Plan-Admin-Key`.

## Product Principles

1. **Mecanismo primero**: explica el "cómo" (S3 directo, WebSocket, P2P en el roadmap) sin humo — el producto de confianza se muestra con datos reales de estado.
2. **Un solo mundo visual**: la landing, el panel y la app comparten la gramática one-bit (tinta/papel/dither/inversión); nunca inventar un estilo flotante por página.
3. **Calma de instrumento**: el panel prioriza datos exactos, jerarquía por inversión y estados claros sobre decorative.
4. **La descarga correcta al primer click**: botón por OS con isPrimary del registro; si falla el API, degradar a "Próximamente", no bloquear.
5. **Seguridad por omisión**: la key del panel vive solo en el env del backend; nunca en HTML estático ni querystrings.

## Accessibility & Inclusion

- Contraste AA garantizado por tokens (muted calibrado).
- Navegación por teclado en tabs y tablas; foco visible 2px.
- `prefers-reduced-motion` respetado (constelación y transiciones).
- Etiquetas asociadas en formularios del panel (`<label>` con `for`), `aria-selected` en tabs.
