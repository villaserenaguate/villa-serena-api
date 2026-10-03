package com.villaserena.api.dto;

import java.time.LocalDate;
import java.util.List;

public record AvailabilityResponse(
    LocalDate checkIn,
    LocalDate checkOut,
    int nights,
    int adults,
    int children,
    List<RoomTypeAvailability> roomTypes) {}
