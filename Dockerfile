FROM node:23-alpine AS base

WORKDIR /app

FROM base AS deps

COPY package.json package-lock.json* ./

RUN npm i

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

FROM base AS runner

ENV NODE_ENV=production

ENV PORT=3000


RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE ${PORT}

CMD ["node", "server.js"]