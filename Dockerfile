FROM docker.n8n.io/n8nio/n8n:latest

LABEL maintainer="Ulises Dan Arroyo Rojas"
LABEL project="DARHE Leads Automation Pipeline"
LABEL description="Contenedor n8n pre-configurado para ingesta, deduplicación y calificación de leads con IA"

USER root

# Crear directorios de trabajo y asegurar permisos para el usuario node (UID 1000)
RUN mkdir -p /data/input /data/output /workflows /scripts /sql && \
    chown -R node:node /data /workflows /scripts /sql

# Copiar el dataset semilla y los workflows dentro de la imagen (para que funcione incluso sin montar volúmenes)
COPY --chown=node:node ./data/input/leads_test_darhe.csv /data/input/leads_test_darhe.csv
COPY --chown=node:node ./workflows/ /workflows/
# Script de inicialización de Postgres (usa el driver pg incluido en n8n) y esquema SQL
COPY --chown=node:node ./scripts/ /scripts/
COPY --chown=node:node ./sql/ /sql/
COPY --chown=node:node ./entrypoint.sh /entrypoint.sh
# Normaliza fin de línea por si el repo se clona en Windows con CRLF
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

# Variables por defecto para permitir lectura/escritura en /data
ENV N8N_RESTRICT_FILE_ACCESS_TO=/data \
    N8N_DEFAULT_BINARY_DATA_MODE=filesystem \
    GENERIC_TIMEZONE=America/Mexico_City \
    TZ=America/Mexico_City

# Volver a usuario sin privilegios (Best Practice de Seguridad en Contenedores)
USER node

EXPOSE 5677

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=5 \
    CMD wget --spider -q http://localhost:5677/healthz || exit 1

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]