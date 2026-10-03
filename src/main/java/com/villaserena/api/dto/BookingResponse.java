package com.villaserena.api.dto;

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
