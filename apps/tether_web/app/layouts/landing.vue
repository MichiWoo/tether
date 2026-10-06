<script setup lang="ts">
import Mark from '~/components/Mark.vue'

const NAV = [
  { href: '#funciones', label: 'Funciones' },
  { href: '#como-funciona', label: 'Cómo funciona' },
  { href: '#descargas', label: 'Descargas' },
  { href: '#planes', label: 'Planes' },
]
</script>

<template>
  <div class="app-shell">
    <a class="skip-link" href="#contenido">Saltar al contenido</a>

    <header class="topbar">
      <div class="wrap topbar__inner">
        <NuxtLink to="/" class="brand">
          <Mark :size="26" />
          <span class="brand__name">Tether</span>
        </NuxtLink>

        <nav class="topnav" aria-label="Principal">
          <a v-for="item in NAV" :key="item.href" class="nav-link" :href="item.href">{{ item.label }}</a>
        </nav>

        <a class="btn btn--primary topbar__cta" href="#descargas">Descargar</a>

        <UDrawer
          title="Menú"
          side="top"
          :ui="{ content: 'bg-[var(--paper)] border-y-2 border-[var(--ink)] rounded-none shadow-1bit' }"
        >
          <UButton
            class="burger burger--drawer"
            icon="i-lucide-menu"
            variant="ghost"
            color="neutral"
            aria-label="Abrir menú"
          />
          <template #body>
            <nav class="mobile-nav" aria-label="Móvil">
              <a v-for="item in NAV" :key="item.href" class="nav-link" :href="item.href">{{ item.label }}</a>
              <a class="btn btn--primary btn--block" href="#descargas">Descargar</a>
            </nav>
          </template>
        </UDrawer>
      </div>
    </header>

    <main id="contenido">
      <slot />
    </main>

    <footer class="footer">
      <div class="wrap footer__inner">
        <span class="footer__brand"><Mark :size="20" /> Tether</span>
        <span class="footer__copy">© {{ new Date().getFullYear() }} Tether. Conecta tus dispositivos.</span>
        <a class="footer__link" href="#descargas">Descargar</a>
      </div>
    </footer>
  </div>
</template>

<style scoped>
/* Skip-link: oculto hasta recibir foco por teclado. */
.skip-link {
  position: absolute;
  left: -9999px;
  top: 0;
  z-index: 100;
  background: var(--ink);
  color: var(--paper);
  font-family: var(--font-display);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 10px 14px;
}
.skip-link:focus-visible {
  left: var(--space-2);
  top: var(--space-2);
  outline: 2px solid var(--paper);
  outline-offset: 2px;
}
.topbar {
  position: sticky;
  top: 0;
  z-index: 50;
  background: var(--paper);
  border-bottom: 1px solid var(--ink);
}
.topbar__inner {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  height: 60px;
}
.brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: var(--ink);
}
.brand__name {
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 15px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.topnav {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-left: var(--space-3);
}
.topbar__cta {
  margin-left: auto;
}
.burger {
  display: none;
  margin-left: auto;
}
.burger--drawer {
  display: none;
  border: 1px solid var(--ink);
}
.mobile-nav {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.mobile-nav .nav-link {
  display: block;
}
.footer {
  border-top: 1px solid var(--ink);
  padding-block: var(--space-3);
}
.footer__inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
  flex-wrap: wrap;
}
.footer__brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-family: var(--font-display);
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.footer__copy {
  font-family: var(--font-mono);
  font-size: 12px;
  color: var(--muted);
}
.footer__link {
  font-family: var(--font-display);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 10px 14px;
  border: 1px solid var(--ink);
}
.footer__link:hover {
  background: var(--ink);
  color: var(--paper);
}
.footer__link:focus-visible {
  outline: 2px solid var(--ink);
  outline-offset: 2px;
}

@media (max-width: 760px) {
  .topnav,
  .topbar__cta {
    display: none;
  }
  .burger--drawer {
    display: inline-flex;
  }
}
</style>
