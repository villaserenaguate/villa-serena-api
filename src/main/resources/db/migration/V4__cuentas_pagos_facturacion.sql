-- =====================================================================
-- V4 — Cuentas, pagos y facturación (OBJ-0C, docs/esquema-propuesto.md §3.5 y §3.9)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Cuenta: una por reserva, creada junto con ella (documento 07 §5.1, E-01)
-- ---------------------------------------------------------------------
CREATE TABLE cuentas (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reserva_id BIGINT      NOT NULL REFERENCES reservas (id),
    estado     VARCHAR(10) NOT NULL DEFAULT 'ABIERTA',
    abierta_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    cerrada_en TIMESTAMPTZ,
    CONSTRAINT uq_cuentas_reserva UNIQUE (reserva_id),
    CONSTRAINT ck_cuentas_estado CHECK (estado IN ('ABIERTA', 'CERRADA'))
);

-- ---------------------------------------------------------------------
-- Cargos: nunca se borran; se anulan con motivo (documento 07 §5.2;
-- RN-PAG-011, RN-PAG-019; RN-RS-007)
-- ---------------------------------------------------------------------
CREATE TABLE cargos (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cuenta_id               BIGINT        NOT NULL REFERENCES cuentas (id),
    tipo                    VARCHAR(15)   NOT NULL,
    categoria_servicio      VARCHAR(15),
    concepto                VARCHAR(150)  NOT NULL,
    cantidad                INT           NOT NULL,
    precio_unitario         NUMERIC(12,2) NOT NULL,
    total                   NUMERIC(12,2) NOT NULL,
    estado                  VARCHAR(10)   NOT NULL DEFAULT 'VIGENTE',
    pedido_id               BIGINT REFERENCES pedidos (id),
    -- Nulo cuando lo genera el sistema (alojamiento y room service).
    creado_por_empleado_id  BIGINT REFERENCES empleados (id),
    creado_en               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    motivo_anulacion        VARCHAR(500),
    anulado_por_empleado_id BIGINT REFERENCES empleados (id),
    anulado_en              TIMESTAMPTZ,
    -- Un solo cargo por pedido (RN-RS-007).
    CONSTRAINT uq_cargos_pedido UNIQUE (pedido_id),
    CONSTRAINT ck_cargos_tipo CHECK (tipo IN ('ALOJAMIENTO', 'ROOM_SERVICE', 'SERVICIO')),
    CONSTRAINT ck_cargos_categoria_servicio
        CHECK (categoria_servicio IN ('RESTAURANTE', 'LAVANDERIA', 'ESTACIONAMIENTO', 'OTRO')),
    CONSTRAINT ck_cargos_categoria_segun_tipo
        CHECK ((tipo = 'SERVICIO') = (categoria_servicio IS NOT NULL)),
    CONSTRAINT ck_cargos_pedido_segun_tipo
        CHECK ((tipo = 'ROOM_SERVICE') = (pedido_id IS NOT NULL)),
    CONSTRAINT ck_cargos_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_cargos_precio CHECK (precio_unitario > 0),
    CONSTRAINT ck_cargos_estado CHECK (estado IN ('VIGENTE', 'ANULADO')),
    -- Anular exige motivo (RG-EST-06).
    CONSTRAINT ck_cargos_motivo_anulacion
        CHECK ((estado = 'ANULADO') = (motivo_anulacion IS NOT NULL)),
    -- El alojamiento no se anula (G3).
    CONSTRAINT ck_cargos_alojamiento_no_anulado
        CHECK (NOT (tipo = 'ALOJAMIENTO' AND estado = 'ANULADO'))
);

CREATE INDEX ix_cargos_cuenta ON cargos (cuenta_id);

-- ---------------------------------------------------------------------
-- Pagos (documento 07 §5.3; RN-PAG-003, 008, 013, 014; RN-IND-001).
-- aprobado_en define el rango de los ingresos; stripe_payment_intent_id
-- se usa para el reembolso total (P6).
-- ---------------------------------------------------------------------
CREATE TABLE pagos (
    id                         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cuenta_id                  BIGINT        NOT NULL REFERENCES cuentas (id),
    metodo                     VARCHAR(10)   NOT NULL,
    estado                     VARCHAR(15)   NOT NULL,
    monto                      NUMERIC(12,2) NOT NULL,
    referencia                 VARCHAR(100),
    stripe_session_id          VARCHAR(255),
    stripe_payment_intent_id   VARCHAR(255),
    registrado_por_empleado_id BIGINT REFERENCES empleados (id),
    creado_en                  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    aprobado_en                TIMESTAMPTZ,
    reembolsado_en             TIMESTAMPTZ,
    CONSTRAINT ck_pagos_metodo CHECK (metodo IN ('STRIPE', 'CANAL', 'EFECTIVO', 'TARJETA', 'OTRO')),
    CONSTRAINT ck_pagos_estado CHECK (estado IN ('PENDIENTE', 'APROBADO', 'FALLIDO', 'REEMBOLSADO')),
    CONSTRAINT ck_pagos_monto CHECK (monto > 0),
    CONSTRAINT uq_pagos_stripe_session UNIQUE (stripe_session_id),
    CONSTRAINT ck_pagos_stripe_session
        CHECK ((metodo = 'STRIPE') = (stripe_session_id IS NOT NULL))
);

CREATE INDEX ix_pagos_cuenta ON pagos (cuenta_id);

-- Eventos de Stripe ya procesados: el webhook es idempotente por el id
-- del evento (documento 14 AD-17 y §6; RN-PAG-002).
CREATE TABLE stripe_eventos (
    evento_id   VARCHAR(255) PRIMARY KEY,
    tipo        VARCHAR(100) NOT NULL,
    recibido_en TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Serie fija de facturación, cargada en los datos iniciales (RN-FAC-004).
-- El correlativo se toma con SELECT ... FOR UPDATE en el check-out.
-- ---------------------------------------------------------------------
CREATE TABLE series_factura (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    serie          VARCHAR(10) NOT NULL,
    numero_inicial INT         NOT NULL,
    ultimo_numero  INT         NOT NULL,
    CONSTRAINT uq_series_factura_serie UNIQUE (serie),
    CONSTRAINT ck_series_factura_numero_inicial CHECK (numero_inicial >= 1),
    CONSTRAINT ck_series_factura_ultimo_numero CHECK (ultimo_numero >= numero_inicial - 1)
);

-- ---------------------------------------------------------------------
-- Facturas de demostración (documento 07 §5.4; RN-FAC-001, 002, 005, 008,
-- 009). Guardan una copia de los datos del hotel para que la reimpresión
-- no cambie si se edita la configuración.
-- ---------------------------------------------------------------------
CREATE TABLE facturas (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cuenta_id        BIGINT        NOT NULL REFERENCES cuentas (id),
    serie_id         BIGINT        NOT NULL REFERENCES series_factura (id),
    numero           INT           NOT NULL,
    estado           VARCHAR(10)   NOT NULL DEFAULT 'EMITIDA',
    emitida_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- NIT validado o "CF" (RN-FAC-005).
    nit_comprador    VARCHAR(20)   NOT NULL,
    nombre_comprador VARCHAR(150)  NOT NULL,
    total            NUMERIC(12,2) NOT NULL,
    clave_pdf        VARCHAR(255),
    nombre_comercial VARCHAR(150)  NOT NULL,
    razon_social     VARCHAR(150)  NOT NULL,
    nit_hotel        VARCHAR(20)   NOT NULL,
    direccion_fiscal VARCHAR(255)  NOT NULL,
    direccion        VARCHAR(255)  NOT NULL,
    -- Una sola factura por cuenta (RN-FAC-001).
    CONSTRAINT uq_facturas_cuenta UNIQUE (cuenta_id),
    -- Correlativo único por serie (RN-FAC-004).
    CONSTRAINT uq_facturas_serie_numero UNIQUE (serie_id, numero),
    CONSTRAINT ck_facturas_estado CHECK (estado = 'EMITIDA')
);
