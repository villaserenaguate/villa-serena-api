package com.villaserena.api.auth.huesped;

/** Adaptar al emisor de Pablo: HUESPED, JWT 15 min y refresh rotativo 7 días. */
@FunctionalInterface
public interface GuestSessionIssuer<T> {
    T issue(long guestId);
}
