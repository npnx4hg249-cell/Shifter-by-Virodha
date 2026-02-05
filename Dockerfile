# CC Shifter - Docker Image
# Multi-stage build for optimized production image

# Stage 1: Build client
FROM node:20-alpine AS client-builder

WORKDIR /app/client

# Copy client package files
COPY client/package*.json ./

# Install client dependencies
RUN npm ci

# Copy client source
COPY client/ ./

# Build client
RUN npm run build

# Stage 2: Production server
FROM node:20-alpine AS production

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy server package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy server source
COPY server/ ./server/

# Copy built client from builder stage
COPY --from=client-builder /app/client/dist ./client/dist

# Create data directory with proper permissions
RUN mkdir -p /app/server/data/storage && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3001

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001/api/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start server with dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server/index.js"]
