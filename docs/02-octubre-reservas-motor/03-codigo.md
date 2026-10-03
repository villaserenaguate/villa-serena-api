# Villa Serena — Código del backend

Todo el código de la etapa 1 (base de datos y backend), listo para copiar al proyecto Spring Boot 4 / Java 21.

- `<package base>` es un placeholder: se reemplaza por el package real del proyecto.
- Los `import` están incluidos en cada archivo. Los DTOs van en el subpackage `dto`.
- El contrato que este código debe cumplir está en `01-contrato-api.md`; las decisiones de diseño, en `02-arquitectura-y-base-de-datos.md`.

---

## 1. Dependencias (`pom.xml`)

El parent es `spring-boot-starter-parent` 4.0.x con `<java.version>21</java.version>`.

```xml
<dependencies>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webmvc</artifactId>
  </dependency>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
  </dependency>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
  </dependency>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-flyway</artifactId>
  </dependency>
  <dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-database-postgresql</artifactId>
  </dependency>
  <dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
  </dependency>
</dependencies>
```

---

## 2. Configuración (`src/main/resources/application.yml`)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/<nombre_bd>
    username: <usuario>
    password: <password>
hotel:
  timezone: America/Guatemala
```

---

## 3. Migraciones Flyway

### `src/main/resources/db/migration/V1__create_schema.sql`

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room_types (
  id              BIGSERIAL     PRIMARY KEY,
  name            VARCHAR(100)  NOT NULL,
  description     TEXT,
  image_url       TEXT,
  price_per_night NUMERIC(10,2) NOT NULL CHECK (price_per_night >= 0),
  max_adults      SMALLINT      NOT NULL CHECK (max_adults > 0),
  max_children    SMALLINT      NOT NULL DEFAULT 0 CHECK (max_children >= 0)
);

CREATE TABLE rooms (
  id           BIGSERIAL   PRIMARY KEY,
  room_type_id BIGINT      NOT NULL REFERENCES room_types(id),
  room_number  VARCHAR(10) NOT NULL UNIQUE,
  active       BOOLEAN     NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_rooms_room_type ON rooms (room_type_id);

CREATE TABLE bookings (
  id              BIGSERIAL     PRIMARY KEY,
  code            VARCHAR(12)   NOT NULL UNIQUE,
  room_id         BIGINT        NOT NULL REFERENCES rooms(id),
  guest_name      VARCHAR(150)  NOT NULL,
  guest_email     VARCHAR(150)  NOT NULL,
  guest_phone     VARCHAR(30),
  check_in        DATE          NOT NULL,
  check_out       DATE          NOT NULL,
  adults          SMALLINT      NOT NULL CHECK (adults > 0),
  children        SMALLINT      NOT NULL DEFAULT 0 CHECK (children >= 0),
  price_per_night NUMERIC(10,2) NOT NULL,
  total_price     NUMERIC(10,2) NOT NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'CONFIRMED'
                  CHECK (status IN ('CONFIRMED', 'CANCELLED')),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CHECK (check_out > check_in),
  EXCLUDE USING gist (
    room_id WITH =,
    daterange(check_in, check_out) WITH &&
  ) WHERE (status = 'CONFIRMED')
);
CREATE INDEX idx_bookings_room_dates ON bookings (room_id, check_in, check_out);
```

### `src/main/resources/db/migration/V2__seed_room_types.sql`

```sql
INSERT INTO room_types (name, description, price_per_night, max_adults, max_children) VALUES
  ('Habitación Sencilla', 'Cama queen, baño privado', 450.00, 2, 1),
  ('Habitación Familiar', 'Dos camas, ideal para familias', 750.00, 4, 2);

INSERT INTO rooms (room_type_id, room_number) VALUES
  (1, '101'), (1, '102'), (1, '103'),
  (2, '201'), (2, '202');
```

---

## 4. DTOs (`<package base>.dto`)

### `GuestDto.java`

```java
package <package base>.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record GuestDto(
    @NotBlank @Size(max = 150) String fullName,
    @NotBlank @Email @Size(max = 150) String email,
    @Size(max = 30) String phone) {}
```

### `BookingRequest.java`

```java
package <package base>.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record BookingRequest(
    @NotNull Long roomTypeId,
    @NotNull LocalDate checkIn,
    @NotNull LocalDate checkOut,
    @NotNull @Min(1) Integer adults,
    @Min(0) Integer children,
    @NotNull @Valid GuestDto guest) {

  public BookingRequest {
    if (children == null) {
      children = 0;
    }
  }
}
```

### `RoomTypeRef.java`

```java
package <package base>.dto;

public record RoomTypeRef(Long id, String name) {}
```

### `BookingResponse.java`

```java
package <package base>.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

public record BookingResponse(
    String code,
    String status,
    RoomTypeRef roomType,
    LocalDate checkIn,
    LocalDate checkOut,
    int nights,
    int adults,
    int children,
    GuestDto guest,
    BigDecimal pricePerNight,
    BigDecimal totalPrice,
    OffsetDateTime createdAt) {}
```

### `RoomTypeAvailability.java`

```java
package <package base>.dto;

import java.math.BigDecimal;

public record RoomTypeAvailability(
    Long id,
    String name,
    String description,
    String imageUrl,
    int maxAdults,
    int maxChildren,
    BigDecimal pricePerNight,
    BigDecimal totalPrice,
    int availableRooms) {}
```

### `AvailabilityResponse.java`

```java
package <package base>.dto;

import java.time.LocalDate;
import java.util.List;

public record AvailabilityResponse(
    LocalDate checkIn,
    LocalDate checkOut,
    int nights,
    int adults,
    int children,
    List<RoomTypeAvailability> roomTypes) {}
```

---

## 5. Errores y configuración (`<package base>`)

### `ApiException.java`

```java
package <package base>;

import org.springframework.http.HttpStatus;

public class ApiException extends RuntimeException {

  private final HttpStatus status;
  private final String code;

  public ApiException(HttpStatus status, String code, String message) {
    super(message);
    this.status = status;
    this.code = code;
  }

  public HttpStatus status() {
    return status;
  }

  public String code() {
    return code;
  }
}
```

### `ClockConfig.java`

```java
package <package base>;

import java.time.Clock;
import java.time.ZoneId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class ClockConfig {

  @Bean
  Clock clock(@Value("${hotel.timezone}") String timezone) {
    return Clock.system(ZoneId.of(timezone));
  }
}
```

### `ApiExceptionHandler.java`

```java
package <package base>;

import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

@RestControllerAdvice
public class ApiExceptionHandler {

  public record FieldIssue(String field, String message) {}

  @ExceptionHandler(ApiException.class)
  ProblemDetail handleApi(ApiException e) {
    return problem(e.status(), e.code(), e.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  ProblemDetail handleBody(MethodArgumentNotValidException e) {
    ProblemDetail pd = problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Hay campos inválidos.");
    List<FieldIssue> errors = e.getBindingResult().getFieldErrors().stream()
        .map(f -> new FieldIssue(f.getField(), f.getDefaultMessage()))
        .toList();
    pd.setProperty("errors", errors);
    return pd;
  }

  @ExceptionHandler(MissingServletRequestParameterException.class)
  ProblemDetail handleMissing(MissingServletRequestParameterException e) {
    return problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
        "Falta el parámetro '" + e.getParameterName() + "'.");
  }

  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  ProblemDetail handleType(MethodArgumentTypeMismatchException e) {
    return problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
        "El parámetro '" + e.getName() + "' tiene un formato inválido.");
  }

  @ExceptionHandler(HttpMessageNotReadableException.class)
  ProblemDetail handleUnreadable(HttpMessageNotReadableException e) {
    return problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
        "Cuerpo inválido. Las fechas deben tener formato yyyy-MM-dd.");
  }

  private ProblemDetail problem(HttpStatus status, String code, String detail) {
    ProblemDetail pd = ProblemDetail.forStatusAndDetail(status, detail);
    pd.setProperty("code", code);
    return pd;
  }
}
```

---

## 6. Servicio (`BookingService.java`)

```java
package <package base>;

import <package base>.dto.AvailabilityResponse;
import <package base>.dto.BookingRequest;
import <package base>.dto.BookingResponse;
import <package base>.dto.GuestDto;
import <package base>.dto.RoomTypeAvailability;
import <package base>.dto.RoomTypeRef;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BookingService {

  // Fragmento SQL reutilizado: la habitación "r" no tiene reservas confirmadas que se solapen.
  private static final String AND_ROOM_IS_FREE = """
      AND NOT EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.room_id = r.id AND b.status = 'CONFIRMED'
          AND b.check_in < :checkOut AND b.check_out > :checkIn)
      """;

  private final JdbcClient jdbc;
  private final Clock clock;

  public BookingService(JdbcClient jdbc, Clock clock) {
    this.jdbc = jdbc;
    this.clock = clock;
  }

  public AvailabilityResponse search(LocalDate checkIn, LocalDate checkOut, int adults, int children) {
    if (adults < 1 || children < 0) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
          "adults debe ser >= 1 y children >= 0.");
    }
    validateDates(checkIn, checkOut);
    int nights = (int) ChronoUnit.DAYS.between(checkIn, checkOut);

    List<RoomTypeAvailability> types = jdbc.sql("""
        SELECT t.id, t.name, t.description, t.image_url, t.max_adults, t.max_children,
               t.price_per_night, COUNT(r.id) AS available
        FROM room_types t
        JOIN rooms r ON r.room_type_id = t.id AND r.active
        WHERE t.max_adults >= :adults AND t.max_children >= :children
        """ + AND_ROOM_IS_FREE + """
        GROUP BY t.id
        ORDER BY t.price_per_night
        """)
        .param("adults", adults)
        .param("children", children)
        .param("checkIn", checkIn)
        .param("checkOut", checkOut)
        .query((rs, i) -> {
          BigDecimal price = rs.getBigDecimal("price_per_night");
          return new RoomTypeAvailability(
              rs.getLong("id"),
              rs.getString("name"),
              rs.getString("description"),
              rs.getString("image_url"),
              rs.getInt("max_adults"),
              rs.getInt("max_children"),
              price,
              price.multiply(BigDecimal.valueOf(nights)),
              rs.getInt("available"));
        })
        .list();

    return new AvailabilityResponse(checkIn, checkOut, nights, adults, children, types);
  }

  @Transactional
  public BookingResponse create(BookingRequest req) {
    validateDates(req.checkIn(), req.checkOut());

    record TypeRow(int maxAdults, int maxChildren, BigDecimal price) {}

    TypeRow type = jdbc.sql(
            "SELECT max_adults, max_children, price_per_night FROM room_types WHERE id = :id")
        .param("id", req.roomTypeId())
        .query((rs, i) -> new TypeRow(rs.getInt(1), rs.getInt(2), rs.getBigDecimal(3)))
        .optional()
        .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ROOM_TYPE_NOT_FOUND",
            "El tipo de habitación no existe."));

    if (req.adults() > type.maxAdults() || req.children() > type.maxChildren()) {
      throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CAPACITY_EXCEEDED",
          "El número de huéspedes excede la capacidad de esta habitación.");
    }

    Long roomId = jdbc.sql("""
        SELECT r.id FROM rooms r
        WHERE r.room_type_id = :typeId AND r.active
        """ + AND_ROOM_IS_FREE + """
        ORDER BY r.id
        LIMIT 1
        """)
        .param("typeId", req.roomTypeId())
        .param("checkIn", req.checkIn())
        .param("checkOut", req.checkOut())
        .query(Long.class)
        .optional()
        .orElseThrow(this::noAvailability);

    long nights = ChronoUnit.DAYS.between(req.checkIn(), req.checkOut());
    BigDecimal total = type.price().multiply(BigDecimal.valueOf(nights));
    String code = UUID.randomUUID().toString().replace("-", "").substring(0, 8).toUpperCase();

    try {
      jdbc.sql("""
          INSERT INTO bookings (code, room_id, guest_name, guest_email, guest_phone,
                                check_in, check_out, adults, children, price_per_night, total_price)
          VALUES (:code, :room, :name, :email, :phone,
                  :checkIn, :checkOut, :adults, :children, :price, :total)
          """)
          .param("code", code)
          .param("room", roomId)
          .param("name", req.guest().fullName())
          .param("email", req.guest().email())
          .param("phone", req.guest().phone())
          .param("checkIn", req.checkIn())
          .param("checkOut", req.checkOut())
          .param("adults", req.adults())
          .param("children", req.children())
          .param("price", type.price())
          .param("total", total)
          .update();
    } catch (DataIntegrityViolationException e) {
      // La restricción EXCLUDE de PostgreSQL detectó que la habitación se ocupó en paralelo.
      throw noAvailability();
    }

    return findByCode(code);
  }

  public BookingResponse findByCode(String code) {
    return jdbc.sql("""
        SELECT b.code, b.status, t.id AS type_id, t.name AS type_name,
               b.check_in, b.check_out, b.adults, b.children,
               b.guest_name, b.guest_email, b.guest_phone,
               b.price_per_night, b.total_price, b.created_at
        FROM bookings b
        JOIN rooms r ON r.id = b.room_id
        JOIN room_types t ON t.id = r.room_type_id
        WHERE b.code = :code
        """)
        .param("code", code)
        .query((rs, i) -> {
          LocalDate in = rs.getObject("check_in", LocalDate.class);
          LocalDate out = rs.getObject("check_out", LocalDate.class);
          return new BookingResponse(
              rs.getString("code"),
              rs.getString("status"),
              new RoomTypeRef(rs.getLong("type_id"), rs.getString("type_name")),
              in,
              out,
              (int) ChronoUnit.DAYS.between(in, out),
              rs.getInt("adults"),
              rs.getInt("children"),
              new GuestDto(rs.getString("guest_name"), rs.getString("guest_email"),
                  rs.getString("guest_phone")),
              rs.getBigDecimal("price_per_night"),
              rs.getBigDecimal("total_price"),
              rs.getObject("created_at", OffsetDateTime.class));
        })
        .optional()
        .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "BOOKING_NOT_FOUND",
            "No existe una reserva con ese código."));
  }

  private void validateDates(LocalDate checkIn, LocalDate checkOut) {
    if (checkIn.isBefore(LocalDate.now(clock)) || !checkOut.isAfter(checkIn)) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES",
          "checkIn no puede ser pasado y checkOut debe ser posterior a checkIn.");
    }
  }

  private ApiException noAvailability() {
    return new ApiException(HttpStatus.CONFLICT, "NO_AVAILABILITY",
        "Ya no hay habitaciones disponibles de este tipo para esas fechas.");
  }
}
```

---

## 7. Controller (`BookingController.java`)

```java
package <package base>;

import <package base>.dto.AvailabilityResponse;
import <package base>.dto.BookingRequest;
import <package base>.dto.BookingResponse;
import jakarta.validation.Valid;
import java.net.URI;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class BookingController {

  private final BookingService service;

  public BookingController(BookingService service) {
    this.service = service;
  }

  @GetMapping("/room-types/availability")
  public AvailabilityResponse availability(
      @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate checkIn,
      @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate checkOut,
      @RequestParam int adults,
      @RequestParam(defaultValue = "0") int children) {
    return service.search(checkIn, checkOut, adults, children);
  }

  @PostMapping("/bookings")
  public ResponseEntity<BookingResponse> create(@Valid @RequestBody BookingRequest request) {
    BookingResponse created = service.create(request);
    return ResponseEntity
        .created(URI.create("/api/v1/bookings/" + created.code()))
        .body(created);
  }

  @GetMapping("/bookings/{code}")
  public BookingResponse get(@PathVariable String code) {
    return service.findByCode(code.toUpperCase());
  }
}
```
