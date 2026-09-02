<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";

// Fondo de constelación: nodos conectados con una "señal" que viaja entre ellos.
// Portado del CustomPainter de la app Flutter (auth_screen.dart).

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

function colors(css: CSSStyleDeclaration) {
  const rgb = (v: string) => {
    const m = v.match(/[\d.]+/g);
    return m ? `rgba(${m[0]}, ${m[1]}, ${m[2]}, ALPHA)` : "rgba(255,255,255,ALPHA)";
  };
  return {
    line: rgb(css.getPropertyValue("--border")),
    primary: rgb(css.getPropertyValue("--primary")),
    secondary: rgb(css.getPropertyValue("--secondary")),
    accent: rgb(css.getPropertyValue("--accent")),
    info: rgb(css.getPropertyValue("--info")),
  };
}

function draw(now: number) {
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

  const t = reducedMotion ? 1 : (now - start) / 3000;
  const palette = colors(getComputedStyle(document.documentElement));

  const pts = NODES.map(([x, y]) => ({ x: x * w, y: y * h }));
  const nodeColors = [palette.primary, palette.secondary, palette.accent, palette.info];

  // Líneas
  ctx.strokeStyle = palette.line.replace("ALPHA", "0.7");
  ctx.lineWidth = 1;
  for (const [a, b] of EDGES) {
    ctx.beginPath();
    ctx.moveTo(pts[a].x, pts[a].y);
    ctx.lineTo(pts[b].x, pts[b].y);
    ctx.stroke();
  }

  // Nodos con pulso
  for (let i = 0; i < pts.length; i++) {
    const pulse = 0.5 + 0.5 * Math.sin(2 * Math.PI * (t + i * 0.13));
    const color = nodeColors[i % nodeColors.length];
    ctx.fillStyle = color.replace("ALPHA", String(0.3 + 0.45 * pulse));
    ctx.beginPath();
    ctx.arc(pts[i].x, pts[i].y, 1.6 + 1.4 * pulse, 0, Math.PI * 2);
    ctx.fill();
  }

  // Señal viajera
  const segCount = EDGES.length;
  const pos = t * segCount;
  const seg = Math.floor(pos) % segCount;
  const local = pos - Math.floor(pos);
  const a = pts[EDGES[seg][0]];
  const b = pts[EDGES[seg][1]];
  const sx = a.x + (b.x - a.x) * local;
  const sy = a.y + (b.y - a.y) * local;
  ctx.fillStyle = palette.accent.replace("ALPHA", "0.2");
  ctx.beginPath();
  ctx.arc(sx, sy, 7, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = palette.accent.replace("ALPHA", "1");
  ctx.beginPath();
  ctx.arc(sx, sy, 3, 0, Math.PI * 2);
  ctx.fill();

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
