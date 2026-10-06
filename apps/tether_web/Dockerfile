# =============================================================================
# Stage build: generar el sitio estático con Nuxt (nuxt generate, SSG)
# El contexto de build es la raíz del repo (necesario para @tether/protocol).
# =============================================================================
FROM node:24-alpine AS build
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate
WORKDIR /app
# Vacío = mismo-origen vía proxy nginx (/releases → backend:3100).
# Solo definir si la landing debe apuntar directo al API (evita CORS si es externo).
ARG NUXT_PUBLIC_API_BASE_URL=""
ENV NUXT_PUBLIC_API_BASE_URL=$NUXT_PUBLIC_API_BASE_URL
# Manifests del workspace + paquete compartido (instalación reproducible).
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY shared/protocol/package.json shared/protocol/
COPY apps/tether_web/package.json apps/tether_web/
RUN pnpm install --filter @tether/web --filter @tether/protocol --no-frozen-lockfile
# Código: la web + el paquete compartido.
COPY shared/protocol shared/protocol
COPY apps/tether_web apps/tether_web
RUN pnpm --filter @tether/protocol build && pnpm --filter @tether/web build

# =============================================================================
# Stage runtime: servir con nginx
# =============================================================================
FROM nginx:1.27-alpine AS runtime
COPY apps/tether_web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/apps/tether_web/dist /usr/share/nginx/html
EXPOSE 80
