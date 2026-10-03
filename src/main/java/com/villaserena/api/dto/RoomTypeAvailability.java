package com.villaserena.api.dto;

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
