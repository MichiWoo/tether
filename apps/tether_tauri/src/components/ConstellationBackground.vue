<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";

// Fondo de constelación one-bit: nodos y líneas en tinta pura, con una señal
// (cuadrado hueco) que viaja por las aristas — el "hilo" que conecta tus equipos.

const canvas = ref<HTMLCanvasElement | null>(null);
let raf = 0;
let start = 0;
let reducedMotion = false;

const NODES: Array<[number, number]> = [
  [0.06, 0.2], [0.18, 0.08], [0.34, 0.22], [0.52, 0.1], [0.7, 0.24], [0.88, 0.12],
  [0.96, 0.34], [0.1, 0.52], [0.28, 0.42], [0.48, 0.58], [0.66, 0.46], [0.84, 0.56],
  [0.16, 0.78], [0.38, 0.8], [0.6, 0.84], [0.86, 0.88], [0.06, 0.94],
];

const EDGES: Array<[number, number]> = [
  [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [7, 8], [8, 9], [9, 10], [10, 11],
  [12, 13], [13, 14], [14, 15], [0, 7], [2, 8], [3, 9], [4, 10], [5, 11], [8, 12],
  [9, 13], [10, 14], [11, 15], [12, 16],
];

function ink(css: CSSStyleDeclaration): string {
  const m = css.getPropertyValue("--ink").trim().match(/\d+/g);
  return m ? `rgb(${m[0]}, ${m[1]}, ${m[2]})` : "rgb(0,0,0)";
}

function draw(now: number = performance.now()) {
  const el = canvas.value;
  if (!el) return;
  const ctx = el.getContext("2d");
  if (!ctx) return;

  const dpr = window.devicePixelRatio || 1;
  const w = el.clientWidth;
  const h = el.clientHeight;
  if (el.width !== w * dpr || el.height !== h * dpr) {
    el.width = w * dpr;
    el.height = h * dpr;
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);

  const t = reducedMotion ? 0.6 : (now - start) / 3200;
  const c = ink(getComputedStyle(document.documentElement));

  const pts = NODES.map(([x, y]) => ({ x: x * w, y: y * h }));

  // Líneas
  ctx.strokeStyle = c;
  ctx.globalAlpha = 0.18;
  ctx.lineWidth = 1;
  for (const [a, b] of EDGES) {
    ctx.beginPath();
    ctx.moveTo(pts[a].x, pts[a].y);
    ctx.lineTo(pts[b].x, pts[b].y);
    ctx.stroke();
  }

  // Nodos (cuadrados de tinta)
  ctx.globalAlpha = 0.5;
  for (const p of pts) {
    ctx.fillRect(p.x - 1, p.y - 1, 2, 2);
  }

  // Señal viajera (cuadrado hueco)
  const segCount = EDGES.length;
  if (segCount === 0) {
    if (!reducedMotion) raf = requestAnimationFrame(draw);
    return;
  }
  const pos = t * segCount;
  if (!Number.isFinite(pos)) {
    if (!reducedMotion) raf = requestAnimationFrame(draw);
    return;
  }
  const seg = ((Math.floor(pos) % segCount) + segCount) % segCount;
  const local = pos - Math.floor(pos);
  const edge = EDGES[seg];
  if (!edge) {
    if (!reducedMotion) raf = requestAnimationFrame(draw);
    return;
  }
  const pa = pts[edge[0]];
  const pb = pts[edge[1]];
  if (!pa || !pb) {
    if (!reducedMotion) raf = requestAnimationFrame(draw);
    return;
  }
  const sx = pa.x + (pb.x - pa.x) * local;
  const sy = pa.y + (pb.y - pa.y) * local;
  ctx.globalAlpha = 1;
  ctx.strokeRect(sx - 4, sy - 4, 8, 8);

  ctx.globalAlpha = 1;

  if (!reducedMotion) raf = requestAnimationFrame(draw);
}

onMounted(() => {
  reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  start = performance.now();
  raf = requestAnimationFrame(draw);
});

onBeforeUnmount(() => cancelAnimationFrame(raf));
</script>

<template>
  <canvas ref="canvas" class="pointer-events-none absolute inset-0 h-full w-full" aria-hidden="true" />
</template>
