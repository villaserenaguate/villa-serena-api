-- =====================================================================
-- V2 — Catálogos y reservas (OBJ-0C, docs/esquema-propuesto.md §3.3 y §3.4)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Datos del hotel y fiscales: una sola fila (HU-ADM-08; RN-FAC-010).
-- Las horas 15:00 y 12:00 son constantes del sistema y no se guardan.
-- ---------------------------------------------------------------------
CREATE TABLE configuracion_hotel (
    id               SMALLINT     PRIMARY KEY,
    nombre           VARCHAR(150) NOT NULL,
    descripcion      TEXT         NOT NULL,
    direccion        VARCHAR(255) NOT NULL,
    telefono         VARCHAR(30)  NOT NULL,
    correo           VARCHAR(150) NOT NULL,
    nombre_comercial VARCHAR(150) NOT NULL,
    razon_social     VARCHAR(150) NOT NULL,
    nit              VARCHAR(20)  NOT NULL,
    direccion_fiscal VARCHAR(255) NOT NULL,
    CONSTRAINT ck_configuracion_hotel_una_fila CHECK (id = 1)
);

-- Fotos del hotel (HU-ADM-08 C1; HU-HUE-01 C1). Clave del objeto en MinIO.
CREATE TABLE fotos_hotel (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clave_objeto VARCHAR(255) NOT NULL,
    orden        INT          NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------
-- Tipos de habitación (HU-ADM-03, HU-ADM-07; RN-HAB-009; RN-TAR-004, 012)
-- ---------------------------------------------------------------------
CREATE TABLE tipos_habitacion (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                VARCHAR(100)  NOT NULL,
    descripcion           TEXT          NOT NULL,
    capacidad             INT           NOT NULL,
    precio_base           NUMERIC(12,2) NOT NULL,
    ajuste_fin_semana_pct NUMERIC(5,2)  NOT NULL DEFAULT 0,
    estado                VARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT uq_tipos_habitacion_nombre UNIQUE (nombre),
    CONSTRAINT ck_tipos_habitacion_capacidad CHECK (capacidad >= 1),
    CONSTRAINT ck_tipos_habitacion_precio CHECK (precio_base > 0),
    CONSTRAINT ck_tipos_habitacion_ajuste CHECK (ajuste_fin_semana_pct > -100),
    CONSTRAINT ck_tipos_habitacion_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- Fotos del tipo, con una sola principal (HU-ADM-03 C2).
CREATE TABLE fotos_tipo_habitacion (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_habitacion_id BIGINT       NOT NULL REFERENCES tipos_habitacion (id),
    clave_objeto       VARCHAR(255) NOT NULL,
    es_principal       BOOLEAN      NOT NULL DEFAULT FALSE,
    orden              INT          NOT NULL DEFAULT 0
);

CREATE INDEX ix_fotos_tipo_habitacion_tipo ON fotos_tipo_habitacion (tipo_habitacion_id);
CREATE UNIQUE INDEX uq_fotos_tipo_habitacion_principal
    ON fotos_tipo_habitacion (tipo_habitacion_id) WHERE es_principal;

-- ---------------------------------------------------------------------
-- Habitaciones: ocupación y condición separadas (documento 07 §4;
-- HU-ADM-04; RN-HAB-007, RN-HAB-011)
-- ---------------------------------------------------------------------
CREATE TABLE habitaciones (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero               VARCHAR(10) NOT NULL,
    piso                 INT         NOT NULL,
    tipo_habitacion_id   BIGINT      NOT NULL REFERENCES tipos_habitacion (id),
    ocupacion            VARCHAR(10) NOT NULL DEFAULT 'LIBRE',
    condicion            VARCHAR(20) NOT NULL DEFAULT 'LIMPIA',
    estado               VARCHAR(10) NOT NULL DEFAULT 'ACTIVO',
    -- Empleado que tiene la limpieza a su nombre (C3).
    limpieza_empleado_id BIGINT REFERENCES empleados (id),
    CONSTRAINT uq_habitaciones_numero UNIQUE (numero),
    CONSTRAINT ck_habitaciones_ocupacion CHECK (ocupacion IN ('LIBRE', 'OCUPADA')),
    CONSTRAINT ck_habitaciones_condicion
        CHECK (condicion IN ('LIMPIA', 'SUCIA', 'EN_LIMPIEZA', 'FUERA_DE_SERVICIO')),
    CONSTRAINT ck_habitaciones_estado CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT ck_habitaciones_limpieza_a_cargo
        CHECK ((condicion = 'EN_LIMPIEZA') = (limpieza_empleado_id IS NOT NULL))
);

CREATE INDEX ix_habitaciones_tipo ON habitaciones (tipo_habitacion_id);

-- ---------------------------------------------------------------------
-- Temporadas (HU-ADM-06; RN-TAR-004, RN-TAR-011). El traslape por tipo
-- (RN-TAR-003) se valida en el servicio.
-- ---------------------------------------------------------------------
CREATE TABLE temporadas (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    fecha_inicio   DATE         NOT NULL,
    fecha_fin      DATE         NOT NULL,
    ajuste_pct     NUMERIC(5,2) NOT NULL,
    aplica_a_todos BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_temporadas_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT ck_temporadas_ajuste CHECK (ajuste_pct > -100)
);

-- Tipos a los que aplica una temporada cuando no es para todos (HU-ADM-06 C2).
-- Las temporadas se pueden eliminar (C5): se borran también sus filas aquí.
CREATE TABLE temporada_tipos_habitacion (
    temporada_id       BIGINT NOT NULL REFERENCES temporadas (id) ON DELETE CASCADE,
    tipo_habitacion_id BIGINT NOT NULL REFERENCES tipos_habitacion (id),
    PRIMARY KEY (temporada_id, tipo_habitacion_id)
);

-- ---------------------------------------------------------------------
-- Menú de Room Service (HU-ADM-05; RN-RS-008, RN-RS-013; documento 07 §9)
-- ---------------------------------------------------------------------
CREATE TABLE items_menu (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    categoria               VARCHAR(60)   NOT NULL,
    nombre                  VARCHAR(100)  NOT NULL,
    descripcion             TEXT          NOT NULL,
    precio                  NUMERIC(12,2) NOT NULL,
    clave_foto              VARCHAR(255),
    disponibilidad          VARCHAR(10)   NOT NULL DEFAULT 'DISPONIBLE',
    estado                  VARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    agotado_en              TIMESTAMPTZ,
    agotado_por_empleado_id BIGINT REFERENCES empleados (id),
    CONSTRAINT ck_items_menu_precio CHECK (precio > 0),
    CONSTRAINT ck_items_menu_disponibilidad CHECK (disponibilidad IN ('DISPONIBLE', 'AGOTADO')),
    CONSTRAINT ck_items_menu_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- ---------------------------------------------------------------------
-- Artículos que el huésped puede pedir (documento 08 §5)
-- ---------------------------------------------------------------------
CREATE TABLE articulos (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    cantidad_maxima INT          NOT NULL,
    CONSTRAINT uq_articulos_nombre UNIQUE (nombre),
    CONSTRAINT ck_articulos_cantidad_maxima CHECK (cantidad_maxima >= 1)
);

-- ---------------------------------------------------------------------
-- Reservas (documento 07 §3; RN-RES-002, 005, 009, 010, 011, 013; RN-CM-004)
-- ---------------------------------------------------------------------
CREATE TABLE reservas (
    id                                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                              VARCHAR(9)    NOT NULL,
    huesped_id                          BIGINT        NOT NULL REFERENCES huespedes (id),
    tipo_habitacion_id                  BIGINT        NOT NULL REFERENCES tipos_habitacion (id),
    habitacion_id                       BIGINT REFERENCES habitaciones (id),
    fecha_entrada                       DATE          NOT NULL,
    fecha_salida                        DATE          NOT NULL,
    numero_huespedes                    INT           NOT NULL,
    estado                              VARCHAR(15)   NOT NULL,
    canal                               VARCHAR(15)   NOT NULL,
    identificador_externo               VARCHAR(60),
    total                               NUMERIC(12,2) NOT NULL,
    creada_por_empleado_id              BIGINT REFERENCES empleados (id),
    creada_en                           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- Solo la última asignación de habitación (RN-RES-013).
    habitacion_asignada_en              TIMESTAMPTZ,
    habitacion_asignada_por_empleado_id BIGINT REFERENCES empleados (id),
    CONSTRAINT uq_reservas_codigo UNIQUE (codigo),
    CONSTRAINT ck_reservas_codigo CHECK (codigo ~ '^VS-[A-Z0-9]{6}$'),
    CONSTRAINT ck_reservas_estado
        CHECK (estado IN ('PENDIENTE_PAGO', 'CONFIRMADA', 'EN_ESTADIA', 'FINALIZADA', 'CANCELADA')),
    CONSTRAINT ck_reservas_canal
        CHECK (canal IN ('DIRECTO_WEB', 'RECEPCION', 'BOOKING', 'EXPEDIA')),
    -- Solo las reservas de canal externo tienen identificador externo.
    CONSTRAINT ck_reservas_identificador_externo
        CHECK ((canal IN ('BOOKING', 'EXPEDIA')) = (identificador_externo IS NOT NULL)),
    -- Una reserva por canal e identificador externo (RN-CM-004).
    CONSTRAINT uq_reservas_canal_identificador UNIQUE (canal, identificador_externo),
    -- De 1 a 30 noches (RN-RES-005).
    CONSTRAINT ck_reservas_fechas CHECK (fecha_salida > fecha_entrada),
    CONSTRAINT ck_reservas_max_noches CHECK (fecha_salida - fecha_entrada <= 30),
    CONSTRAINT ck_reservas_numero_huespedes CHECK (numero_huespedes >= 1),
    -- Sin reservas activas traslapadas en la misma habitación (RN-RES-002).
    -- '[)': la salida de una y la entrada de la siguiente pueden ser el mismo día.
    CONSTRAINT ex_reservas_habitacion_traslape EXCLUDE USING gist (
        habitacion_id WITH =,
        daterange(fecha_entrada, fecha_salida, '[)') WITH &&
    ) WHERE (estado IN ('PENDIENTE_PAGO', 'CONFIRMADA', 'EN_ESTADIA'))
);

CREATE INDEX ix_reservas_huesped ON reservas (huesped_id);
CREATE INDEX ix_reservas_tipo_fechas ON reservas (tipo_habitacion_id, fecha_entrada, fecha_salida);

-- Precio fijo de cada noche, para el detalle de la cuenta (HU-REC-13 C1;
-- RN-TAR-006, 007). Las reservas de canal no tienen filas (RN-TAR-010).
CREATE TABLE reserva_noches (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reserva_id       BIGINT        NOT NULL REFERENCES reservas (id),
    fecha            DATE          NOT NULL,
    precio           NUMERIC(12,2) NOT NULL,
    temporada_nombre VARCHAR(100),
    fin_de_semana    BOOLEAN       NOT NULL,
    CONSTRAINT uq_reserva_noches_fecha UNIQUE (reserva_id, fecha)
);

-- Huéspedes adicionales: no son usuarios (RN-RES-020; RN-APP-004).
CREATE TABLE huespedes_adicionales (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reserva_id       BIGINT       NOT NULL REFERENCES reservas (id),
    nombre_completo  VARCHAR(150) NOT NULL,
    tipo_documento   VARCHAR(10)  NOT NULL,
    numero_documento VARCHAR(30)  NOT NULL,
    nacionalidad     VARCHAR(60)  NOT NULL,
    CONSTRAINT ck_huespedes_adicionales_tipo_documento
        CHECK (tipo_documento IN ('DPI', 'PASAPORTE'))
);

CREATE INDEX ix_huespedes_adicionales_reserva ON huespedes_adicionales (reserva_id);
