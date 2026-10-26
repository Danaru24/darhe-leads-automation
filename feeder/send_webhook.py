import csv
import json
import os
import time
import urllib.request
import urllib.error

WEBHOOK_URL = os.getenv("WEBHOOK_URL", "http://darhe-n8n-engine:5677/webhook/darhe-leads")
CSV_PATH = os.getenv("CSV_PATH", "/data/input/leads_test_darhe.csv")

def main():
    print(f"[Feeder] Leyendo leads desde {CSV_PATH}...")
    with open(CSV_PATH, mode="r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        leads = list(reader)

    payload = json.dumps({"leads": leads}).encode("utf-8")
    req = urllib.request.Request(
        WEBHOOK_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    for intento in range(1, 5):
        try:
            print(f"[Feeder] Enviando {len(leads)} leads al Webhook ({WEBHOOK_URL}) - Intento {intento}...")
            with urllib.request.urlopen(req, timeout=30) as response:
                body = json.loads(response.read().decode("utf-8"))
                print("\n✅ [Feeder] Respuesta exitosa de n8n:")
                print(f"   - Status: {body.get('status')}")
                print(f"   - Leads únicos procesados: {body.get('total_leads_unicos')}")
                print(f"   - Archivos creados por n8n: {body.get('archivos_escritos')}")
                return
        except (urllib.error.URLError, urllib.error.HTTPError) as e:
            print(f"[Feeder] Esperando a que el Webhook de n8n esté listo ({e})...")
            time.sleep(3)

    raise RuntimeError("No se pudo conectar al Webhook de n8n tras varios intentos.")

if __name__ == "__main__":
    main()