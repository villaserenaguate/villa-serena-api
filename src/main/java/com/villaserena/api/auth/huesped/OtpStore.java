package com.villaserena.api.auth.huesped;

import java.time.Instant;
import java.util.Optional;
import java.util.function.Function;

/** Ejecuta cada operación en una transacción y con bloqueo exclusivo del huésped. */
public interface OtpStore {
    <T> T withGuest(String email, Function<Optional<Guest>, T> operation);

    interface Guest {
        long id();
        String email();
        int failures();
        Instant blockedUntil();
        Optional<Code> latestCode();
        void replaceCode(String hash, Instant expires, Instant now);
        void recordAttempts(int failures, Instant blockedUntil);
        void useCode(long codeId, Instant now);
    }

    record Code(long id, String hash, Instant expires, Instant usedAt) {}
}
