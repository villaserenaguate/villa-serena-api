-- =====================================================================
-- V5 — Canales y sistema (OBJ-0C, docs/esquema-propuesto.md §3.10 y §3.11)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Canales externos con el hash SHA-256 (hexadecimal) de su clave
-- (AD-13; RN-CM-001). reservas.canal no tiene FK aquí: DIRECTO_WEB y
-- RECEPCION no son canales externos.
-- ---------------------------------------------------------------------
CREATE TABLE canales (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo     VARCHAR(15) NOT NULL,
    nombre     VARCHAR(60) NOT NULL,
    clave_hash VARCHAR(64) NOT NULL,
    CONSTRAINT uq_canales_codigo UNIQUE (codigo),
    CONSTRAINT ck_canales_codigo CHECK (codigo IN ('BOOKING', 'EXPEDIA')),
    CONSTRAINT ck_canales_clave_hash CHECK (clave_hash ~ '^[0-9a-f]{64}$')
);

-- ---------------------------------------------------------------------
-- Historial de cambios de estado (documento 07 RG-EST-02). La habitación
-- se registra por dimensión: ocupación o condición. id_responsable solo
-- se llena si actuó un empleado; si fue el huésped, se sabe por la reserva.
-- ---------------------------------------------------------------------
CREATE TABLE historial_estados (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_entidad     VARCHAR(25)  NOT NULL,
    id_entidad       BIGINT       NOT NULL,
    estado_anterior  VARCHAR(20),
    estado_nuevo     VARCHAR(20)  NOT NULL,
    tipo_responsable VARCHAR(10)  NOT NULL,
    id_responsable   BIGINT REFERENCES empleados (id),
    motivo           VARCHAR(500),
    fecha            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_historial_tipo_entidad CHECK (tipo_entidad IN (
        'RESERVA', 'HABITACION_OCUPACION', 'HABITACION_CONDICION',
        'PEDIDO', 'SOLICITUD', 'INCIDENCIA')),
    CONSTRAINT ck_historial_tipo_responsable CHECK (tipo_responsable IN (
        'EMPLEADO', 'HUESPED', 'CLIENTE', 'CANAL', 'STRIPE', 'SISTEMA')),
    CONSTRAINT ck_historial_responsable
        CHECK ((tipo_responsable = 'EMPLEADO') = (id_responsable IS NOT NULL))
);

CREATE INDEX ix_historial_entidad ON historial_estados (tipo_entidad, id_entidad, fecha);

-- ---------------------------------------------------------------------
-- Outbox de correos y push con reintentos: si un envío falla, el cambio
-- de estado se guarda igual (AD-12; RN-NOT-002, RN-NOT-003)
-- ---------------------------------------------------------------------
CREATE TABLE outbox (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo               VARCHAR(30)  NOT NULL,
    destinatario       VARCHAR(255) NOT NULL,
    payload            JSONB        NOT NULL,
    estado             VARCHAR(10)  NOT NULL DEFAULT 'PENDIENTE',
    intentos           INT          NOT NULL DEFAULT 0,
    proximo_intento_en TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ultimo_error       TEXT,
    creado_en          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    enviado_en         TIMESTAMPTZ,
    CONSTRAINT ck_outbox_tipo CHECK (tipo IN (
        'CORREO_CONFIRMACION', 'CORREO_OTP', 'CORREO_FACTURA',
        'PUSH_PEDIDO_ENTREGADO', 'PUSH_SOLICITUD_ATENDIDA')),
    CONSTRAINT ck_outbox_estado CHECK (estado IN ('PENDIENTE', 'ENVIADO', 'FALLIDO')),
    CONSTRAINT ck_outbox_intentos CHECK (intentos >= 0)
);

-- Lo que el @Scheduled tiene que procesar.
CREATE INDEX ix_outbox_pendientes ON outbox (proximo_intento_en) WHERE estado = 'PENDIENTE';
