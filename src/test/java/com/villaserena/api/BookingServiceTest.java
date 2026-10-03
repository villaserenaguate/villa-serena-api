package com.villaserena.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.villaserena.api.dto.BookingRequest;
import com.villaserena.api.dto.GuestDto;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;

@ExtendWith(MockitoExtension.class)
class BookingServiceTest {

  @Mock
  private JdbcClient jdbcClient;

  private final Clock fixedClock = Clock.fixed(
      Instant.parse("2026-10-03T10:00:00Z"),
      ZoneId.of("America/Guatemala")
  );

  private BookingService bookingService;

  @BeforeEach
  void setUp() {
    bookingService = new BookingService(jdbcClient, fixedClock);
  }

  @Test
  void searchInvalidGuestsThrowsValidationError() {
    LocalDate in = LocalDate.of(2026, 11, 10);
    LocalDate out = LocalDate.of(2026, 11, 12);

    ApiException ex = assertThrows(ApiException.class, () ->
        bookingService.search(in, out, 0, 0));
    assertEquals(HttpStatus.BAD_REQUEST, ex.status());
    assertEquals("VALIDATION_ERROR", ex.code());

    ApiException ex2 = assertThrows(ApiException.class, () ->
        bookingService.search(in, out, 2, -1));
    assertEquals(HttpStatus.BAD_REQUEST, ex2.status());
    assertEquals("VALIDATION_ERROR", ex2.code());
  }

  @Test
  void searchInvalidDatesThrowsInvalidDates() {
    // checkIn is in the past (clock is fixed at 2026-10-03)
    LocalDate pastIn = LocalDate.of(2026, 10, 1);
    LocalDate out = LocalDate.of(2026, 10, 5);

    ApiException ex = assertThrows(ApiException.class, () ->
        bookingService.search(pastIn, out, 2, 0));
    assertEquals(HttpStatus.BAD_REQUEST, ex.status());
    assertEquals("INVALID_DATES", ex.code());

    // checkOut is not after checkIn
    LocalDate in = LocalDate.of(2026, 11, 10);
    LocalDate sameOut = LocalDate.of(2026, 11, 10);

    ApiException ex2 = assertThrows(ApiException.class, () ->
        bookingService.search(in, sameOut, 2, 0));
    assertEquals(HttpStatus.BAD_REQUEST, ex2.status());
    assertEquals("INVALID_DATES", ex2.code());
  }

  @Test
  void createBookingPastDateThrowsInvalidDates() {
    LocalDate pastIn = LocalDate.of(2026, 10, 1);
    LocalDate out = LocalDate.of(2026, 10, 5);
    BookingRequest req = new BookingRequest(
        1L, pastIn, out, 2, 0,
        new GuestDto("Juan", "juan@test.com", null)
    );

    ApiException ex = assertThrows(ApiException.class, () ->
        bookingService.create(req));
    assertEquals(HttpStatus.BAD_REQUEST, ex.status());
    assertEquals("INVALID_DATES", ex.code());
  }
}
