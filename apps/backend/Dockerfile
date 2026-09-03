# =============================================================================
# Stage base: dependencias del monorepo (pnpm workspace)
# =============================================================================
FROM node:24-alpine AS base
RUN apk add --no-cache libc6-compat openssl python3 make g++ \
 && npm install -g pnpm@10.12.1
WORKDIR /app

# Manifests del workspace (pnpm necesita todos los package.json del lockfile)
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY apps/backend/package.json apps/backend/package.json
COPY apps/tether_tauri/package.json apps/tether_tauri/package.json
COPY apps/tether_web/package.json apps/tether_web/package.json
COPY shared/protocol/package.json shared/protocol/package.json
COPY shared/types/package.json shared/types/package.json
RUN pnpm install --frozen-lockfile

# =============================================================================
# Stage build: compilar shared packages, generar Prisma client y build NestJS
# =============================================================================
FROM base AS build
COPY apps/backend apps/backend
COPY shared/protocol shared/protocol
COPY shared/types shared/types
RUN pnpm --filter @tether/protocol build \
 && pnpm --filter @tether/types build \
 && pnpm --filter @tether/backend exec prisma generate \
 && pnpm --filter @tether/backend build
# Empaqueta el backend + dependencias de producción en un directorio autocontenido
RUN pnpm --filter @tether/backend deploy --prod --legacy /prod/backend

# =============================================================================
# Stage runtime: imagen mínima de producción
# =============================================================================
FROM node:24-alpine AS runtime
RUN apk add --no-cache libc6-compat \
 && addgroup -g 1001 -S nodejs \
 && adduser -S nodejs -u 1001
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=nodejs:nodejs /prod/backend ./
USER nodejs
EXPOSE 3100
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://localhost:3100/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/src/main.js"]
