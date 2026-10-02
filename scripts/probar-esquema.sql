-- =====================================================================
-- Pruebas del esquema y los datos iniciales (OBJ-0C)
--
-- Se corre sobre una base con TODAS las migraciones aplicadas (V1 a V6).
-- Todo va dentro de una transacción que se deshace al final: no deja datos.
-- Si una prueba falla, psql se detiene y muestra "FALLO ...".
-- Cómo correrlo: ver README.md, sección "Probar el esquema".
-- =====================================================================
\set ON_ERROR_STOP 1
\set QUIET on
\pset footer off
BEGIN;

-- ---------------------------------------------------------------------
-- 1. Datos iniciales (V6)
-- ---------------------------------------------------------------------
\echo '== Datos iniciales'
SELECT (SELECT count(*) FROM configuracion_hotel) AS hotel,
       (SELECT count(*) FROM series_factura)      AS series,
       (SELECT count(*) FROM tipos_habitacion)    AS tipos,
       (SELECT count(*) FROM habitaciones)        AS habitaciones,
       (SELECT count(*) FROM temporadas)          AS temporadas,
       (SELECT count(*) FROM items_menu)          AS items_menu,
       (SELECT count(*) FROM articulos)           AS articulos,
       (SELECT count(*) FROM canales)             AS canales,
       (SELECT count(*) FROM empleados)           AS empleados;

DO $$
BEGIN
  IF (SELECT count(*) FROM configuracion_hotel) <> 1 THEN RAISE EXCEPTION 'FALLO: falta la configuración del hotel'; END IF;
  IF NOT EXISTS (SELECT 1 FROM series_factura WHERE serie = 'VS-A') THEN RAISE EXCEPTION 'FALLO: falta la serie VS-A'; END IF;
  IF (SELECT count(*) FROM tipos_habitacion) < 4 THEN RAISE EXCEPTION 'FALLO: faltan tipos de habitación'; END IF;
  IF (SELECT count(*) FROM habitaciones) < 12 THEN RAISE EXCEPTION 'FALLO: faltan habitaciones'; END IF;
  IF (SELECT count(*) FROM temporadas) < 2 THEN RAISE EXCEPTION 'FALLO: faltan temporadas'; END IF;
  IF (SELECT count(*) FROM items_menu) < 10 OR (SELECT count(DISTINCT categoria) FROM items_menu) < 3 THEN
    RAISE EXCEPTION 'FALLO: faltan ítems o categorías del menú'; END IF;
  IF (SELECT count(*) FROM articulos) < 6 THEN RAISE EXCEPTION 'FALLO: faltan artículos'; END IF;
  IF (SELECT count(*) FROM canales WHERE codigo IN ('BOOKING', 'EXPEDIA')) <> 2 THEN RAISE EXCEPTION 'FALLO: faltan canales'; END IF;
  IF (SELECT count(*) FROM empleados WHERE rol = 'ADMIN' AND estado = 'ACTIVO') < 2 THEN RAISE EXCEPTION 'FALLO: faltan 2 ADMIN activos'; END IF;
  IF (SELECT count(DISTINCT area) FROM empleados WHERE rol = 'MANTENIMIENTO_LIMPIEZA') <> 3 THEN
    RAISE EXCEPTION 'FALLO: falta un empleado de alguna área'; END IF;
  IF EXISTS (SELECT 1 FROM empleados WHERE contrasena_hash LIKE '%${%') OR EXISTS (SELECT 1 FROM canales WHERE clave_hash LIKE '%${%') THEN
    RAISE EXCEPTION 'FALLO: hay un placeholder sin sustituir'; END IF;
  RAISE NOTICE 'OK: datos iniciales completos';
END $$;

-- ---------------------------------------------------------------------
-- 2. Datos propios de las pruebas (se deshacen al final)
-- ---------------------------------------------------------------------
INSERT INTO empleados (nombre_completo, correo, telefono, rol, contrasena_hash)
VALUES ('Prueba Recepción', 'prueba.recepcion@villaserena.test', '1', 'RECEPCION', 'x');
INSERT INTO huespedes (nombre_completo, correo, telefono, nacionalidad, tipo_documento, numero_documento)
VALUES ('Huésped de Prueba', 'prueba.huesped@example.test', '1', 'Guatemalteca', 'DPI', '1');
INSERT INTO tipos_habitacion (nombre, descripcion, capacidad, precio_base) VALUES ('Tipo de prueba', 'x', 4, 100.00);
INSERT INTO habitaciones (numero, piso, tipo_habitacion_id)
SELECT 'P901', 9, id FROM tipos_habitacion WHERE nombre = 'Tipo de prueba';
INSERT INTO reservas (codigo, huesped_id, tipo_habitacion_id, habitacion_id, fecha_entrada, fecha_salida,
                      numero_huespedes, estado, canal, total)
SELECT 'VS-PRB001', h.id, t.id, hab.id, '2030-10-15', '2030-10-17', 2, 'CONFIRMADA', 'RECEPCION', 200.00
FROM huespedes h, tipos_habitacion t, habitaciones hab
WHERE h.correo = 'prueba.huesped@example.test' AND t.nombre = 'Tipo de prueba' AND hab.numero = 'P901';

-- Atajo para insertar una reserva de prueba en P901.
CREATE FUNCTION pg_temp.reserva_prueba(p_codigo TEXT, p_entrada DATE, p_salida DATE, p_estado TEXT,
                                       p_canal TEXT DEFAULT 'RECEPCION', p_externo TEXT DEFAULT NULL,
                                       p_con_habitacion BOOLEAN DEFAULT TRUE) RETURNS VOID AS $$
  INSERT INTO reservas (codigo, huesped_id, tipo_habitacion_id, habitacion_id, fecha_entrada, fecha_salida,
                        numero_huespedes, estado, canal, identificador_externo, total)
  SELECT p_codigo, h.id, t.id, CASE WHEN p_con_habitacion THEN hab.id END, p_entrada, p_salida,
         2, p_estado, p_canal, p_externo, 100.00
  FROM huespedes h, tipos_habitacion t, habitaciones hab
  WHERE h.correo = 'prueba.huesped@example.test' AND t.nombre = 'Tipo de prueba' AND hab.numero = 'P901';
$$ LANGUAGE sql;

-- ---------------------------------------------------------------------
-- 3. Seguridad, huéspedes, catálogos y reservas (V1, V2)
-- ---------------------------------------------------------------------
\echo '== Seguridad, catálogos y reservas'
DO $$ BEGIN
  INSERT INTO empleados (nombre_completo, correo, telefono, rol, contrasena_hash)
  VALUES ('Otra', 'PRUEBA.Recepcion@villaserena.test', '1', 'RECEPCION', 'x');
  RAISE EXCEPTION 'FALLO: correo de empleado duplicado aceptado';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: correo de empleado duplicado rechazado';
END $$;

DO $$ BEGIN
  INSERT INTO huespedes (nombre_completo, correo, telefono, nacionalidad, tipo_documento, numero_documento)
  VALUES ('Otra', 'Prueba.Huesped@Example.test', '1', 'X', 'DPI', '1');
  RAISE EXCEPTION 'FALLO: correo de huésped duplicado aceptado';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: correo de huésped duplicado rechazado';
END $$;

DO $$ BEGIN
  PERFORM pg_temp.reserva_prueba('VS-PRB002', '2030-10-16', '2030-10-18', 'CONFIRMADA');
  RAISE EXCEPTION 'FALLO: reserva traslapada aceptada';
EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'OK: reserva traslapada rechazada por el EXCLUDE';
END $$;

DO $$ BEGIN PERFORM pg_temp.reserva_prueba('VS-PRB003', '2030-10-17', '2030-10-19', 'PENDIENTE_PAGO', 'DIRECTO_WEB'); END $$;
\echo 'OK: reserva que entra el día de salida de la anterior aceptada'
DO $$ BEGIN PERFORM pg_temp.reserva_prueba('VS-PRB004', '2030-10-15', '2030-10-16', 'CANCELADA'); END $$;
\echo 'OK: reserva CANCELADA traslapada aceptada'

DO $$ BEGIN
  INSERT INTO empleados (nombre_completo, correo, telefono, rol, contrasena_hash)
  VALUES ('Sin área', 'prueba.sinarea@villaserena.test', '1', 'MANTENIMIENTO_LIMPIEZA', 'x');
  RAISE EXCEPTION 'FALLO: MANTENIMIENTO_LIMPIEZA sin área aceptado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: MANTENIMIENTO_LIMPIEZA sin área rechazado';
END $$;

DO $$ BEGIN
  INSERT INTO empleados (nombre_completo, correo, telefono, rol, area, contrasena_hash)
  VALUES ('Con área', 'prueba.conarea@villaserena.test', '1', 'RECEPCION', 'LIMPIEZA', 'x');
  RAISE EXCEPTION 'FALLO: RECEPCION con área aceptado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: RECEPCION con área rechazado';
END $$;

DO $$ BEGIN PERFORM pg_temp.reserva_prueba('VS-PRB005', '2030-11-03', '2030-11-06', 'CONFIRMADA', 'BOOKING', 'PRB-1', FALSE); END $$;
DO $$ BEGIN
  PERFORM pg_temp.reserva_prueba('VS-PRB006', '2030-11-03', '2030-11-06', 'CONFIRMADA', 'BOOKING', 'PRB-1', FALSE);
  RAISE EXCEPTION 'FALLO: identificador externo duplicado aceptado';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: canal + identificador externo duplicado rechazado';
END $$;

DO $$ BEGIN
  PERFORM pg_temp.reserva_prueba('VS-PRB007', '2030-12-01', '2031-01-01', 'CONFIRMADA', p_con_habitacion => FALSE);
  RAISE EXCEPTION 'FALLO: estadía de 31 noches aceptada';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: estadía de 31 noches rechazada';
END $$;

DO $$ BEGIN
  PERFORM pg_temp.reserva_prueba('VS-prb', '2030-12-01', '2030-12-02', 'CONFIRMADA', p_con_habitacion => FALSE);
  RAISE EXCEPTION 'FALLO: código de reserva inválido aceptado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: código de reserva inválido rechazado';
END $$;

DO $$ BEGIN
  INSERT INTO habitaciones (numero, piso, tipo_habitacion_id)
  SELECT 'P901', 9, id FROM tipos_habitacion WHERE nombre = 'Tipo de prueba';
  RAISE EXCEPTION 'FALLO: número de habitación duplicado aceptado';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: número de habitación duplicado rechazado';
END $$;

INSERT INTO fotos_tipo_habitacion (tipo_habitacion_id, clave_objeto, es_principal)
SELECT id, 'prueba/a.jpg', TRUE FROM tipos_habitacion WHERE nombre = 'Tipo de prueba';
DO $$ BEGIN
  INSERT INTO fotos_tipo_habitacion (tipo_habitacion_id, clave_objeto, es_principal)
  SELECT id, 'prueba/b.jpg', TRUE FROM tipos_habitacion WHERE nombre = 'Tipo de prueba';
  RAISE EXCEPTION 'FALLO: dos fotos principales aceptadas';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: segunda foto principal rechazada';
END $$;

-- ---------------------------------------------------------------------
-- 4. Cuentas, pagos, room service, piso, facturación y sistema (V3 a V5)
-- ---------------------------------------------------------------------
\echo '== Cuentas, pagos, piso, facturación y sistema'
INSERT INTO cuentas (reserva_id) SELECT id FROM reservas WHERE codigo = 'VS-PRB001';
INSERT INTO pedidos (reserva_id) SELECT id FROM reservas WHERE codigo = 'VS-PRB001';
INSERT INTO cargos (cuenta_id, tipo, concepto, cantidad, precio_unitario, total)
SELECT c.id, 'ALOJAMIENTO', 'Alojamiento', 1, 200.00, 200.00
FROM cuentas c JOIN reservas r ON r.id = c.reserva_id WHERE r.codigo = 'VS-PRB001';
INSERT INTO cargos (cuenta_id, tipo, concepto, cantidad, precio_unitario, total, pedido_id)
SELECT c.id, 'ROOM_SERVICE', 'Room Service — Pedido de prueba', 1, 65.00, 65.00, p.id
FROM cuentas c JOIN reservas r ON r.id = c.reserva_id JOIN pedidos p ON p.reserva_id = r.id
WHERE r.codigo = 'VS-PRB001';
INSERT INTO series_factura (serie, numero_inicial, ultimo_numero) VALUES ('PRB', 1, 0);
INSERT INTO facturas (cuenta_id, serie_id, numero, nit_comprador, nombre_comprador, total,
                      nombre_comercial, razon_social, nit_hotel, direccion_fiscal, direccion)
SELECT c.id, s.id, 1, 'CF', 'Prueba', 265.00, 'a', 'b', 'c', 'd', 'e'
FROM cuentas c JOIN reservas r ON r.id = c.reserva_id, series_factura s
WHERE r.codigo = 'VS-PRB001' AND s.serie = 'PRB';

DO $$ BEGIN
  INSERT INTO cargos (cuenta_id, tipo, concepto, cantidad, precio_unitario, total, pedido_id)
  SELECT cuenta_id, tipo, concepto, cantidad, precio_unitario, total, pedido_id
  FROM cargos WHERE tipo = 'ROOM_SERVICE' AND concepto = 'Room Service — Pedido de prueba';
  RAISE EXCEPTION 'FALLO: segundo cargo del mismo pedido aceptado';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: segundo cargo del mismo pedido rechazado';
END $$;

DO $$ BEGIN
  INSERT INTO cuentas (reserva_id) SELECT id FROM reservas WHERE codigo = 'VS-PRB001';
  RAISE EXCEPTION 'FALLO: segunda cuenta de la reserva aceptada';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: segunda cuenta de la reserva rechazada';
END $$;

DO $$ BEGIN
  INSERT INTO facturas (cuenta_id, serie_id, numero, nit_comprador, nombre_comprador, total,
                        nombre_comercial, razon_social, nit_hotel, direccion_fiscal, direccion)
  SELECT f.cuenta_id, f.serie_id, 2, 'CF', 'X', 1.00, 'a', 'b', 'c', 'd', 'e'
  FROM facturas f JOIN series_factura s ON s.id = f.serie_id WHERE s.serie = 'PRB';
  RAISE EXCEPTION 'FALLO: segunda factura de la cuenta aceptada';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: segunda factura de la cuenta rechazada';
END $$;

INSERT INTO cuentas (reserva_id) SELECT id FROM reservas WHERE codigo = 'VS-PRB005';
DO $$ BEGIN
  INSERT INTO facturas (cuenta_id, serie_id, numero, nit_comprador, nombre_comprador, total,
                        nombre_comercial, razon_social, nit_hotel, direccion_fiscal, direccion)
  SELECT c.id, s.id, 1, 'CF', 'X', 1.00, 'a', 'b', 'c', 'd', 'e'
  FROM cuentas c JOIN reservas r ON r.id = c.reserva_id, series_factura s
  WHERE r.codigo = 'VS-PRB005' AND s.serie = 'PRB';
  RAISE EXCEPTION 'FALLO: correlativo repetido aceptado';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: correlativo repetido en la serie rechazado';
END $$;

DO $$ BEGIN
  UPDATE cargos SET estado = 'ANULADO', motivo_anulacion = 'error'
  WHERE tipo = 'ALOJAMIENTO' AND concepto = 'Alojamiento' AND precio_unitario = 200.00;
  RAISE EXCEPTION 'FALLO: alojamiento anulado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: anular el alojamiento rechazado';
END $$;

DO $$ BEGIN
  UPDATE cargos SET estado = 'ANULADO' WHERE concepto = 'Room Service — Pedido de prueba';
  RAISE EXCEPTION 'FALLO: anulación sin motivo aceptada';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: anulación sin motivo rechazada';
END $$;

DO $$ BEGIN
  INSERT INTO pagos (cuenta_id, metodo, estado, monto)
  SELECT c.id, 'STRIPE', 'PENDIENTE', 10.00 FROM cuentas c JOIN reservas r ON r.id = c.reserva_id
  WHERE r.codigo = 'VS-PRB001';
  RAISE EXCEPTION 'FALLO: pago STRIPE sin sesión aceptado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: pago STRIPE sin sesión rechazado';
END $$;

-- Solicitudes en la habitación P901 (reserva VS-PRB001)
CREATE FUNCTION pg_temp.solicitud_prueba(p_tipo TEXT) RETURNS VOID AS $$
  INSERT INTO solicitudes (reserva_id, habitacion_id, tipo)
  SELECT r.id, r.habitacion_id, p_tipo FROM reservas r WHERE r.codigo = 'VS-PRB001';
$$ LANGUAGE sql;

DO $$ BEGIN PERFORM pg_temp.solicitud_prueba('LIMPIEZA'); END $$;
DO $$ BEGIN PERFORM pg_temp.solicitud_prueba('ARTICULOS'); END $$;
\echo 'OK: solicitud de artículos junto a una limpieza activa aceptada'
DO $$ BEGIN
  PERFORM pg_temp.solicitud_prueba('LIMPIEZA');
  RAISE EXCEPTION 'FALLO: segunda limpieza activa aceptada';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: segunda limpieza activa rechazada';
END $$;
DO $$ BEGIN
  UPDATE solicitudes SET estado = 'EN_PROCESO'
  WHERE tipo = 'LIMPIEZA' AND habitacion_id = (SELECT id FROM habitaciones WHERE numero = 'P901');
  RAISE EXCEPTION 'FALLO: solicitud en proceso sin empleado aceptada';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: solicitud en proceso sin empleado rechazada';
END $$;
UPDATE solicitudes
SET estado = 'ATENDIDA', empleado_id = (SELECT id FROM empleados WHERE correo = 'prueba.recepcion@villaserena.test')
WHERE tipo = 'LIMPIEZA' AND habitacion_id = (SELECT id FROM habitaciones WHERE numero = 'P901');
DO $$ BEGIN PERFORM pg_temp.solicitud_prueba('LIMPIEZA'); END $$;
\echo 'OK: nueva limpieza aceptada después de atender la anterior'

INSERT INTO incidencias (habitacion_id, descripcion, impide_uso, reportada_por_empleado_id)
SELECT h.id, 'Incidencia de prueba', TRUE, e.id
FROM habitaciones h, empleados e WHERE h.numero = 'P901' AND e.correo = 'prueba.recepcion@villaserena.test';
DO $$ BEGIN
  UPDATE incidencias SET estado = 'RESUELTA', tecnico_id = reportada_por_empleado_id
  WHERE descripcion = 'Incidencia de prueba';
  RAISE EXCEPTION 'FALLO: incidencia resuelta sin solución aceptada';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: incidencia resuelta sin solución rechazada';
END $$;

DO $$ BEGIN
  INSERT INTO historial_estados (tipo_entidad, id_entidad, estado_nuevo, tipo_responsable)
  VALUES ('RESERVA', 1, 'CONFIRMADA', 'EMPLEADO');
  RAISE EXCEPTION 'FALLO: historial de EMPLEADO sin id aceptado';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: historial de EMPLEADO sin id rechazado';
END $$;

DO $$ BEGIN
  UPDATE canales SET clave_hash = 'clave-en-texto-plano' WHERE codigo = 'BOOKING';
  RAISE EXCEPTION 'FALLO: clave de canal sin hash aceptada';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: clave de canal sin hash rechazada';
END $$;

INSERT INTO stripe_eventos (evento_id, tipo) VALUES ('evt_prueba', 'checkout.session.completed');
DO $$ BEGIN
  INSERT INTO stripe_eventos (evento_id, tipo) VALUES ('evt_prueba', 'checkout.session.completed');
  RAISE EXCEPTION 'FALLO: evento de Stripe repetido aceptado';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'OK: evento de Stripe repetido rechazado';
END $$;

ROLLBACK;
\echo '== Todas las pruebas pasaron (los datos de prueba se deshicieron)'
