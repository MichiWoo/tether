<script setup lang="ts">
import type { ReleaseAsset } from '~/utils/releases'
import { archLabel, formatBytes, pickPrimary } from '~/utils/releases'

definePageMeta({ layout: 'landing' })

const DESCRIPTION
  = 'Tether conecta tus dispositivos: copia texto y mueve archivos entre tu Mac, PC, iPhone o Android, sin cables.'

// URLs absolutas para canonical / Open Graph / Twitter (los crawlers no resuelven rutas relativas).
const { public: { siteUrl } } = useRuntimeConfig()
const canonicalUrl = siteUrl
const ogImage = `${siteUrl}/logo.png`

useHead({
  title: 'Tether — Copia aquí, pega allá',
  meta: [
    { name: 'description', content: DESCRIPTION },
    { property: 'og:type', content: 'website' },
    { property: 'og:title', content: 'Tether — Copia aquí, pega allá' },
    { property: 'og:description', content: DESCRIPTION },
    { property: 'og:image', content: ogImage },
    { property: 'og:url', content: canonicalUrl },
    { property: 'og:site_name', content: 'Tether' },
    { name: 'twitter:card', content: 'summary_large_image' },
    { name: 'twitter:title', content: 'Tether — Copia aquí, pega allá' },
    { name: 'twitter:description', content: DESCRIPTION },
    { name: 'twitter:image', content: ogImage },
  ],
  link: [{ rel: 'canonical', href: canonicalUrl }],
})

const PLATFORMS = [
  { name: 'macOS', tag: 'Mac', note: 'Apple Silicon + Intel', platform: 'macos' },
  { name: 'Windows', tag: 'Win', note: 'x64', platform: 'windows' },
  { name: 'Linux', tag: 'Linux', note: 'AppImage / .deb', platform: 'linux' },
  { name: 'iOS', tag: 'iOS', note: 'iPhone / iPad', platform: 'ios' },
  { name: 'Android', tag: 'APK', note: '8.0+', platform: 'android' },
]

const FEATURES = [
  {
    n: '01',
    title: 'Portapapeles',
    body: 'Copia texto en un equipo y pégalo en otro. Con historial, dedupe y auto-copiado en el destino.',
  },
  {
    n: '02',
    title: 'Archivos',
    body: 'Arrastra, suelta y recibe. Los bytes van directo a tu almacenamiento (S3/MinIO), nunca por nuestro servidor.',
  },
  {
    n: '03',
    title: 'Tiempo real',
    body: 'Estado online/offline de cada dispositivo y progreso en vivo de cada transferencia, por WebSocket.',
  },
]

const STEPS = [
  { n: '1', title: 'Copia', body: 'En un dispositivo, copia texto o arrastra un archivo.' },
  { n: '2', title: 'Viaja', body: 'El ítem aparece en el pasteboard del otro dispositivo, siempre tuyo.' },
  { n: '3', title: 'Pega', body: 'Pégalo o guárdalo. Sin cables, sin correos a ti mismo.' },
]

const PLANS = [
  {
    name: 'Gratis',
    desc: 'Para empezar. Todo lo esencial, sin tarjeta.',
    cta: 'Descargar ahora',
    href: '#descargas',
  },
  {
    name: 'Pro',
    desc: 'Más volumen, más dispositivos y transferencias prioritarias.',
    flag: 'Próximamente',
  },
  {
    name: 'Equipos',
    desc: 'Para compartir el hilo entre varias personas.',
    flag: 'Próximamente',
  },
]

// Resuelve las descargas contra el backend (GET /releases/latest).
// El CI registra cada artefacto en Postgres vía POST /releases y la landing
// pide URLs presignadas frescas (TTL 7 días). Un botón por OS: prefiere
// `isPrimary` del API, con fallback por extensión. iOS/Android quedan en
// "Próximamente". Es mejora progresiva: si el backend no responde, quedan así.
const { public: { apiBase } } = useRuntimeConfig()

interface DownloadInfo {
  href: string
  note: string
  title: string
  ready: boolean
}
const downloads = ref<Record<string, DownloadInfo>>({})
const releaseVersion = ref<string | null>(null)

onMounted(async () => {
  let releases: ReleaseAsset[]
  try {
    const res = await fetch(`${apiBase}/releases/latest?channel=stable`)
    if (!res.ok) return
    releases = await res.json()
    if (!Array.isArray(releases) || releases.length === 0) return
  } catch {
    // sin conexión con el backend: se deja el estado por defecto
    return
  }

  releaseVersion.value = releases[0]!.version

  const next: Record<string, DownloadInfo> = {}
  for (const p of PLATFORMS) {
    const candidates = releases.filter(r => r.platform === p.platform)
    if (candidates.length === 0) continue
    const match = pickPrimary(candidates, p.platform)
    if (!match?.downloadUrl) continue
    next[p.platform] = {
      href: match.downloadUrl,
      title: `${match.filename}${match.size ? ` (${formatBytes(match.size)})` : ''}`,
      note: `${archLabel(match.arch)}${match.size ? ` · ${formatBytes(match.size)}` : ''}`,
      ready: true,
    }
  }
  downloads.value = next
})
</script>

<template>
  <div>
    <!-- ============ HERO ============ -->
    <section class="hero">
      <Constellation />
      <div class="wrap hero__grid">
        <div class="hero__copy">
          <p class="hero__kicker">
            <Mark :size="22" /> Conecta tus dispositivos
            <span v-if="releaseVersion" class="hero__badge">v{{ releaseVersion }}</span>
          </p>
          <h1 class="hero__title">Copia aquí,<br>pega allá.</h1>
          <p class="hero__lead">
            Tether estira tu portapapeles y tu estante de archivos a través de todos tus
            equipos. Un solo escritorio, en todas partes.
          </p>
          <p class="hero__sub">
            Tus datos van directo a tu almacenamiento: el servidor nunca actúa de buffer.
          </p>
          <div class="hero__actions">
            <a class="btn btn--primary" href="#descargas">Descargar Tether</a>
            <a class="btn btn--ghost" href="#como-funciona">Cómo funciona</a>
          </div>
        </div>

        <div class="hero__demo">
          <div class="hero__dither dither-25" aria-hidden="true" />
          <ClientOnly>
            <DemoWindow />
          </ClientOnly>
          <p class="hero__demo-caption">Clipboard y archivos en vuelo. Izquierda a derecha, sin cables.</p>
        </div>
      </div>
    </section>

    <!-- ============ FEATURES ============ -->
    <section id="funciones" class="section">
      <div class="wrap">
        <header class="section__head">
          <span class="section__kicker">Funciones</span>
          <h2 class="section__title">Un solo escritorio,<br>en todas partes.</h2>
        </header>

        <div class="features">
          <article v-for="f in FEATURES" :key="f.n" class="card">
            <span class="card__num">{{ f.n }}</span>
            <h3 class="card__title">{{ f.title }}</h3>
            <p class="card__body">{{ f.body }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- ============ CÓMO FUNCIONA ============ -->
    <section id="como-funciona" class="section section--invert">
      <div class="wrap">
        <header class="section__head">
          <span class="section__kicker">Cómo funciona</span>
          <h2 class="section__title">Tres pasos.<br>Cero fricción.</h2>
        </header>

        <ol class="steps">
          <li v-for="s in STEPS" :key="s.n" class="step">
            <span class="step__num">{{ s.n }}</span>
            <h3 class="step__title">{{ s.title }}</h3>
            <p class="step__body">{{ s.body }}</p>
          </li>
        </ol>
      </div>
    </section>

    <!-- ============ DESCARGAS ============ -->
    <section id="descargas" class="section">
      <div class="wrap">
        <header class="section__head">
          <span class="section__kicker">Descargas</span>
          <h2 class="section__title">Para todos<br>los equipos.</h2>
          <p class="section__lead">
            Última versión: <span class="downloads__version" aria-live="polite">{{ releaseVersion ? `v${releaseVersion}` : '—' }}</span>.
            Los enlaces apuntan a la release más reciente publicada.
          </p>
        </header>

        <div class="downloads">
          <a
            v-for="p in PLATFORMS"
            :key="p.platform"
            class="download"
            :href="downloads[p.platform]?.ready ? downloads[p.platform]?.href : undefined"
            :download="downloads[p.platform]?.ready ? '' : undefined"
            :aria-disabled="downloads[p.platform]?.ready ? undefined : 'true'"
            :tabindex="downloads[p.platform]?.ready ? undefined : -1"
            :title="downloads[p.platform]?.title"
          >
            <span class="download__tag">{{ p.tag }}</span>
            <span class="download__info">
              <span class="download__name">{{ p.name }}</span>
              <span class="download__note">{{ downloads[p.platform]?.note ?? p.note }}</span>
            </span>
            <span class="download__cta">{{ downloads[p.platform]?.ready ? 'Descargar' : 'Próximamente' }}</span>
          </a>
        </div>
      </div>
    </section>

    <!-- ============ PLANES ============ -->
    <section id="planes" class="section section--invert">
      <div class="wrap">
        <header class="section__head">
          <span class="section__kicker">Próximamente</span>
          <h2 class="section__title">Planes a tu medida.</h2>
          <p class="section__lead">Estamos preparando suscripciones para quienes necesitan más volumen y prioridad.</p>
        </header>

        <div class="plans">
          <article v-for="p in PLANS" :key="p.name" class="plan" :class="{ 'plan--muted': p.flag }">
            <div class="plan__head">
              <h3 class="plan__name">{{ p.name }}</h3>
              <span v-if="p.flag" class="plan__flag">{{ p.flag }}</span>
            </div>
            <p class="plan__desc">{{ p.desc }}</p>
            <a v-if="p.cta" class="btn btn--outline plan__cta" :href="p.href">{{ p.cta }}</a>
          </article>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
/* Hero */
.hero {
  position: relative;
  overflow: hidden;
  border-bottom: 1px solid var(--ink);
}
.hero__grid {
  display: grid;
  grid-template-columns: 1.05fr 0.95fr;
  gap: var(--space-4);
  align-items: center;
  padding-block: var(--space-5);
  position: relative;
}
.hero__kicker {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  font-family: var(--font-display);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--muted);
  margin-bottom: var(--space-3);
}
.hero__badge {
  font-family: var(--font-mono);
  font-size: 10px;
  text-transform: none;
  letter-spacing: 0.04em;
  border: 1px solid var(--ink);
  color: var(--ink);
  padding: 2px 8px;
}
.hero__title {
  font-size: clamp(34px, 8.5vw, 76px);
  letter-spacing: 0.02em;
}
.hero__lead {
  margin-top: var(--space-3);
  font-size: 18px;
  max-width: 34ch;
}
.hero__sub {
  margin-top: var(--space-2);
  font-family: var(--font-mono);
  font-size: 13px;
  color: var(--muted);
  max-width: 44ch;
}
.hero__actions {
  display: flex;
  gap: var(--space-2);
  margin-top: var(--space-4);
}

.hero__demo {
  position: relative;
}
/* Panel dither anclado a la ventana de la demo, sin invadir la caption. */
.hero__dither {
  position: absolute;
  inset: 26px -16px 76px 26px;
  border: 1px solid var(--ink);
  opacity: 0.3;
}
/* La ventana siempre sobre el panel. */
.hero__demo > :deep(.win) {
  position: relative;
  z-index: 1;
}
.hero__demo-caption {
  position: relative;
  margin-top: var(--space-2);
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--muted);
  max-width: 46ch;
}

/* Secciones */
.section {
  padding-block: var(--space-5);
  border-bottom: 1px solid var(--ink);
}
.section--invert {
  background: var(--ink);
  color: var(--paper);
}
.section--invert .section__kicker,
.section--invert .section__lead {
  color: var(--gray-2);
}
.section--invert .section__title {
  color: var(--paper);
}

.section__head {
  max-width: 720px;
  margin-bottom: var(--space-4);
}
.section__kicker {
  font-family: var(--font-display);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--muted);
}
.section__title {
  margin-top: var(--space-1);
  font-size: clamp(28px, 4vw, 44px);
}
.section__lead {
  margin-top: var(--space-2);
  font-family: var(--font-mono);
  font-size: 14px;
  color: var(--muted);
}
.downloads__version {
  font-family: var(--font-mono);
  color: var(--ink);
}

/* Features */
.features {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
}
.card {
  border: 1px solid var(--ink);
  padding: var(--space-3) var(--space-2);
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.card:hover {
  box-shadow: var(--shadow);
  transform: translate(-2px, -2px);
  transition: transform 0.15s, box-shadow 0.15s;
}
.card__num {
  font-family: var(--font-mono);
  font-size: 13px;
  color: var(--muted);
}
.card__title {
  font-size: 18px;
}
.card__body {
  font-family: var(--font-mono);
  font-size: 13px;
  color: var(--muted);
}

/* Pasos */
.steps {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
}
.step {
  border: 1px solid var(--paper);
  padding: var(--space-3) var(--space-2);
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.step__num {
  font-family: var(--font-display);
  font-size: 34px;
  line-height: 1;
}
.step__title {
  font-size: 16px;
  color: var(--paper);
}
.step__body {
  font-family: var(--font-mono);
  font-size: 13px;
  color: var(--gray-2);
}

/* Descargas */
.downloads {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(210px, 1fr));
  gap: var(--space-2);
}
.download {
  border: 1px solid var(--ink);
  padding: var(--space-2);
  display: flex;
  align-items: center;
  gap: 14px;
}
.download:hover {
  box-shadow: var(--shadow);
  transform: translate(-2px, -2px);
  transition: transform 0.15s, box-shadow 0.15s;
}
.download:focus-visible {
  outline: 2px solid var(--ink);
  outline-offset: 2px;
}
/* Sin release registrada: se ve deshabilitado, no clicable. */
.download[aria-disabled='true'] {
  cursor: default;
}
.download[aria-disabled='true']:hover {
  box-shadow: none;
  transform: none;
}
.download[aria-disabled='true'] .download__cta {
  color: var(--muted);
}
.download[aria-disabled='true'] .download__tag {
  opacity: 0.5;
}
.download__tag {
  flex-shrink: 0;
  width: 44px;
  height: 44px;
  display: grid;
  place-items: center;
  border: 1px solid var(--ink);
  font-family: var(--font-display);
  font-size: 10px;
  text-transform: uppercase;
}
.download__info {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
}
.download__name {
  font-family: var(--font-display);
  font-size: 14px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.download__note {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.download__cta {
  margin-left: auto;
  flex-shrink: 0;
  font-family: var(--font-display);
  font-size: 10px;
  text-transform: uppercase;
  color: var(--muted);
  white-space: nowrap;
}

/* Planes */
.plans {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
}
.plan {
  border: 1px solid var(--paper);
  padding: var(--space-3) var(--space-2);
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.plan--muted {
  opacity: 0.85;
}
.plan--muted .plan__desc {
  color: var(--gray-2);
}
.plan__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.plan__name {
  font-size: 18px;
  color: var(--paper);
}
.plan__flag {
  font-family: var(--font-display);
  font-size: 10px;
  text-transform: uppercase;
  border: 1px solid var(--paper);
  padding: 2px 8px;
}
.plan__desc {
  font-family: var(--font-mono);
  font-size: 13px;
  color: var(--gray-2);
}
.plan__cta {
  /* Sección invertida (fondo papel claro): el btn base asume tinta clara. */
  margin-top: var(--space-1);
  align-self: flex-start;
  border-color: var(--paper);
  color: var(--paper);
}
.plan__cta:hover {
  background: var(--paper);
  color: var(--ink);
}

@media (max-width: 900px) {
  .hero__grid {
    grid-template-columns: 1fr;
    gap: var(--space-3);
  }
  .features,
  .steps,
  .plans {
    grid-template-columns: 1fr;
  }
}
</style>
