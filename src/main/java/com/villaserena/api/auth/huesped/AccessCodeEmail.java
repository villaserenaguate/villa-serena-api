package com.villaserena.api.auth.huesped;

import java.time.Instant;

/** Adaptar al Outbox de Hugo: encolar codigo-acceso en la MISMA transacción. */
@FunctionalInterface
public interface AccessCodeEmail {
    void enqueue(String email, String code, Instant expires);
}
