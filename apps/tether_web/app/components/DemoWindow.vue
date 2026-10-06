<script setup lang="ts">
// Ventana simulada de Tether: el producto haciendo su trabajo en el hero.
// Clipboard y transferencias llegan en bucle (respeta prefers-reduced-motion:
// si hay, queda el estado estático por defecto).
const CLIPBOARD = [
  { text: 'https://tether.app/download' },
  { text: '¿reunión a las 17:00?' },
  { text: '#282a36 · rgb(40 42 54)' },
  { text: 'ssh michi@10.0.0.12 -p 2222' },
]
const DEVICES = ['MacBook Pro', 'iPhone 16', 'PC Escritorio', 'iPad Air']
const CLIP_PERIOD = 4200

const FILES = [
  { name: 'foto.png', size: '2.4 MB' },
  { name: 'presentación.pdf', size: '8.1 MB' },
  { name: 'grabación.wav', size: '1.2 MB' },
]
const STEP_PERCENT = 4
const STEP_MS = 130 // ~3.2s por archivo
const HOLD_AT_FULL_MS = 1100

const clipIdx = ref(0)
const device = ref(DEVICES[0]!)
const arriveKey = ref(0)

const fileIdx = ref(0)
const filePct = ref(78)
const file = computed(() => FILES[fileIdx.value]!)

let clipTimer: ReturnType<typeof setInterval> | undefined
let transferTimer: ReturnType<typeof setTimeout> | undefined

function nextClipboardItem() {
  clipIdx.value = (clipIdx.value + 1) % CLIPBOARD.length
  device.value = DEVICES[clipIdx.value % DEVICES.length]!
  arriveKey.value++
}

function tickTransfer() {
  const step = Math.min(100, filePct.value + STEP_PERCENT)
  filePct.value = step
  if (step >= 100) {
    transferTimer = setTimeout(() => {
      fileIdx.value = (fileIdx.value + 1) % FILES.length
      filePct.value = 0
      tickTransfer()
    }, HOLD_AT_FULL_MS)
    return
  }
  transferTimer = setTimeout(tickTransfer, STEP_MS)
}

onMounted(() => {
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (reduced) return

  clipTimer = setInterval(nextClipboardItem, CLIP_PERIOD)
  transferTimer = setTimeout(() => {
    filePct.value = 0
    tickTransfer()
  }, CLIP_PERIOD)

  document.addEventListener('visibilitychange', onVisibility)
})

function onVisibility() {
  if (document.hidden) {
    clearInterval(clipTimer)
    clearTimeout(transferTimer)
    clipTimer = undefined
    transferTimer = undefined
  } else {
    if (!clipTimer) clipTimer = setInterval(nextClipboardItem, CLIP_PERIOD)
    if (!transferTimer) tickTransfer()
  }
}

onUnmounted(() => {
  clearInterval(clipTimer)
  clearTimeout(transferTimer)
  document.removeEventListener('visibilitychange', onVisibility)
})
</script>

<template>
  <div class="win">
    <div class="win__title">
      <span class="win__title-mark">
        <span class="sq filled" />
        <span class="ln" />
        <span class="sq hollow" />
      </span>
      <span class="win__name">Tether</span>
      <span class="win__status">en línea</span>
    </div>

    <div class="win__body">
      <dl class="row">
        <dt class="row__label">Dispositivos</dt>
        <dd class="row__value">{{ DEVICES.length }} en línea</dd>
      </dl>

      <div class="paper">
        <div class="paper__head">
          <span class="paper__title">Portapapeles</span>
          <span class="paper__meta">de {{ device }}</span>
        </div>
        <div :key="arriveKey" class="paper__item arrive">
          <span class="dot dot--filled" />
          <code>{{ CLIPBOARD[clipIdx]?.text }}</code>
        </div>
      </div>

      <div class="transfer">
        <span class="transfer__icon">
          <span class="doc" />
        </span>
        <div class="transfer__body">
          <div class="transfer__meta">
            <span>{{ file.name }} · {{ file.size }}</span>
            <span>{{ Math.min(filePct, 100) }}%</span>
          </div>
          <div class="transfer__track">
            <div class="transfer__fill" :style="{ width: `${Math.min(filePct, 100)}%` }" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.win {
  border: 2px solid var(--ink);
  background: var(--paper);
  box-shadow: 4px 4px 0 var(--ink);
  max-width: 460px;
  font-family: var(--font-mono);
}
.win__title {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background: var(--ink);
  color: var(--paper);
  font-family: var(--font-display);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.win__title-mark {
  display: inline-flex;
  align-items: center;
  gap: 3px;
}
.win__title-mark .sq {
  width: 10px;
  height: 10px;
}
.win__title-mark .filled {
  background: var(--paper);
}
.win__title-mark .ln {
  width: 6px;
  height: 1px;
  background: var(--paper);
}
.win__title-mark .hollow {
  border: 1px solid var(--paper);
}
.win__status {
  margin-left: auto;
  font-family: var(--font-mono);
  font-size: 10px;
  text-transform: lowercase;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
/* Latido discreto del indicador (1-bit: on/off, no fade). */
.win__status::before {
  content: '';
  width: 6px;
  height: 6px;
  background: var(--paper);
}
@media (prefers-reduced-motion: no-preference) {
  .win__status::before {
    animation: beat 2.4s steps(1) infinite;
  }
  @keyframes beat {
    0%, 100% { opacity: 1; }
    92% { opacity: 0.35; }
    96% { opacity: 1; }
  }
}

.win__body {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 18px;
}

.row {
  display: flex;
  justify-content: space-between;
  margin: 0;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--ink);
}
.row__label {
  font-family: var(--font-display);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.row__value {
  font-size: 12px;
  color: var(--muted);
}

.paper {
  border: 1px solid var(--ink);
}
.paper__head {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  padding: 8px 12px;
  border-bottom: 1px solid var(--ink);
  background: var(--gray-2);
}
.paper__title {
  font-family: var(--font-display);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.paper__meta {
  font-size: 11px;
  color: var(--muted);
}
.paper__item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px;
  font-size: 13px;
  overflow: hidden;
}
.paper__item code {
  font-family: var(--font-mono);
  color: var(--ink);
  white-space: nowrap;
}
/* Llegada del ítem: entra en pasos discretos, coherente con 1-bit. */
.paper__item.arrive code {
  animation: arrive 0.48s steps(4, end);
}
@keyframes arrive {
  from {
    transform: translateY(-8px);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}

.dot {
  width: 8px;
  height: 8px;
  flex-shrink: 0;
}
.dot--filled {
  background: var(--ink);
}

.transfer {
  display: flex;
  align-items: center;
  gap: 12px;
  border: 1px solid var(--ink);
  padding: 12px;
}
.transfer__icon {
  width: 34px;
  height: 40px;
  flex-shrink: 0;
  border: 1px solid var(--ink);
  display: grid;
  place-items: center;
}
.doc {
  width: 14px;
  height: 18px;
  border: 1px solid var(--ink);
  position: relative;
}
.doc::after {
  content: '';
  position: absolute;
  inset: 3px;
  background-image: repeating-linear-gradient(
    var(--ink) 0 1px,
    transparent 1px 3px
  );
}
.transfer__body {
  flex: 1;
  min-width: 0;
}
.transfer__meta {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  color: var(--muted);
  margin-bottom: 6px;
}
.transfer__track {
  height: 10px;
  border: 1px solid var(--ink);
  padding: 1px;
}
.transfer__fill {
  height: 100%;
  background: var(--ink);
  transition: width 0.12s steps(4);
}
</style>
