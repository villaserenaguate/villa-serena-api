-- =====================================================================
-- V1 — Seguridad y huéspedes (OBJ-0C, docs/esquema-propuesto.md §3.1 y §3.2)
-- =====================================================================

-- Necesaria para el EXCLUDE de reservas traslapadas (V2).
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------
-- Empleados (documento 08 §3.1; RN-PER-007, RN-PER-008, RN-PER-013)
-- ---------------------------------------------------------------------
CREATE TABLE empleados (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_completo         VARCHAR(150) NOT NULL,
    correo                  VARCHAR(150) NOT NULL,
    telefono                VARCHAR(30)  NOT NULL,
    rol                     VARCHAR(30)  NOT NULL,
    area                    VARCHAR(20),
    estado                  VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
    contrasena_hash         VARCHAR(100) NOT NULL,
    debe_cambiar_contrasena BOOLEAN      NOT NULL DEFAULT TRUE,
    intentos_fallidos       INT          NOT NULL DEFAULT 0,
    bloqueado_hasta         TIMESTAMPTZ,
    creado_en               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_empleados_rol
        CHECK (rol IN ('ADMIN', 'RECEPCION', 'ROOM_SERVICE', 'MANTENIMIENTO_LIMPIEZA')),
    CONSTRAINT ck_empleados_area
        CHECK (area IN ('LIMPIEZA', 'MANTENIMIENTO', 'AMBAS')),
    -- El área es obligatoria solo para Mantenimiento/Limpieza (RN-PER-007).
    CONSTRAINT ck_empleados_area_segun_rol
        CHECK ((rol = 'MANTENIMIENTO_LIMPIEZA') = (area IS NOT NULL)),
    CONSTRAINT ck_empleados_estado
        CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT ck_empleados_intentos
        CHECK (intentos_fallidos >= 0)
);

-- Correo único entre empleados, sin distinguir mayúsculas (RN-PER-008).
CREATE UNIQUE INDEX uq_empleados_correo ON empleados (lower(correo));

-- ---------------------------------------------------------------------
-- Huéspedes (documento 08 §4; RN-RES-019; bloqueo del OTP, PAR-15)
-- ---------------------------------------------------------------------
CREATE TABLE huespedes (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_completo       VARCHAR(150) NOT NULL,
    correo                VARCHAR(150) NOT NULL,
    telefono              VARCHAR(30)  NOT NULL,
    nacionalidad          VARCHAR(60)  NOT NULL,
    tipo_documento        VARCHAR(10)  NOT NULL,
    numero_documento      VARCHAR(30)  NOT NULL,
    otp_intentos_fallidos INT          NOT NULL DEFAULT 0,
    otp_bloqueado_hasta   TIMESTAMPTZ,
    creado_en             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_huespedes_tipo_documento
        CHECK (tipo_documento IN ('DPI', 'PASAPORTE')),
    CONSTRAINT ck_huespedes_otp_intentos
        CHECK (otp_intentos_fallidos >= 0)
);

-- El correo identifica al huésped (RN-RES-019).
CREATE UNIQUE INDEX uq_huespedes_correo ON huespedes (lower(correo));

-- ---------------------------------------------------------------------
-- Refresh tokens: solo el hash, rotativos y revocables (documento 14 §6)
-- ---------------------------------------------------------------------
CREATE TABLE refresh_tokens (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    token_hash   VARCHAR(100) NOT NULL,
    tipo_usuario VARCHAR(10)  NOT NULL,
    empleado_id  BIGINT REFERENCES empleados (id),
    huesped_id   BIGINT REFERENCES huespedes (id),
    expira_en    TIMESTAMPTZ  NOT NULL,
    revocado_en  TIMESTAMPTZ,
    creado_en    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash),
    CONSTRAINT ck_refresh_tokens_usuario CHECK (
        (tipo_usuario = 'EMPLEADO' AND empleado_id IS NOT NULL AND huesped_id IS NULL)
        OR (tipo_usuario = 'HUESPED' AND huesped_id IS NOT NULL AND empleado_id IS NULL)
    )
);

CREATE INDEX ix_refresh_tokens_empleado ON refresh_tokens (empleado_id);
CREATE INDEX ix_refresh_tokens_huesped ON refresh_tokens (huesped_id);

-- ---------------------------------------------------------------------
-- Códigos OTP del huésped: solo el hash (PAR-14; RN-APP-001)
-- ---------------------------------------------------------------------
CREATE TABLE codigos_otp (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    huesped_id  BIGINT       NOT NULL REFERENCES huespedes (id),
    codigo_hash VARCHAR(100) NOT NULL,
    expira_en   TIMESTAMPTZ  NOT NULL,
    usado_en    TIMESTAMPTZ,
    creado_en   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX ix_codigos_otp_huesped ON codigos_otp (huesped_id);

-- ---------------------------------------------------------------------
-- Teléfonos registrados para push (AD-10; RN-NOT-004)
-- ---------------------------------------------------------------------
CREATE TABLE dispositivos_push (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    huesped_id BIGINT       NOT NULL REFERENCES huespedes (id),
    token_expo VARCHAR(255) NOT NULL,
    creado_en  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_dispositivos_push_token UNIQUE (token_expo)
);

CREATE INDEX ix_dispositivos_push_huesped ON dispositivos_push (huesped_id);
