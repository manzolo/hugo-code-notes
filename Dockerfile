# Multi-stage build per produzione
FROM hugomods/hugo:go-0.150.0 AS builder

# Copia i file sorgente
COPY . /src
WORKDIR /src

# Build del sito
RUN hugo --minify --gc --environment production

# Stage finale con Nginx
FROM nginx:alpine AS production

# Copia la configurazione Nginx
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

# Copia il sito buildato dal builder stage
COPY --from=builder /src/public /usr/share/nginx/html

# Metadata
LABEL maintainer="Manzolo"
LABEL description="Hugo Blog - Production Ready"
LABEL version="1.0"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Esponi la porta 80
EXPOSE 80

# Comando di avvio
CMD ["nginx", "-g", "daemon off;"]