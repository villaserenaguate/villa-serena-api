-- =====================================================================
-- V6 — Datos iniciales de la demostración (OBJ-0C PASO 3; AD-18)
--
-- Todo es ficticio. Las contraseñas y las claves de los canales NO están
-- aquí: Flyway sustituye estos placeholders con variables de entorno
-- (ver .env.example):
--   demo_password_hash -> DEMO_PASSWORD_HASH (BCrypt)
--   canal1_key_hash    -> CANAL1_KEY_HASH    (SHA-256 en hexadecimal)
--   canal2_key_hash    -> CANAL2_KEY_HASH    (SHA-256 en hexadecimal)
-- Las reservas de prueba van en el objetivo 2.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Datos del hotel y fiscales (HU-ADM-08). Las horas 15:00 y 12:00 son
-- constantes del sistema. NIT ficticio con dígito verificador válido.
-- ---------------------------------------------------------------------
INSERT INTO configuracion_hotel
    (id, nombre, descripcion, direccion, telefono, correo,
     nombre_comercial, razon_social, nit, direccion_fiscal)
VALUES
    (1, 'Villa Serena',
     'Hotel boutique de 12 habitaciones en el corazón de Antigua Guatemala, con jardín colonial y vista a los volcanes.',
     '5a Avenida Norte 12, Antigua Guatemala, Sacatepéquez',
     '+502 7832 0000', 'reservas@villaserena.test',
     'Hotel Villa Serena', 'Villa Serena Hotelera, S.A.', '4817205-7',
     '5a Avenida Norte 12, Antigua Guatemala, Sacatepéquez');

-- Serie fija de la factura de demostración (RN-FAC-004). La primera será VS-A 1.
INSERT INTO series_factura (serie, numero_inicial, ultimo_numero)
VALUES ('VS-A', 1, 0);

-- ---------------------------------------------------------------------
-- Tipos de habitación (HU-ADM-03) con su ajuste de fin de semana (HU-ADM-07)
-- ---------------------------------------------------------------------
INSERT INTO tipos_habitacion (nombre, descripcion, capacidad, precio_base, ajuste_fin_semana_pct)
VALUES
    ('Doble Superior', 'Dos camas matrimoniales con vista al jardín.', 4, 850.00, 25.00),
    ('Suite Volcán', 'Cama king, terraza privada y vista al Volcán de Agua.', 2, 1450.00, 20.00),
    ('Estándar Jardín', 'Cama queen con acceso directo al jardín colonial.', 2, 650.00, 10.00),
    ('Suite Familiar', 'Dos ambientes, una cama king y dos individuales, con sala.', 5, 1800.00, 15.00);

-- ---------------------------------------------------------------------
-- Habitaciones: nacen LIBRE + LIMPIA y ACTIVO (valores por defecto, HU-ADM-04)
-- ---------------------------------------------------------------------
INSERT INTO habitaciones (numero, piso, tipo_habitacion_id)
SELECT h.numero, h.piso, t.id
FROM (VALUES
    ('101', 1, 'Estándar Jardín'),
    ('102', 1, 'Estándar Jardín'),
    ('103', 1, 'Doble Superior'),
    ('104', 1, 'Doble Superior'),
    ('105', 1, 'Doble Superior'),
    ('201', 2, 'Suite Volcán'),
    ('202', 2, 'Suite Volcán'),
    ('203', 2, 'Doble Superior'),
    ('204', 2, 'Estándar Jardín'),
    ('301', 3, 'Suite Familiar'),
    ('302', 3, 'Suite Familiar'),
    ('303', 3, 'Suite Volcán')
) AS h (numero, piso, tipo)
JOIN tipos_habitacion t ON t.nombre = h.tipo;

-- ---------------------------------------------------------------------
-- Temporadas para todos los tipos (HU-ADM-06)
-- ---------------------------------------------------------------------
INSERT INTO temporadas (nombre, fecha_inicio, fecha_fin, ajuste_pct, aplica_a_todos)
VALUES
    ('Temporada alta', '2026-12-15', '2027-01-10', 20.00, TRUE),
    ('Temporada baja', '2027-05-01', '2027-06-30', -10.00, TRUE);

-- ---------------------------------------------------------------------
-- Menú de Room Service: 3 categorías, todo DISPONIBLE (HU-ADM-05)
-- ---------------------------------------------------------------------
INSERT INTO items_menu (categoria, nombre, descripcion, precio)
VALUES
    ('Desayunos', 'Desayuno chapín', 'Huevos al gusto, frijoles volteados, plátanos fritos, crema, queso y tortillas.', 75.00),
    ('Desayunos', 'Panqueques con frutas', 'Tres panqueques con miel, mantequilla y frutas de temporada.', 60.00),
    ('Desayunos', 'Omelette de vegetales', 'Omelette con chile pimiento, cebolla, tomate y queso, con pan tostado.', 65.00),
    ('Platos fuertes', 'Pepián de pollo', 'Pepián tradicional con arroz y tamalitos.', 110.00),
    ('Platos fuertes', 'Hilachas', 'Carne deshilachada en salsa de tomate y miltomate, con arroz.', 95.00),
    ('Platos fuertes', 'Lomito a la parrilla', 'Lomito de res con chirmol, papas y ensalada.', 145.00),
    ('Platos fuertes', 'Pasta Alfredo', 'Fettuccine en salsa Alfredo con pollo a la plancha.', 90.00),
    ('Bebidas', 'Café de Antigua', 'Taza de café de altura de Antigua Guatemala.', 25.00),
    ('Bebidas', 'Licuado de frutas', 'Licuado en agua o leche, con fruta de temporada.', 30.00),
    ('Bebidas', 'Limonada con soda', 'Limonada natural con agua mineral.', 20.00),
    ('Bebidas', 'Agua pura', 'Botella de 600 ml.', 12.00);

-- ---------------------------------------------------------------------
-- Artículos que el huésped puede pedir, con su máximo (documento 08 §5)
-- ---------------------------------------------------------------------
INSERT INTO articulos (nombre, cantidad_maxima)
VALUES
    ('Toalla de baño', 4),
    ('Toalla de mano', 4),
    ('Almohada', 2),
    ('Cobija', 2),
    ('Papel higiénico', 4),
    ('Jabón', 3);

-- ---------------------------------------------------------------------
-- Canales simulados (AD-13). Solo el hash de la clave.
-- ---------------------------------------------------------------------
INSERT INTO canales (codigo, nombre, clave_hash)
VALUES
    ('BOOKING', 'Booking simulado', '${canal1_key_hash}'),
    ('EXPEDIA', 'Expedia simulado', '${canal2_key_hash}');

-- ---------------------------------------------------------------------
-- Empleados de prueba: 2 ADMIN, 1 RECEPCION, 1 ROOM_SERVICE y 3
-- MANTENIMIENTO_LIMPIEZA (uno por área). Todos ACTIVO, sin contraseña
-- temporal y con el mismo hash BCrypt de demostración (V-04).
-- ---------------------------------------------------------------------
INSERT INTO empleados
    (nombre_completo, correo, telefono, rol, area, contrasena_hash, debe_cambiar_contrasena)
VALUES
    ('Sofía Morales', 'sofia.morales@villaserena.test', '+502 5000 0001', 'ADMIN', NULL, '${demo_password_hash}', FALSE),
    ('Diego Castillo', 'diego.castillo@villaserena.test', '+502 5000 0002', 'ADMIN', NULL, '${demo_password_hash}', FALSE),
    ('Ana Pérez', 'ana.perez@villaserena.test', '+502 5000 0003', 'RECEPCION', NULL, '${demo_password_hash}', FALSE),
    ('Rodrigo Ajú', 'rodrigo.aju@villaserena.test', '+502 5000 0004', 'ROOM_SERVICE', NULL, '${demo_password_hash}', FALSE),
    ('Luis García', 'luis.garcia@villaserena.test', '+502 5000 0005', 'MANTENIMIENTO_LIMPIEZA', 'LIMPIEZA', '${demo_password_hash}', FALSE),
    ('Marta Xicará', 'marta.xicara@villaserena.test', '+502 5000 0006', 'MANTENIMIENTO_LIMPIEZA', 'MANTENIMIENTO', '${demo_password_hash}', FALSE),
    ('Pedro Coy', 'pedro.coy@villaserena.test', '+502 5000 0007', 'MANTENIMIENTO_LIMPIEZA', 'AMBAS', '${demo_password_hash}', FALSE);
