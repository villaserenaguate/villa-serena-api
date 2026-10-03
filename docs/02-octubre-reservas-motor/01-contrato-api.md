# Villa Serena — Contrato del API (v1)

Este documento es el acuerdo entre backend y frontend. Si el código y este documento difieren, el documento manda: el frontend se construye contra él.

## 1. Convenciones

| Tema | Convención |
|---|---|
| Base URL | `/api/v1` |
| Formato | JSON (`Content-Type: application/json`) |
| Fechas | `yyyy-MM-dd` (ej. `2026-11-10`) |
| Fecha y hora | ISO-8601 con zona (ej. `2026-10-03T14:22:10.123456Z`) |
| Dinero | número con 2 decimales (ej. `450.00`). El API no expone moneda |
| Autenticación | ninguna por ahora |
| Noches | `checkOut - checkIn`. El día de salida no cuenta como noche ocupada |

**Reserva por tipo de habitación.** El cliente elige un *tipo* (Sencilla, Familiar, ...). El servidor asigna la habitación concreta; el número de habitación no se expone.

## 2. Flujo esperado desde el frontend

1. El usuario elige fechas, adultos y niños → `GET /room-types/availability`.
2. El usuario elige un tipo de habitación de la lista.
3. El usuario llena sus datos → `POST /bookings`.
4. Se muestra el `code` de confirmación (y, si se recarga la página, `GET /bookings/{code}`).
5. Si el POST responde `409 NO_AVAILABILITY`, se vuelve a ejecutar el paso 1 para refrescar la lista.

---

## 3. Endpoints

### 3.1 `GET /api/v1/room-types/availability`

Lista los tipos de habitación que tienen capacidad suficiente y al menos una habitación libre en el rango.

**Query params**

| Param | Tipo | Requerido | Regla |
|---|---|---|---|
| `checkIn` | date | sí | no puede ser anterior a hoy |
| `checkOut` | date | sí | posterior a `checkIn` |
| `adults` | int | sí | ≥ 1 |
| `children` | int | no (default `0`) | ≥ 0 |

**200 OK**

```json
{
  "checkIn": "2026-11-10",
  "checkOut": "2026-11-12",
  "nights": 2,
  "adults": 2,
  "children": 0,
  "roomTypes": [
    {
      "id": 1,
      "name": "Habitación Sencilla",
      "description": "Cama queen, baño privado",
      "imageUrl": null,
      "maxAdults": 2,
      "maxChildren": 1,
      "pricePerNight": 450.00,
      "totalPrice": 900.00,
      "availableRooms": 3
    }
  ]
}
```

| Campo | Descripción |
|---|---|
| `roomTypes` | Ordenado por `pricePerNight` ascendente. Es `[]` si nada cumple (sigue siendo 200) |
| `totalPrice` | `pricePerNight × nights` |
| `availableRooms` | Cuántas habitaciones de ese tipo están libres en el rango |
| `imageUrl` | Puede ser `null` |

**Errores posibles:** `400 VALIDATION_ERROR`, `400 INVALID_DATES`.

---

### 3.2 `POST /api/v1/bookings`

Crea una reserva confirmada.

**Request**

```json
{
  "roomTypeId": 1,
  "checkIn": "2026-11-10",
  "checkOut": "2026-11-12",
  "adults": 2,
  "children": 0,
  "guest": {
    "fullName": "Juan Pérez",
    "email": "juan@correo.com",
    "phone": "+502 5555 5555"
  }
}
```

| Campo | Requerido | Regla |
|---|---|---|
| `roomTypeId` | sí | debe existir |
| `checkIn` | sí | no puede ser anterior a hoy |
| `checkOut` | sí | posterior a `checkIn` |
| `adults` | sí | ≥ 1 |
| `children` | no (default `0`) | ≥ 0 |
| `guest.fullName` | sí | no vacío, máx. 150 |
| `guest.email` | sí | email válido, máx. 150 |
| `guest.phone` | no | máx. 30 |

**201 Created**

Header: `Location: /api/v1/bookings/A1B2C3D4`

```json
{
  "code": "A1B2C3D4",
  "status": "CONFIRMED",
  "roomType": { "id": 1, "name": "Habitación Sencilla" },
  "checkIn": "2026-11-10",
  "checkOut": "2026-11-12",
  "nights": 2,
  "adults": 2,
  "children": 0,
  "guest": {
    "fullName": "Juan Pérez",
    "email": "juan@correo.com",
    "phone": "+502 5555 5555"
  },
  "pricePerNight": 450.00,
  "totalPrice": 900.00,
  "createdAt": "2026-10-03T14:22:10.123456Z"
}
```

| Campo | Descripción |
|---|---|
| `code` | 8 caracteres, mayúsculas y dígitos. Es el identificador público de la reserva |
| `status` | `CONFIRMED` o `CANCELLED` (por ahora solo se crean `CONFIRMED`) |
| `pricePerNight` | Tarifa congelada al momento de reservar; un cambio posterior de precio no afecta la reserva |

**Errores posibles:** `400 VALIDATION_ERROR`, `400 INVALID_DATES`, `404 ROOM_TYPE_NOT_FOUND`, `409 NO_AVAILABILITY`, `422 CAPACITY_EXCEEDED`.

---

### 3.3 `GET /api/v1/bookings/{code}`

Consulta una reserva por su código (no distingue mayúsculas/minúsculas).

**200 OK:** mismo body que el `201` de la sección 3.2.

**Errores posibles:** `404 BOOKING_NOT_FOUND`.

---

## 4. Formato de errores

Todos los errores usan `ProblemDetail` (RFC 9457) más un campo estable `code`.

```json
{
  "type": "about:blank",
  "title": "Conflict",
  "status": 409,
  "detail": "Ya no hay habitaciones disponibles de este tipo para esas fechas.",
  "code": "NO_AVAILABILITY"
}
```

> El frontend decide su comportamiento por `code`. `detail` es texto legible y puede cambiar.
> Puede venir un campo `instance`; no depender de él.

### Catálogo de códigos

| HTTP | `code` | Cuándo ocurre |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Campo faltante, formato inválido (fecha mal escrita, JSON roto), `adults < 1`, email inválido, etc. |
| 400 | `INVALID_DATES` | `checkIn` anterior a hoy, o `checkOut` ≤ `checkIn` |
| 404 | `ROOM_TYPE_NOT_FOUND` | `roomTypeId` no existe |
| 404 | `BOOKING_NOT_FOUND` | No hay reserva con ese `code` |
| 409 | `NO_AVAILABILITY` | No quedan habitaciones libres del tipo pedido, incluso si alguien reservó segundos antes |
| 422 | `CAPACITY_EXCEEDED` | `adults` o `children` superan la capacidad del tipo de habitación |

### Error de validación con detalle por campo

Los `VALIDATION_ERROR` originados en el body del POST incluyen la lista `errors`:

```json
{
  "type": "about:blank",
  "title": "Bad Request",
  "status": 400,
  "detail": "Hay campos inválidos.",
  "code": "VALIDATION_ERROR",
  "errors": [
    { "field": "guest.email", "message": "must be a well-formed email address" },
    { "field": "adults", "message": "must be greater than or equal to 1" }
  ]
}
```

`field` usa notación con punto para campos anidados (`guest.email`). Los mensajes de `errors` son los estándar de Bean Validation y no son parte estable del contrato; lo estable es `field`.

---

## 5. Ejemplos con curl

```bash
# Disponibilidad
curl "http://localhost:8080/api/v1/room-types/availability?checkIn=2026-11-10&checkOut=2026-11-12&adults=2&children=0"

# Crear reserva
curl -i -X POST http://localhost:8080/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "roomTypeId": 1,
    "checkIn": "2026-11-10",
    "checkOut": "2026-11-12",
    "adults": 2,
    "children": 0,
    "guest": { "fullName": "Juan Pérez", "email": "juan@correo.com", "phone": "+502 5555 5555" }
  }'

# Consultar reserva
curl http://localhost:8080/api/v1/bookings/A1B2C3D4
```

## 6. Tipos para el frontend (referencia TypeScript)

```ts
export interface RoomTypeAvailability {
  id: number; name: string; description: string | null; imageUrl: string | null;
  maxAdults: number; maxChildren: number;
  pricePerNight: number; totalPrice: number; availableRooms: number;
}

export interface AvailabilityResponse {
  checkIn: string; checkOut: string; nights: number; adults: number; children: number;
  roomTypes: RoomTypeAvailability[];
}

export interface Guest { fullName: string; email: string; phone?: string | null; }

export interface BookingRequest {
  roomTypeId: number; checkIn: string; checkOut: string;
  adults: number; children?: number; guest: Guest;
}

export interface BookingResponse {
  code: string; status: 'CONFIRMED' | 'CANCELLED';
  roomType: { id: number; name: string };
  checkIn: string; checkOut: string; nights: number;
  adults: number; children: number; guest: Guest;
  pricePerNight: number; totalPrice: number; createdAt: string;
}

export type ApiErrorCode =
  | 'VALIDATION_ERROR' | 'INVALID_DATES' | 'ROOM_TYPE_NOT_FOUND'
  | 'BOOKING_NOT_FOUND' | 'NO_AVAILABILITY' | 'CAPACITY_EXCEEDED';

export interface ApiError {
  type: string; title: string; status: number; detail: string;
  code: ApiErrorCode; errors?: { field: string; message: string }[];
}
```
