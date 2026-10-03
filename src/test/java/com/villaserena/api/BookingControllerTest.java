package com.villaserena.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.villaserena.api.dto.AvailabilityResponse;
import com.villaserena.api.dto.BookingRequest;
import com.villaserena.api.dto.BookingResponse;
import com.villaserena.api.dto.GuestDto;
import com.villaserena.api.dto.RoomTypeAvailability;
import com.villaserena.api.dto.RoomTypeRef;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest({BookingController.class, ApiExceptionHandler.class})
class BookingControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private BookingService bookingService;

  @Test
  void availabilitySuccess() throws Exception {
    LocalDate in = LocalDate.of(2026, 11, 10);
    LocalDate out = LocalDate.of(2026, 11, 12);
    AvailabilityResponse response = new AvailabilityResponse(
        in, out, 2, 2, 0,
        List.of(new RoomTypeAvailability(
            1L, "Habitación Sencilla", "Cama queen, baño privado", null,
            2, 1, new BigDecimal("450.00"), new BigDecimal("900.00"), 3
        ))
    );

    when(bookingService.search(eq(in), eq(out), eq(2), eq(0))).thenReturn(response);

    mockMvc.perform(get("/api/v1/room-types/availability")
            .param("checkIn", "2026-11-10")
            .param("checkOut", "2026-11-12")
            .param("adults", "2")
            .param("children", "0"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.checkIn").value("2026-11-10"))
        .andExpect(jsonPath("$.checkOut").value("2026-11-12"))
        .andExpect(jsonPath("$.nights").value(2))
        .andExpect(jsonPath("$.roomTypes[0].id").value(1))
        .andExpect(jsonPath("$.roomTypes[0].availableRooms").value(3));
  }

  @Test
  void availabilityMissingParamReturnsValidationError() throws Exception {
    mockMvc.perform(get("/api/v1/room-types/availability")
            .param("checkIn", "2026-11-10")
            .param("checkOut", "2026-11-12"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
  }

  @Test
  void availabilityInvalidDateFormatReturnsValidationError() throws Exception {
    mockMvc.perform(get("/api/v1/room-types/availability")
            .param("checkIn", "not-a-date")
            .param("checkOut", "2026-11-12")
            .param("adults", "2"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
  }

  @Test
  void createBookingSuccess() throws Exception {
    LocalDate in = LocalDate.of(2026, 11, 10);
    LocalDate out = LocalDate.of(2026, 11, 12);
    BookingResponse response = new BookingResponse(
        "A1B2C3D4",
        "CONFIRMED",
        new RoomTypeRef(1L, "Habitación Sencilla"),
        in,
        out,
        2,
        2,
        0,
        new GuestDto("Juan Pérez", "juan@correo.com", "+502 5555 5555"),
        new BigDecimal("450.00"),
        new BigDecimal("900.00"),
        OffsetDateTime.now()
    );

    when(bookingService.create(any(BookingRequest.class))).thenReturn(response);

    String requestJson = """
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
        """;

    mockMvc.perform(post("/api/v1/bookings")
            .contentType(MediaType.APPLICATION_JSON)
            .content(requestJson))
        .andExpect(status().isCreated())
        .andExpect(header().string("Location", "/api/v1/bookings/A1B2C3D4"))
        .andExpect(jsonPath("$.code").value("A1B2C3D4"))
        .andExpect(jsonPath("$.status").value("CONFIRMED"))
        .andExpect(jsonPath("$.roomType.name").value("Habitación Sencilla"));
  }

  @Test
  void createBookingValidationError() throws Exception {
    String invalidJson = """
        {
          "roomTypeId": null,
          "checkIn": "2026-11-10",
          "checkOut": "2026-11-12",
          "adults": 0,
          "guest": {
            "fullName": "",
            "email": "invalid-email"
          }
        }
        """;

    mockMvc.perform(post("/api/v1/bookings")
            .contentType(MediaType.APPLICATION_JSON)
            .content(invalidJson))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.errors").isArray());
  }

  @Test
  void createBookingNoAvailabilityReturnsConflict() throws Exception {
    when(bookingService.create(any(BookingRequest.class)))
        .thenThrow(new ApiException(HttpStatus.CONFLICT, "NO_AVAILABILITY",
            "Ya no hay habitaciones disponibles de este tipo para esas fechas."));

    String requestJson = """
        {
          "roomTypeId": 1,
          "checkIn": "2026-11-10",
          "checkOut": "2026-11-12",
          "adults": 2,
          "children": 0,
          "guest": {
            "fullName": "Juan Pérez",
            "email": "juan@correo.com"
          }
        }
        """;

    mockMvc.perform(post("/api/v1/bookings")
            .contentType(MediaType.APPLICATION_JSON)
            .content(requestJson))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.code").value("NO_AVAILABILITY"))
        .andExpect(jsonPath("$.status").value(409));
  }

  @Test
  void getBookingSuccess() throws Exception {
    LocalDate in = LocalDate.of(2026, 11, 10);
    LocalDate out = LocalDate.of(2026, 11, 12);
    BookingResponse response = new BookingResponse(
        "A1B2C3D4",
        "CONFIRMED",
        new RoomTypeRef(1L, "Habitación Sencilla"),
        in,
        out,
        2,
        2,
        0,
        new GuestDto("Juan Pérez", "juan@correo.com", "+502 5555 5555"),
        new BigDecimal("450.00"),
        new BigDecimal("900.00"),
        OffsetDateTime.now()
    );

    when(bookingService.findByCode("A1B2C3D4")).thenReturn(response);

    mockMvc.perform(get("/api/v1/bookings/a1b2c3d4"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.code").value("A1B2C3D4"));
  }

  @Test
  void getBookingNotFound() throws Exception {
    when(bookingService.findByCode("UNKNOWN1"))
        .thenThrow(new ApiException(HttpStatus.NOT_FOUND, "BOOKING_NOT_FOUND",
            "No existe una reserva con ese código."));

    mockMvc.perform(get("/api/v1/bookings/UNKNOWN1"))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.code").value("BOOKING_NOT_FOUND"))
        .andExpect(jsonPath("$.status").value(404));
  }
}
