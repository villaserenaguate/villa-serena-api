# Villa Serena — Arquitectura y base de datos

## 1. Alcance de esta etapa

Lograr **una reserva exitosa** desde la web del hotel:

1. Buscar habitaciones disponibles por fechas y número de huéspedes (adultos y niños).
2. Elegir un tipo de habitación.
3. Dejar los datos del huésped y confirmar.
4. Recibir un código de reserva.

Esta etapa cubre base de datos y backend. El frontend viene después, contra el contrato de `01-contrato-api.md`.

**Fuera de alcance por ahora:** pagos, autenticación, panel de administración, cancelaciones, correos de confirmación, imágenes subidas, ubicación dinámica (el mapa o dirección se maneja como contenido estático en el frontend).

## 2. Stack

| Capa | Tecnología |
|---|---|
| Lenguaje | Java 21 |
| Framework | Spring Boot 4 (Spring Framework 7) |
| Acceso a datos | `JdbcClient` (SQL explícito, sin JPA) |
| Base de datos | PostgreSQL |
| Migraciones | Flyway |
| Errores | `ProblemDetail` (RFC 9457) |

### Notas específicas de Spring Boot 4

- El starter web se llama `spring-boot-starter-webmvc`.
- Flyway necesita su propio starter, `spring-boot-starter-flyway`, además del módulo `flyway-database-postgresql`. Con solo `flyway-core` ya no se autoconfigura.
- Los starters de JDBC y Validation mantienen sus nombres (`spring-boot-starter-jdbc`, `spring-boot-starter-validation`).
- Jackson 3 es el serializador por defecto. Para este API (records, `LocalDate`, `OffsetDateTime`, `BigDecimal`) no requiere configuración especial.

## 3. Estructura de código propuesta

Un solo package, sin capas extra: el dominio es pequeño y el SQL es directo.

```
<package base>/
├── BookingController.java        # 3 endpoints
├── BookingService.java           # reglas de negocio + SQL
├── ApiException.java             # error de dominio (status + code)
├── ApiExceptionHandler.java      # traduce errores a ProblemDetail
├── ClockConfig.java              # Clock con la zona horaria del hotel
└── dto/
    ├── GuestDto.java
    ├── BookingRequest.java
    ├── BookingResponse.java
    ├── RoomTypeRef.java
    ├── RoomTypeAvailability.java
    └── AvailabilityResponse.java
```

La estructura es una sugerencia. Si el proyecto ya tiene otra organización (por ejemplo hexagonal), se puede adaptar mientras el contrato de `01-contrato-api.md` se mantenga igual.

## 4. Modelo de datos

```
room_types 1 ───< rooms 1 ───< bookings
```

### `room_types` — categorías de habitación

| Columna | Tipo | Notas |
|---|---|---|
| `id` | BIGSERIAL PK | |
| `name` | VARCHAR(100) | |
| `description` | TEXT | opcional |
| `image_url` | TEXT | opcional |
| `price_per_night` | NUMERIC(10,2) | ≥ 0 |
| `max_adults` | SMALLINT | > 0 |
| `max_children` | SMALLINT | ≥ 0, default 0 |

### `rooms` — habitaciones físicas

| Columna | Tipo | Notas |
|---|---|---|
| `id` | BIGSERIAL PK | |
| `room_type_id` | BIGINT FK → `room_types` | indexado |
| `room_number` | VARCHAR(10) UNIQUE | |
| `active` | BOOLEAN | default `TRUE`; permite sacar una habitación de servicio sin borrarla |

### `bookings` — reservas

| Columna | Tipo | Notas |
|---|---|---|
| `id` | BIGSERIAL PK | interno |
| `code` | VARCHAR(12) UNIQUE | identificador público |
| `room_id` | BIGINT FK → `rooms` | la habitación asignada |
| `guest_name`, `guest_email`, `guest_phone` | VARCHAR | el huésped va dentro de la reserva (sin tabla de clientes por ahora) |
| `check_in`, `check_out` | DATE | `check_out > check_in` |
| `adults`, `children` | SMALLINT | |
| `price_per_night` | NUMERIC(10,2) | tarifa congelada al reservar |
| `total_price` | NUMERIC(10,2) | `price_per_night × noches` |
| `status` | VARCHAR(20) | `CONFIRMED` \| `CANCELLED` |
| `created_at` | TIMESTAMPTZ | default `now()` |

## 5. Decisiones de diseño

**5.1 Disponibilidad calculada, no almacenada.** No existe una tabla de "días disponibles". Una habitación está libre en un rango si no tiene ninguna reserva `CONFIRMED` que se solape:

```
reserva.check_in < :checkOut  AND  reserva.check_out > :checkIn
```

Con esta regla, una salida el día 12 y una entrada el día 12 no chocan (el día de salida no cuenta como noche ocupada).

**5.2 La base de datos impide la doble reserva.** `bookings` tiene un `EXCLUDE USING gist` sobre `(room_id, daterange(check_in, check_out))` para reservas `CONFIRMED`. Aunque dos personas confirmen a la vez, PostgreSQL rechaza la segunda y el backend lo traduce a `409 NO_AVAILABILITY`. Requiere la extensión `btree_gist` (la crea la migración V1).

**5.3 Se reserva un tipo, el servidor elige la habitación.** El cliente nunca ve números de habitación. El backend toma la primera habitación activa y libre del tipo pedido (orden por `id`).

**5.4 Precio congelado.** `price_per_night` y `total_price` se copian a la reserva. Si el hotel cambia tarifas después, las reservas existentes no cambian.

**5.5 "Hoy" depende de la zona horaria del hotel.** La validación `checkIn >= hoy` usa un `Clock` configurado con `hotel.timezone`, no la zona del servidor.

**5.6 Errores con código estable.** El frontend se apoya en `code` (ver el catálogo en `01-contrato-api.md`), no en el texto del mensaje.

## 6. Migraciones con Flyway

Ubicación: `src/main/resources/db/migration`.

| Archivo | Contenido |
|---|---|
| `V1__create_schema.sql` | Extensión `btree_gist`, tablas, índices y la restricción anti-solapamiento |
| `V2__seed_room_types.sql` | Datos de prueba: 2 tipos de habitación y 5 habitaciones |

Convenciones:

- Una migración aplicada **no se edita**; los cambios van en una nueva (`V3__...`).
- Los datos de prueba de V2 sirven para desarrollo. Antes de producción conviene moverlos a un profile de desarrollo o reemplazarlos por el catálogo real del hotel.
- El código del repositorio de este documento está en `03-codigo.md`.

## 7. Configuración

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/<nombre_bd>
    username: <usuario>
    password: <password>
hotel:
  timezone: America/Guatemala
```

`hotel.timezone` acepta cualquier zona IANA. El valor `America/Guatemala` es el valor inicial sugerido y se puede cambiar sin tocar código.

## 8. Cómo verificar que funciona

1. Arrancar la app y confirmar que Flyway aplicó V1 y V2 (tabla `flyway_schema_history` con 2 filas).
2. `GET /api/v1/room-types/availability` con fechas futuras y 2 adultos: deben salir los 2 tipos, con `availableRooms` 3 y 2.
3. `POST /api/v1/bookings` para el tipo 1: responde 201 con `Location` y un `code`.
4. Repetir el `GET` del paso 2: el tipo 1 baja a `availableRooms: 2`.
5. Repetir el `POST` hasta agotar el tipo 1: la última llamada responde 409 `NO_AVAILABILITY`.
6. `GET /api/v1/bookings/{code}` con el código recibido: responde 200 con la misma información.
7. Probar un error de cada fila del catálogo (fechas pasadas, `adults: 0`, `roomTypeId` inexistente, 5 adultos en el tipo 1, código inexistente) y confirmar el `code` y el HTTP status.

## 9. Limitación conocida

Si dos peticiones simultáneas eligen la misma habitación libre mientras otra del mismo tipo sigue libre, la segunda recibe `409` aunque técnicamente había cupo. El `EXCLUDE` garantiza que nunca haya doble reserva; lo que no hace esta primera versión es reintentar con otra habitación. Es una mejora pequeña para una etapa posterior.
