-- Se ejecuta automáticamente al levantar el contenedor darhe-postgres-db
CREATE TABLE IF NOT EXISTS public.leads_calificados (
    id INTEGER PRIMARY KEY,
    duplicado_de VARCHAR(50),
    fecha VARCHAR(20),  
    nombre VARCHAR(150) NOT NULL,
    empresa VARCHAR(200),
    email VARCHAR(255),
    telefono VARCHAR(30),
    segmento VARCHAR(50) NOT NULL,
    num_empleados_reportado INTEGER,
    num_empleados_estimado INTEGER,
    ciudad VARCHAR(100),
    fuente VARCHAR(150),
    mensaje TEXT,
    calificacion VARCHAR(20) NOT NULL CHECK (calificacion IN ('A', 'B', 'C', 'Descartado')),
    razon TEXT NOT NULL,
    siguiente_accion TEXT NOT NULL,
    requiere_revision BOOLEAN DEFAULT FALSE NOT NULL,
    motivo_revision TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_leads_calificacion ON public.leads_calificados(calificacion);
CREATE INDEX IF NOT EXISTS idx_leads_revision ON public.leads_calificados(requiere_revision) WHERE requiere_revision = TRUE;
CREATE INDEX IF NOT EXISTS idx_leads_telefono ON public.leads_calificados(telefono);