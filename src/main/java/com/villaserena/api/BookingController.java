package com.villaserena.api;

import com.villaserena.api.dto.AvailabilityResponse;
import com.villaserena.api.dto.BookingRequest;
import com.villaserena.api.dto.BookingResponse;
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
