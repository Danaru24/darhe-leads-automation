# Bitácora de IA

## Herramientas usadas
| Herramienta | Uso |
|---|---|
| **Google Gemini** (`gemini-3.5-flash-lite`, temperatura 0.1) dentro de n8n | Calificar cada lead leyendo el campo `mensaje` y redactar el resumen para Christian. |
| **Asistentes de código (ChatGPT / Gemini / Antigravity)** | Diseño de arquitectura, nodos Code en JS, Docker/Compose, entrypoint y documentación. |
| **n8n 2.x** | Orquestación: AI Agent, Structured Output Parser, Convert/Write File y Postgres. |

**Criterio:** lo determinista (limpieza, teléfonos, emails, duplicados) va en JavaScript, porque es auditable y repetible. Lo semántico (intención, idioma, competidor, empleados mencionados en texto) va con el LLM.

---

## Prompts clave

### 1. Diseño de la solución (asistente de código)
> "Tengo 15 leads en CSV con teléfonos en formatos distintos, correos rotos, segmentos mal escritos y duplicados. Diseña un flujo n8n que separe limpieza determinista en JavaScript de la calificación con LLM. Los duplicados se detectan por teléfono normalizado y se fusionan conservando el mejor dato por columna (field-level survivorship)."

### 2. System prompt del clasificador (AI Agent en n8n)
> "Eres el Clasificador de Leads de DARHE. Evalúas UN lead a la vez y devuelves únicamente un JSON con 6 campos: num_empleados_estimado (number), calificacion ("A", "B", "C" o "Descartado"), razon (1 línea), siguiente_accion, requiere_revision (boolean) y motivo_revision… Si el dato de empleados no está especificado, venía corrupto (ej. "abc") o es menor a 20, PERO el mensaje menciona una cantidad mayor, usa el número del mensaje y pon requiere_revision = true…"

(Versión completa en el nodo `AI Agent` del [workflow](../workflows/workflow_n8n_darhe.json).)

### 3. User prompt por lead
> "Analiza este único lead y devuelve tu dictamen en el formato JSON requerido: ID, Nombre, Empresa, Email (o SIN EMAIL), Teléfono, Segmento, Empleados reportados en columna (o 'No especificado / Corrupto (abc)'), Fuente, Duplicado fusionado de ID, Mensaje del prospecto."

### 4. Resumen para Christian
> "Genera el RESUMEN EJECUTIVO PARA CHRISTIAN de máximo 1 página en TEXTO PLANO (sin Markdown, sin ** ni #), listo para el cuerpo de un correo, en lenguaje comercial y cero técnico: 1) panorama de entrada, 2) a quién llamar primero hoy (los A y el referido de 250 empleados) con teléfono, dolor y abordaje, 3) casos que requieren su validación y qué debe decidir, 4) seguimiento del resto."

### 5. Infraestructura idempotente (asistente de código)
> "El contenedor crea un workflow nuevo cada vez que lo levanto. Haz que el entrypoint cree la base y la tabla y que importe el workflow solo si no existen."

---

## Lo que la IA hizo mal y cómo lo detecté

### 1. No vio el BOM `\ufeff` del CSV
**Qué pasó:** el código generado leía `row.id`, pero la primera columna del CSV se llama en realidad `"\ufeffid"` (BOM UTF-8 invisible). Por la ruta Manual todos los IDs salían vacíos o `NaN`; por el webhook funcionaba.
**Cómo lo detecté:** en la salida del nodo `Extraer Filas CSV` en n8n, la llave se veía como `id` pero `$json.id` era `undefined`. Al imprimir `Object.keys()` apareció el carácter.
**Corrección:** el nodo `1. Unificar Entrada` limpia `^\ufeff` de todas las llaves, así ambas rutas producen datos idénticos.

### 2. Survivorship incorrecto en Ana Torres (ID 4 vs 14)
**Qué pasó:** la primera versión del merge se quedaba con el registro maestro completo (ID 4). Así sobrevivía el email roto `ana.torres@pilar` y `num_empleados` vacío, y el lead acababa en B "sin contacto válido", cuando el ID 14 traía `ana.torres@pilar.example` y 45 empleados.
**Cómo lo detecté:** comparando a mano el CSV de entrada contra el de salida; Ana pedía demo y describía un dolor claro, así que debía ser A.
**Corrección:** fusión campo por campo. El email inválido se descarta antes del merge, el primer email válido gana y los empleados se toman del duplicado si el maestro no los tiene. Resultado: ID 4, `duplicado_de: 14`, calificación A.

### 3. Calificar los 13 leads en un solo prompt
**Qué pasó:** al mandar el lote completo, el LLM omitía leads, mezclaba razones entre registros y el Structured Output Parser fallaba con el esquema de arreglo, o con `null` en `num_empleados_estimado`.
**Cómo lo detecté:** la salida traía menos de 13 objetos y errores de parseo en n8n.
**Corrección:** evaluación **1 a 1** (un item por ejecución del agente), parser en modo **Generate from JSON Example** con solo los 6 campos que decide la IA, y `0` en vez de `null` para empleados desconocidos. Un nodo Code une después el dictamen con los datos limpios.

