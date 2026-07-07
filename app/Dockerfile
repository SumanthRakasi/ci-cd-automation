# Stage 1: install only production dependencies.
FROM node:20-alpine AS deps
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2: the actual runtime image — no devDependencies, no build tools.
FROM node:20-alpine
WORKDIR /usr/src/app

COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .

ENV NODE_ENV=production
EXPOSE 3000

# Same endpoint the deploy script will use to judge readiness — Docker itself
# can also use this to mark the container unhealthy if the app wedges.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Don't run as root inside the container.
USER node

CMD ["node", "server.js"]
