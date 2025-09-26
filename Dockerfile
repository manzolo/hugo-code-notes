# Simple runtime container with auto-import
FROM nginx:alpine

# Copy nginx configuration
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

# Add entrypoint script for auto-import
COPY conf/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://localhost || exit 1

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]