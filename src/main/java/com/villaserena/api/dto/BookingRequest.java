package com.villaserena.api.dto;

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
