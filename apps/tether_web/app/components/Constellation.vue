<script setup lang="ts">
// Fondo de constelación one-bit: nodos y líneas en tinta pura, con señales
// (cuadrado hueco) que viajan por las aristas — el "hilo" que conecta tus equipos.
const canvasRef = ref<HTMLCanvasElement | null>(null)

const NODES = [
  [0.04, 0.18], [0.16, 0.08], [0.32, 0.2], [0.5, 0.1], [0.68, 0.22], [0.86, 0.1],
  [0.96, 0.32], [0.08, 0.5], [0.26, 0.42], [0.47, 0.56], [0.66, 0.45], [0.84, 0.55],
  [0.15, 0.78], [0.37, 0.8], [0.6, 0.84], [0.88, 0.88], [0.05, 0.95],
] as const

const EDGES = [
  [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [7, 8], [8, 9], [9, 10], [10, 11],
  [12, 13], [13, 14], [14, 15], [0, 7], [2, 8], [3, 9], [4, 10], [5, 11], [8, 12],
  [9, 13], [10, 14], [11, 15], [12, 16],
] as const

// Dos señales desfasadas medio recorrido, en tramos distintos del ciclo.
const SIGNALS = [
  { offset: 0 },
  { offset: Math.floor(EDGES.length / 2) + 0.5 },
]

function drawSignal(ctx: CanvasRenderingContext2D, pts: { x: number, y: number }[], pos: number, segCount: number) {
  // Módulo siempre positivo: en el primer frame el timestamp de rAF puede ser < start,
  // dando `pos` ligeramente negativo → `-1 % n` = -1 → EDGES[-1] undefined y crash.
  const seg = ((Math.floor(pos) % segCount) + segCount) % segCount
  const local = pos - Math.floor(pos)
  const a = pts[EDGES[seg]![0]!]!
  const b = pts[EDGES[seg]![1]!]!
  const sx = a.x + (b.x - a.x) * local
  const sy = a.y + (b.y - a.y) * local
  ctx.strokeRect(sx - 4, sy - 4, 8, 8)
}

onMounted(() => {
  const canvas = canvasRef.value
  if (!canvas) return
  const ctx = canvas.getContext('2d')
  if (!ctx) return

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  let raf = 0
  const start = performance.now()

  function draw(now: number) {
    const w = canvas!.clientWidth
    const h = canvas!.clientHeight
    const dpr = window.devicePixelRatio || 1
    if (canvas!.width !== w * dpr || canvas!.height !== h * dpr) {
      canvas!.width = w * dpr
      canvas!.height = h * dpr
    }
    ctx!.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx!.clearRect(0, 0, w, h)

    const t = reducedMotion ? 0.6 : (now - start) / 3200
    const color = getComputedStyle(document.documentElement).getPropertyValue('--ink').trim()

    const pts = NODES.map(([x, y]) => ({ x: x * w, y: y * h }))

    ctx!.strokeStyle = color
    ctx!.fillStyle = color
    ctx!.globalAlpha = 0.16
    ctx!.lineWidth = 1
    for (const [a, b] of EDGES) {
      ctx!.beginPath()
      ctx!.moveTo(pts[a]!.x, pts[a]!.y)
      ctx!.lineTo(pts[b]!.x, pts[b]!.y)
      ctx!.stroke()
    }

    // Nodos: pulso sutil — uno de cada cuatro respira en escala discreta.
    for (let i = 0; i < pts.length; i++) {
      const pulse = reducedMotion ? 0 : Math.sin(t * Math.PI / 3 + i)
      const size = pulse > 0.85 ? 3 : 2
      const alpha = pulse > 0.85 ? 0.7 : 0.45
      ctx!.globalAlpha = alpha
      ctx!.fillRect(pts[i]!.x - size / 2, pts[i]!.y - size / 2, size, size)
    }

    // Señales viajando las aristas.
    const segCount = EDGES.length
    ctx!.globalAlpha = 1
    for (const signal of SIGNALS) {
      drawSignal(ctx!, pts, t * segCount + signal.offset, segCount)
    }

    if (!reducedMotion) raf = requestAnimationFrame(draw)
  }

  raf = requestAnimationFrame(draw)

  onUnmounted(() => cancelAnimationFrame(raf))
})
</script>

<template>
  <canvas ref="canvasRef" class="constellation" aria-hidden="true" />
</template>

<style scoped>
.constellation {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  opacity: 0.6;
}
</style>
