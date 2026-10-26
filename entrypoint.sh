#!/bin/sh
# Entrypoint DARHE: prepara Postgres, credenciales y workflow UNA sola vez y arranca n8n.
# Todo es idempotente: reiniciar el contenedor no duplica tablas ni workflows.
set -e

N8N_MODULES=/usr/local/lib/node_modules/n8n/node_modules

# ---------------------------------------------------------------
# 1) Base de datos + tabla public.leads_calificados (solo si no existen)
# ---------------------------------------------------------------
if [ "$DB_TYPE" = "postgresdb" ]; then
    echo "=== [DARHE Init] 1/3 Verificando base de datos y tabla en Postgres ==="
    NODE_PATH="$N8N_MODULES" node /scripts/init-db.js
else
    echo "=== [DARHE Init] 1/3 Sin Postgres (modo autónomo SQLite): se omite la tabla leads_calificados ==="
fi

# ---------------------------------------------------------------
# 2) Credenciales con ID fijo (import con mismo ID = actualiza, no duplica)
# ---------------------------------------------------------------
echo "=== [DARHE Init] 2/3 Registrando credenciales ==="
CREDS=/tmp/darhe_credentials.json
NODE_PATH="$N8N_MODULES" node -e '
const e = process.env, c = [];
if (e.DB_TYPE === "postgresdb") c.push({
  id: "darhePostgresLocal", name: "DARHE Postgres (local)", type: "postgres",
  data: { host: e.DB_POSTGRESDB_HOST, port: Number(e.DB_POSTGRESDB_PORT || 5432),
          database: e.DB_POSTGRESDB_DATABASE, user: e.DB_POSTGRESDB_USER,
          password: e.DB_POSTGRESDB_PASSWORD, ssl: "disable" } });
if (e.GEMINI_API_KEY) c.push({
  id: "darheGeminiApi", name: "DARHE Gemini API", type: "googlePalmApi",
  data: { host: "https://generativelanguage.googleapis.com", apiKey: e.GEMINI_API_KEY } });
require("fs").writeFileSync(process.argv[1], JSON.stringify(c));
console.log("-> Credenciales a registrar:", c.map(x => x.name).join(", ") || "ninguna");
' "$CREDS"
if [ "$(cat "$CREDS")" != "[]" ]; then
    n8n import:credentials --input="$CREDS" || echo "!! No se pudieron importar credenciales"
fi
rm -f "$CREDS"

# ---------------------------------------------------------------
# 3) Workflows: se importan SOLO si su ID aún no existe en n8n
# ---------------------------------------------------------------
echo "=== [DARHE Init] 3/3 Verificando workflows en /workflows ==="
if ls /workflows/*.json >/dev/null 2>&1; then
    EXISTENTES=$(n8n list:workflow 2>/dev/null | cut -d'|' -f1)
    for wf in /workflows/*.json; do
        WF_ID=$(node -e 'try{process.stdout.write(require(process.argv[1]).id||"")}catch(e){}' "$wf")
        if [ -z "$WF_ID" ]; then
            echo "!! $wf no tiene 'id'; se omite para no crear duplicados."
        elif echo "$EXISTENTES" | grep -qx "$WF_ID"; then
            echo "-> Workflow $WF_ID ya existe; no se reimporta (se conservan cambios hechos en la UI)."
        else
            echo "-> Importando workflow $WF_ID desde $wf"
            n8n import:workflow --input="$wf"
            n8n publish:workflow --id="$WF_ID" || echo "!! No se pudo publicar $WF_ID (revisa credenciales en la UI)"
        fi
    done
else
    echo "-> No hay workflows en /workflows."
fi

echo "=== [DARHE Init] Iniciando n8n en puerto ${N8N_PORT:-5677} ==="
exec n8n start