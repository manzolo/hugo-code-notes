# Multi-stage build for production
FROM hugomods/hugo:go-0.150.0 AS builder

# Copy source files
COPY . /src
WORKDIR /src

# Build the site
RUN hugo --minify --gc --environment production

# Final stage with Nginx
FROM nginx:alpine AS production

# Copy nginx configuration
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built site from builder stage
COPY --from=builder /src/public /usr/share/nginx/html

# Metadata
LABEL maintainer="Manzolo"
LABEL description="Hugo Blog - Production Ready"
LABEL version="1.0"

# Health check using BusyBox wget (alpine version)
# Note: BusyBox wget doesn't support --spider, use -O /dev/null instead
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://localhost || exit 1

# Expose port 80
EXPOSE 80

# Start command
CMD ["nginx", "-g", "daemon off;"]