-- =====================================================================
-- V3 — Room Service, solicitudes e incidencias
-- (OBJ-0C, docs/esquema-propuesto.md §3.6, §3.7 y §3.8)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Pedidos de Room Service (documento 07 §6; HU-HUE-10 C4; RN-RS-006).
-- El "Pedido #n" del cargo es el id. El motivo de cancelación va en
-- historial_estados.
-- ---------------------------------------------------------------------
CREATE TABLE pedidos (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reserva_id BIGINT      NOT NULL REFERENCES reservas (id),
    estado     VARCHAR(15) NOT NULL DEFAULT 'NUEVO',
    notas      VARCHAR(500),
    creado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_pedidos_estado
        CHECK (estado IN ('NUEVO', 'EN_PREPARACION', 'EN_CAMINO', 'ENTREGADO', 'CANCELADO'))
);

CREATE INDEX ix_pedidos_reserva ON pedidos (reserva_id);
CREATE INDEX ix_pedidos_estado ON pedidos (estado);

-- Ítems del pedido con el precio congelado al pedir (RN-RS-006).
CREATE TABLE pedido_items (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id       BIGINT        NOT NULL REFERENCES pedidos (id),
    item_menu_id    BIGINT        NOT NULL REFERENCES items_menu (id),
    cantidad        INT           NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,
    CONSTRAINT ck_pedido_items_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_pedido_items_precio CHECK (precio_unitario > 0)
);

CREATE INDEX ix_pedido_items_pedido ON pedido_items (pedido_id);

-- ---------------------------------------------------------------------
-- Solicitudes de limpieza y artículos (documento 07 §7; HU-HUE-12 C2;
-- RN-LIM-005). habitacion_id se copia de la reserva para que exista el
-- índice único parcial.
-- ---------------------------------------------------------------------
CREATE TABLE solicitudes (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reserva_id    BIGINT      NOT NULL REFERENCES reservas (id),
    habitacion_id BIGINT      NOT NULL REFERENCES habitaciones (id),
    tipo          VARCHAR(10) NOT NULL,
    estado        VARCHAR(10) NOT NULL DEFAULT 'PENDIENTE',
    comentario    VARCHAR(500),
    -- Empleado que la tomó (Q2).
    empleado_id   BIGINT REFERENCES empleados (id),
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_solicitudes_tipo CHECK (tipo IN ('LIMPIEZA', 'ARTICULOS')),
    CONSTRAINT ck_solicitudes_estado
        CHECK (estado IN ('PENDIENTE', 'EN_PROCESO', 'ATENDIDA', 'CANCELADA')),
    -- En proceso y atendida siempre tienen a alguien a cargo (Q2, Q3).
    CONSTRAINT ck_solicitudes_a_cargo
        CHECK (estado NOT IN ('EN_PROCESO', 'ATENDIDA') OR empleado_id IS NOT NULL)
);

CREATE INDEX ix_solicitudes_reserva ON solicitudes (reserva_id);
-- Una sola solicitud de limpieza activa por habitación (RN-LIM-005).
CREATE UNIQUE INDEX uq_solicitudes_limpieza_activa
    ON solicitudes (habitacion_id)
    WHERE tipo = 'LIMPIEZA' AND estado IN ('PENDIENTE', 'EN_PROCESO');

-- Artículos de una solicitud. "Cantidad ≤ máximo" se valida en el servicio.
CREATE TABLE solicitud_items (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id BIGINT NOT NULL REFERENCES solicitudes (id),
    articulo_id  BIGINT NOT NULL REFERENCES articulos (id),
    cantidad     INT    NOT NULL,
    CONSTRAINT uq_solicitud_items_articulo UNIQUE (solicitud_id, articulo_id),
    CONSTRAINT ck_solicitud_items_cantidad CHECK (cantidad > 0)
);

-- ---------------------------------------------------------------------
-- Incidencias de mantenimiento (documento 07 §8; RN-MAN-001, 009, 010).
-- creado_en es la fecha de reporte; tomar y resolver van en el historial.
-- ---------------------------------------------------------------------
CREATE TABLE incidencias (
    id                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    habitacion_id             BIGINT      NOT NULL REFERENCES habitaciones (id),
    descripcion               TEXT        NOT NULL,
    impide_uso                BOOLEAN     NOT NULL,
    -- Foto opcional en el bucket privado.
    clave_foto                VARCHAR(255),
    estado                    VARCHAR(15) NOT NULL DEFAULT 'REPORTADA',
    reportada_por_empleado_id BIGINT      NOT NULL REFERENCES empleados (id),
    tecnico_id                BIGINT REFERENCES empleados (id),
    solucion                  TEXT,
    creado_en                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_incidencias_estado CHECK (estado IN ('REPORTADA', 'EN_PROCESO', 'RESUELTA')),
    CONSTRAINT ck_incidencias_tecnico
        CHECK (estado = 'REPORTADA' OR tecnico_id IS NOT NULL),
    -- Resolver exige la descripción de la solución (RN-MAN-010).
    CONSTRAINT ck_incidencias_solucion
        CHECK ((estado = 'RESUELTA') = (solucion IS NOT NULL))
);

CREATE INDEX ix_incidencias_habitacion ON incidencias (habitacion_id);
