package com.villaserena.api.auth.huesped;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import java.util.function.Function;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/** Usa V1 y V2 existentes, sin crear ni cambiar migraciones. */
@Repository
public class JdbcOtpStore implements OtpStore {
    private final JdbcTemplate jdbc;
    private final TransactionTemplate transaction;

    public JdbcOtpStore(JdbcTemplate jdbc, PlatformTransactionManager manager) {
        this.jdbc = jdbc;
        this.transaction = new TransactionTemplate(manager);
        // No participar en una transacción exterior que pueda revertir los intentos fallidos.
        this.transaction.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    @Override
    public <T> T withGuest(String email, Function<Optional<Guest>, T> operation) {
        return transaction.execute(status -> {
            var guests = jdbc.query("""
                SELECT h.id, h.correo, h.otp_intentos_fallidos, h.otp_bloqueado_hasta
                FROM huespedes h
                WHERE lower(h.correo) = ? AND EXISTS (SELECT 1 FROM reservas r WHERE r.huesped_id = h.id)
                FOR UPDATE OF h
                """, (rs, row) -> new JdbcGuest(rs.getLong("id"), rs.getString("correo"),
                    rs.getInt("otp_intentos_fallidos"), instant(rs.getTimestamp("otp_bloqueado_hasta"))), email);
            return operation.apply(guests.stream().findFirst().map(value -> (Guest) value));
        });
    }

    private final class JdbcGuest implements Guest {
        private final long id;
        private final String email;
        private int failures;
        private Instant blockedUntil;
        JdbcGuest(long id, String email, int failures, Instant blockedUntil) {
            this.id = id; this.email = email; this.failures = failures; this.blockedUntil = blockedUntil;
        }
        @Override public long id() { return id; }
        @Override public String email() { return email; }
        @Override public int failures() { return failures; }
        @Override public Instant blockedUntil() { return blockedUntil; }
        @Override public Optional<Code> latestCode() {
            return jdbc.query("""
                SELECT id, codigo_hash, expira_en, usado_en FROM codigos_otp
                WHERE huesped_id = ? ORDER BY id DESC LIMIT 1
                """, (rs, row) -> new Code(rs.getLong("id"), rs.getString("codigo_hash"),
                    instant(rs.getTimestamp("expira_en")), instant(rs.getTimestamp("usado_en"))), id)
                .stream().findFirst();
        }
        @Override public void replaceCode(String hash, Instant expires, Instant now) {
            jdbc.update("UPDATE codigos_otp SET usado_en = ? WHERE huesped_id = ? AND usado_en IS NULL", timestamp(now), id);
            jdbc.update("INSERT INTO codigos_otp (huesped_id, codigo_hash, expira_en, creado_en) VALUES (?, ?, ?, ?)", id, hash, timestamp(expires), timestamp(now));
        }
        @Override public void recordAttempts(int count, Instant until) {
            jdbc.update("UPDATE huespedes SET otp_intentos_fallidos = ?, otp_bloqueado_hasta = ? WHERE id = ?", count, timestamp(until), id);
            failures = count; blockedUntil = until;
        }
        @Override public void useCode(long codeId, Instant now) {
            int updated = jdbc.update("UPDATE codigos_otp SET usado_en = ? WHERE id = ? AND huesped_id = ? AND usado_en IS NULL", timestamp(now), codeId, id);
            if (updated != 1) throw new IllegalStateException("El código ya no está disponible.");
        }
    }
    private static Instant instant(Timestamp value) { return value == null ? null : value.toInstant(); }
    private static Timestamp timestamp(Instant value) { return value == null ? null : Timestamp.from(value); }
}
