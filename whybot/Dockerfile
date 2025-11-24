# Stage 1: Build frontend
FROM node:20 AS frontend-build
WORKDIR /app
COPY app ./app
WORKDIR /app/app
COPY app/package*.json ./
RUN npm install && npm run build

# Stage 2: Build backend
FROM node:20 AS backend-build
WORKDIR /app
COPY server/package.json ./server/package.json
WORKDIR /app/server
COPY server/package*.json ./
RUN npm install

# Stage 3: Final image
FROM node:20-slim
RUN apt-get update && apt-get install -y openssl
WORKDIR /app

# Copy built frontend from frontend-build stage
COPY --from=frontend-build /app/app/dist ./app/dist

WORKDIR /app/app
COPY app/package*.json ./
RUN npm install

WORKDIR /app/server
COPY server/package*.json ./
RUN npm install

# Source code is mounted via docker-compose, so no COPY for app/server
ENV NODE_ENV=development
ENV PORT=6823
ENV OLLAMA_HOST=${OLLAMA_HOST:-http://192.168.27.10:11434}
ENV OLLAMA_MODEL=${OLLAMA_MODEL:-deepseek-r1:8b}
WORKDIR /app/server
EXPOSE 6823
EXPOSE 3003
CMD ["sh", "-c", "npx prisma generate && npx prisma migrate dev --name add_example_table && npm run dev"]
