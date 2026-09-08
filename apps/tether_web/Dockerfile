# =============================================================================
# Stage build: generar el sitio estático con Astro
# =============================================================================
FROM node:24-alpine AS build
RUN npm install -g pnpm@10.12.1
WORKDIR /app
# Vacío = mismo-origen vía proxy nginx (/releases → backend:3100).
# Solo definir si la landing debe apuntar directo al API (evita CORS si es externo).
ARG PUBLIC_API_BASE_URL=""
ENV PUBLIC_API_BASE_URL=$PUBLIC_API_BASE_URL
COPY package.json ./
RUN pnpm install
COPY . .
RUN pnpm build

# =============================================================================
# Stage runtime: servir con nginx
# =============================================================================
FROM nginx:1.27-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
