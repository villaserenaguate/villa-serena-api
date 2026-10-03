package com.villaserena.api;

import com.villaserena.api.dto.AvailabilityResponse;
import com.villaserena.api.dto.BookingRequest;
import com.villaserena.api.dto.BookingResponse;
import com.villaserena.api.dto.GuestDto;
import com.villaserena.api.dto.RoomTypeAvailability;
import com.villaserena.api.dto.RoomTypeRef;
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
        .param("code", code == null ? "" : code.toUpperCase())
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
