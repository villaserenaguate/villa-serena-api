# Esquema propuesto de la base de datos (Nivel 1)

> **Objetivo:** OBJ-0C — API: esquema y datos iniciales (PASO 1, propuesta)
> **Estado:** ✅ Aprobado por Josué el 1 de octubre de 2026
> **Fuentes:** documentos 07, 08, 10 y 14 (Documentación V3), `HU - Administrador.md` y el contrato `openapi.yaml` (PR #2)
> **Siguiente paso:** PASO 2 — migraciones Flyway (`V1__esquema.sql` y las que hagan falta) con base en este documento

No incluye tablas de Nivel 2 (turnos, inventario, amenidades ni Wi-Fi).

---

## 1. Convenciones

- Llave primaria: `id BIGINT GENERATED ALWAYS AS IDENTITY`.
- Estados y códigos: `VARCHAR` con `CHECK` de los valores exactos del documento 07.
- Fechas con hora: `TIMESTAMPTZ` (se guardan en UTC, AD-19). Fechas de estadía: `DATE`.
- Montos: `NUMERIC(12,2)`, en quetzales. Porcentajes de ajuste: `NUMERIC(5,2)`.
- Correos únicos sin distinguir mayúsculas: índice único sobre `lower(correo)`.
- Fotos y PDF: se guarda la **clave del objeto** en MinIO, no la URL. El API arma la URL que devuelve el contrato; así el paso a Cloudflare R2 no cambia datos (AD-08).
- `refresh_tokens`, `codigos_otp`, contraseñas y claves de canal guardan **solo el hash**.
- Extensión requerida: `btree_gist` (para el `EXCLUDE` de reservas).

## 2. Decisiones de la revisión

| # | Decisión |
|---|---|
| D-1 | `Hotel.ubicacion` del contrato queda solo con `direccion`; se quitaron `latitud` y `longitud` (PR #2). |
| D-2 | El ajuste de fin de semana va **por tipo de habitación** (`tipos_habitacion.ajuste_fin_semana_pct`), como dicen HU-ADM-07 y RN-TAR-012; no en `configuracion_hotel`. |
| D-3 | Las horas de check-in (15:00) y check-out (12:00) **no se guardan**: son constantes del sistema (HU-ADM-08, R-01). |
| D-4 | El ticket del WebSocket (`/auth/ws-ticket`, 60 s, un solo uso) se guarda **en memoria**, sin tabla. |
| D-5 | Se agregan `fotos_hotel`, `fotos_tipo_habitacion`, `temporada_tipos_habitacion`, `reserva_noches` y `stripe_eventos`. **No** hay tabla de categorías del menú: `items_menu.categoria VARCHAR(60)` (el menú solo viene de los datos iniciales). |
| D-6 | De la asignación de habitación se guarda solo la última: `habitacion_asignada_en` y `habitacion_asignada_por_empleado_id` en `reservas`. |
| D-7 | `historial_estados`: `id_responsable` es FK a `empleados` (nulo si no fue un empleado), la habitación se registra como `HABITACION_OCUPACION` o `HABITACION_CONDICION`, y se agrega la columna `motivo`. |

## 3. Tablas por módulo

Las marcadas con **(+)** no estaban en la lista guía del prompt y se aprobaron en la revisión.

### 3.1 Seguridad

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `empleados` | nombre_completo VARCHAR(150), correo VARCHAR(150), telefono VARCHAR(30), rol, area (nula), estado, contrasena_hash, debe_cambiar_contrasena BOOLEAN, intentos_fallidos INT, bloqueado_hasta TIMESTAMPTZ, creado_en | — | UNIQUE `lower(correo)`; CHECK rol ∈ (ADMIN, RECEPCION, ROOM_SERVICE, MANTENIMIENTO_LIMPIEZA); CHECK area ∈ (LIMPIEZA, MANTENIMIENTO, AMBAS); CHECK `(rol = 'MANTENIMIENTO_LIMPIEZA') = (area IS NOT NULL)`; CHECK estado ∈ (ACTIVO, INACTIVO) | 08 §3.1; RN-PER-007, 008, 013; 14 §6 |
| `refresh_tokens` | token_hash, tipo_usuario (EMPLEADO, HUESPED), empleado_id, huesped_id, expira_en, revocado_en, creado_en | empleados, huespedes | UNIQUE token_hash; CHECK solo uno de empleado_id / huesped_id, según tipo_usuario | 14 §6; PAR-25, PAR-26 |
| `codigos_otp` | huesped_id, codigo_hash, expira_en, usado_en, creado_en | huespedes | — | PAR-14; RN-APP-001 |
| `dispositivos_push` | huesped_id, token_expo, creado_en | huespedes | UNIQUE token_expo | AD-10; RN-NOT-004; 14 §6.1 |

El bloqueo por OTP (5 intentos, 15 minutos, PAR-15) vive en `huespedes`, no en el código, para que pedir un código nuevo no lo evite.

### 3.2 Huéspedes

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `huespedes` | nombre_completo VARCHAR(150), correo VARCHAR(150), telefono VARCHAR(30), nacionalidad VARCHAR(60), tipo_documento, numero_documento VARCHAR(30), otp_intentos_fallidos INT, otp_bloqueado_hasta TIMESTAMPTZ, creado_en | — | UNIQUE `lower(correo)`; CHECK tipo_documento ∈ (DPI, PASAPORTE) | 08 §4; RN-RES-019; contrato `HuespedDatos` |
| `huespedes_adicionales` | reserva_id, nombre_completo VARCHAR(150), tipo_documento, numero_documento VARCHAR(30), nacionalidad VARCHAR(60) | reservas | CHECK tipo_documento ∈ (DPI, PASAPORTE) | RN-RES-020; contrato `HuespedAdicionalDatos` |

"Principal + adicionales ≤ número de huéspedes" se valida en el servicio.

### 3.3 Catálogos

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `configuracion_hotel` | nombre, descripcion, direccion, telefono, correo, nombre_comercial, razon_social, nit, direccion_fiscal | — | Una sola fila: CHECK `id = 1` | HU-ADM-08 (C1, C2) |
| `fotos_hotel` (+) | clave_objeto, orden | — | — | HU-ADM-08 C1; HU-HUE-01 C1 |
| `tipos_habitacion` | nombre VARCHAR(100), descripcion, capacidad INT, precio_base NUMERIC(12,2), ajuste_fin_semana_pct NUMERIC(5,2) DEFAULT 0, estado | — | UNIQUE nombre; CHECK capacidad ≥ 1; CHECK precio_base > 0; CHECK ajuste_fin_semana_pct > −100; CHECK estado ∈ (ACTIVO, INACTIVO) | HU-ADM-03, HU-ADM-07; RN-HAB-009; RN-TAR-004, 012 |
| `fotos_tipo_habitacion` (+) | tipo_habitacion_id, clave_objeto, es_principal BOOLEAN, orden | tipos_habitacion | Índice único parcial: una sola foto principal por tipo | HU-ADM-03 C2 |
| `habitaciones` | numero VARCHAR(10), piso INT, tipo_habitacion_id, ocupacion, condicion, estado, limpieza_empleado_id (nula) | tipos_habitacion, empleados | UNIQUE numero; CHECK ocupacion ∈ (LIBRE, OCUPADA); CHECK condicion ∈ (LIMPIA, SUCIA, EN_LIMPIEZA, FUERA_DE_SERVICIO); CHECK estado ∈ (ACTIVO, INACTIVO); CHECK `(condicion = 'EN_LIMPIEZA') = (limpieza_empleado_id IS NOT NULL)` | HU-ADM-04; 07 §4; RN-HAB-007, 011 |
| `temporadas` | nombre, fecha_inicio DATE, fecha_fin DATE, ajuste_pct NUMERIC(5,2), aplica_a_todos BOOLEAN | — | CHECK fecha_fin ≥ fecha_inicio; CHECK ajuste_pct > −100 | HU-ADM-06; RN-TAR-004, 011 |
| `temporada_tipos_habitacion` (+) | temporada_id, tipo_habitacion_id | temporadas, tipos_habitacion | PK (temporada_id, tipo_habitacion_id) | HU-ADM-06 C2 |
| `items_menu` | categoria VARCHAR(60), nombre, descripcion, precio NUMERIC(12,2), clave_foto (nula), disponibilidad, estado, agotado_en, agotado_por_empleado_id | empleados | CHECK precio > 0; CHECK disponibilidad ∈ (DISPONIBLE, AGOTADO); CHECK estado ∈ (ACTIVO, INACTIVO) | HU-ADM-05; RN-RS-008, 013; 07 §9 |
| `articulos` | nombre, cantidad_maxima INT | — | UNIQUE nombre; CHECK cantidad_maxima ≥ 1 | 08 §5 |

- El traslape de temporadas por tipo (RN-TAR-003) se valida en el servicio.
- "Tiempo que lleva `SUCIA`" (RN-LIM-010) se obtiene de `historial_estados`.

### 3.4 Reservas

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `reservas` | codigo VARCHAR(9), huesped_id, tipo_habitacion_id, habitacion_id (nula), fecha_entrada DATE, fecha_salida DATE, numero_huespedes INT, estado, canal, identificador_externo VARCHAR(60) (nulo), total NUMERIC(12,2), creada_por_empleado_id (nula), creada_en, habitacion_asignada_en, habitacion_asignada_por_empleado_id | huespedes, tipos_habitacion, habitaciones, empleados | UNIQUE codigo; CHECK codigo `~ '^VS-[A-Z0-9]{6}$'`; CHECK estado ∈ (PENDIENTE_PAGO, CONFIRMADA, EN_ESTADIA, FINALIZADA, CANCELADA); CHECK canal ∈ (DIRECTO_WEB, RECEPCION, BOOKING, EXPEDIA); CHECK `(canal IN ('BOOKING','EXPEDIA')) = (identificador_externo IS NOT NULL)`; UNIQUE (canal, identificador_externo); CHECK fecha_salida > fecha_entrada; CHECK `fecha_salida - fecha_entrada <= 30`; CHECK numero_huespedes ≥ 1; **EXCLUDE** (abajo) | 07 §3; RN-RES-005, 009, 010, 011, 013; contrato `ReservaDetalle` |
| `reserva_noches` (+) | reserva_id, fecha DATE, precio NUMERIC(12,2), temporada_nombre (nulo), fin_de_semana BOOLEAN | reservas | UNIQUE (reserva_id, fecha) | HU-REC-13 C1; RN-TAR-006, 007, 010 |

```sql
EXCLUDE USING gist (
  habitacion_id WITH =,
  daterange(fecha_entrada, fecha_salida, '[)') WITH &&
) WHERE (estado IN ('PENDIENTE_PAGO', 'CONFIRMADA', 'EN_ESTADIA'))
```

- Con `'[)'`, la salida de una reserva y la entrada de la siguiente pueden ser el mismo día. Las filas con `habitacion_id` nulo no chocan.
- Al cancelar se pone `habitacion_id = NULL` (el contrato devuelve `habitacion: null`).
- Se calculan y no se guardan: `noches`, `saldoPendiente`, `pagoVenceEn` (`creada_en` + 30 minutos) y el responsable "Cliente web" del historial.
- Las reservas de canal no tienen filas en `reserva_noches`: su alojamiento es una sola línea (RN-TAR-010).

### 3.5 Cuentas y pagos

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `cuentas` | reserva_id, estado, abierta_en, cerrada_en | reservas | UNIQUE reserva_id; CHECK estado ∈ (ABIERTA, CERRADA) | 07 §5.1 (E-01) |
| `cargos` | cuenta_id, tipo, categoria_servicio (nula), concepto, cantidad, precio_unitario, total, estado, pedido_id (nulo), creado_por_empleado_id (nulo), creado_en, motivo_anulacion, anulado_por_empleado_id, anulado_en | cuentas, pedidos, empleados | **UNIQUE pedido_id**; CHECK tipo ∈ (ALOJAMIENTO, ROOM_SERVICE, SERVICIO); CHECK categoria_servicio ∈ (RESTAURANTE, LAVANDERIA, ESTACIONAMIENTO, OTRO) y solo con tipo SERVICIO; CHECK `(tipo = 'ROOM_SERVICE') = (pedido_id IS NOT NULL)`; CHECK cantidad > 0 y precio_unitario > 0; CHECK estado ∈ (VIGENTE, ANULADO); CHECK `(estado = 'ANULADO') = (motivo_anulacion IS NOT NULL)`; CHECK que un cargo de ALOJAMIENTO no esté ANULADO | 07 §5.2; RN-PAG-011, 019; RN-RS-007 |
| `pagos` | cuenta_id, metodo, estado, monto, referencia (nula), stripe_session_id (nulo), stripe_payment_intent_id (nulo), registrado_por_empleado_id (nulo), creado_en, aprobado_en, reembolsado_en | cuentas, empleados | CHECK metodo ∈ (STRIPE, CANAL, EFECTIVO, TARJETA, OTRO); CHECK estado ∈ (PENDIENTE, APROBADO, FALLIDO, REEMBOLSADO); CHECK monto > 0; UNIQUE stripe_session_id; CHECK `(metodo = 'STRIPE') = (stripe_session_id IS NOT NULL)` | 07 §5.3; RN-PAG-003, 008, 013, 014; RN-IND-001 |
| `stripe_eventos` (+) | evento_id VARCHAR (PK), tipo, recibido_en | — | PK evento_id | 14 AD-17 y §6; RN-PAG-002 |

- `aprobado_en` define el rango de los ingresos (RN-IND-001); `stripe_payment_intent_id` se usa para el reembolso total (P6).
- `urlPago` y `expiraEn` del contrato se consultan a Stripe con `stripe_session_id`; no se guardan.

### 3.6 Room Service

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `pedidos` | reserva_id, estado, notas (nula), creado_en | reservas | CHECK estado ∈ (NUEVO, EN_PREPARACION, EN_CAMINO, ENTREGADO, CANCELADO) | 07 §6; HU-HUE-10 C4; HU-RS-02 C2 |
| `pedido_items` | pedido_id, item_menu_id, cantidad INT, precio_unitario NUMERIC(12,2) | pedidos, items_menu | CHECK cantidad > 0; CHECK precio_unitario > 0 | RN-RS-006 (precio congelado) |

El "Pedido #n" del concepto del cargo es el `id` del pedido. El motivo de cancelación queda en `historial_estados`.

### 3.7 Solicitudes

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `solicitudes` | reserva_id, habitacion_id, tipo, estado, comentario (nulo), empleado_id (nulo), creado_en | reservas, habitaciones, empleados | CHECK tipo ∈ (LIMPIEZA, ARTICULOS); CHECK estado ∈ (PENDIENTE, EN_PROCESO, ATENDIDA, CANCELADA); **índice único parcial** `(habitacion_id) WHERE tipo = 'LIMPIEZA' AND estado IN ('PENDIENTE', 'EN_PROCESO')` | 07 §7; RN-LIM-005; HU-HUE-12 C2 |
| `solicitud_items` | solicitud_id, articulo_id, cantidad INT | solicitudes, articulos | CHECK cantidad > 0; UNIQUE (solicitud_id, articulo_id) | HU-HUE-13; RN-LIM-007 |

- `habitacion_id` se copia de la reserva solo para que el índice único parcial sea posible.
- "Cantidad ≤ máximo del artículo" se valida en el servicio.

### 3.8 Incidencias

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `incidencias` | habitacion_id, descripcion, impide_uso BOOLEAN, clave_foto (nula, bucket privado), estado, reportada_por_empleado_id, tecnico_id (nulo), solucion (nula), creado_en | habitaciones, empleados | CHECK estado ∈ (REPORTADA, EN_PROCESO, RESUELTA); CHECK `estado IN ('EN_PROCESO','RESUELTA')` ⇒ tecnico_id NOT NULL; CHECK `(estado = 'RESUELTA') = (solucion IS NOT NULL)` | 07 §8; RN-MAN-001, 009, 010; HU-ADM-10 |

`creado_en` es el `reportadaEn` del contrato; las fechas de tomar y resolver salen de `historial_estados`.

### 3.9 Facturación

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `series_factura` | serie VARCHAR(10), numero_inicial INT, ultimo_numero INT | — | UNIQUE serie; CHECK ultimo_numero ≥ numero_inicial − 1 | RN-FAC-004; HU-ADM-08 C3 |
| `facturas` | cuenta_id, serie_id, numero INT, estado, emitida_en, nit_comprador (NIT o "CF"), nombre_comprador, total, clave_pdf; copia del hotel: nombre_comercial, razon_social, nit_hotel, direccion_fiscal, direccion | cuentas, series_factura | **UNIQUE cuenta_id**; **UNIQUE (serie_id, numero)**; CHECK estado = 'EMITIDA' | 07 §5.4; RN-FAC-001, 002, 005, 008, 009 |

- El correlativo se toma con `SELECT … FOR UPDATE` sobre `series_factura` dentro del check-out.
- Los datos del hotel se copian en la factura porque la reimpresión se arma en el navegador (RN-FAC-007) y cambiar la configuración no debe alterar facturas emitidas (RN-FAC-009).

### 3.10 Canales

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `canales` | codigo, nombre, clave_hash (SHA-256 en hexadecimal) | — | UNIQUE codigo; CHECK codigo ∈ (BOOKING, EXPEDIA) | AD-13; RN-CM-001; contrato `X-Canal-Codigo` |

`reservas.canal` usa CHECK con los 4 orígenes, sin FK a `canales` (DIRECTO_WEB y RECEPCION no son canales externos).

### 3.11 Sistema

| Tabla | Columnas principales | FK | Restricciones | Origen |
|---|---|---|---|---|
| `historial_estados` | tipo_entidad, id_entidad BIGINT, estado_anterior (nulo), estado_nuevo, tipo_responsable, id_responsable (nulo), motivo (nulo), fecha | id_responsable → empleados | CHECK tipo_entidad ∈ (RESERVA, HABITACION_OCUPACION, HABITACION_CONDICION, PEDIDO, SOLICITUD, INCIDENCIA); CHECK tipo_responsable ∈ (EMPLEADO, HUESPED, CLIENTE, CANAL, STRIPE, SISTEMA); CHECK `(tipo_responsable = 'EMPLEADO') = (id_responsable IS NOT NULL)`; índice (tipo_entidad, id_entidad) | 07 RG-EST-02; 14 §5; contrato `HistorialEstado` |
| `outbox` | tipo, destinatario, payload JSONB, estado, intentos INT, proximo_intento_en, ultimo_error, creado_en, enviado_en | — | CHECK tipo ∈ (CORREO_CONFIRMACION, CORREO_OTP, CORREO_FACTURA, PUSH_PEDIDO_ENTREGADO, PUSH_SOLICITUD_ATENDIDA); CHECK estado ∈ (PENDIENTE, ENVIADO, FALLIDO) | 14 AD-12 y §5; RN-NOT-002, 003 |

Cuando actúa el huésped, su identidad sale de la reserva; el nombre del empleado responsable se obtiene con un JOIN a `empleados`.

## 4. Restricciones del documento 14, sección 5

| Restricción | Regla | Tabla | Mecanismo |
|---|---|---|---|
| Sin reservas traslapadas en la misma habitación | RN-RES-002 | `reservas` | `EXCLUDE USING gist` con `daterange '[)'` y `WHERE estado IN (PENDIENTE_PAGO, CONFIRMADA, EN_ESTADIA)` |
| Número de habitación único | RN-HAB-007 | `habitaciones` | UNIQUE numero |
| Correo único de empleado | RN-PER-008 | `empleados` | UNIQUE `lower(correo)` |
| Correo único de huésped | RN-RES-019 | `huespedes` | UNIQUE `lower(correo)` |
| Una reserva por canal e identificador externo | RN-CM-004 | `reservas` | UNIQUE (canal, identificador_externo) |
| Un solo cargo por pedido | RN-RS-007 | `cargos` | UNIQUE pedido_id |
| Una sola factura por cuenta | RN-FAC-001 | `facturas` | UNIQUE cuenta_id |
| Una sola solicitud de limpieza activa por habitación | RN-LIM-005 | `solicitudes` | Índice único parcial `(habitacion_id) WHERE tipo = 'LIMPIEZA' AND estado IN ('PENDIENTE','EN_PROCESO')` |
| Correlativo de factura único por serie | RN-FAC-004 | `facturas` | UNIQUE (serie_id, numero) |
| Stock ≥ 0 | RN-INV-002 | — | No aplica: inventario es Nivel 2 |
