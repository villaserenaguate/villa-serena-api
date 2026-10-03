package com.villaserena.api.auth.huesped;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Objects;

/** Lógica HU-HUE-08. Se instancia al disponer de los adaptadores de JWT y Outbox. */
public final class OtpAccessService<T> {
    public static final String REQUEST_MESSAGE = "Si el correo tiene reservas, recibirás un código para entrar.";
    private static final Duration VALIDITY = Duration.ofMinutes(10);
    private static final Duration BLOCK = Duration.ofMinutes(15);
    private final OtpStore store;
    private final AccessCodeEmail email;
    private final GuestSessionIssuer<T> issuer;
    private final Clock clock;
    private final OtpHasher hasher = new OtpHasher();
    private final SecureRandom random = new SecureRandom();

    public OtpAccessService(OtpStore store, AccessCodeEmail email, GuestSessionIssuer<T> issuer, Clock clock) {
        this.store = Objects.requireNonNull(store);
        this.email = Objects.requireNonNull(email);
        this.issuer = Objects.requireNonNull(issuer);
        this.clock = Objects.requireNonNull(clock);
    }

    public String requestCode(String address) {
        // El trabajo criptográfico se realiza también para correos sin reservas.
        String code = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
        String hash = hasher.hash(code);
        store.withGuest(normalize(address), guest -> {
            guest.ifPresent(value -> {
                Instant now = clock.instant();
                if (blocked(value, now)) return;
                resetExpiredBlock(value, now);
                value.replaceCode(hash, now.plus(VALIDITY), now);
                email.enqueue(value.email(), code, now.plus(VALIDITY));
            });
            return null;
        });
        return REQUEST_MESSAGE;
    }

    public T verifyCode(String address, String code) {
        Result<T> result = store.withGuest(normalize(address), guest -> {
            if (guest.isEmpty()) return Result.failure(invalid());
            var value = guest.get();
            Instant now = clock.instant();
            if (blocked(value, now)) return Result.failure(blockedError());
            resetExpiredBlock(value, now);
            var latest = value.latestCode();
            OtpAccessException error;
            if (latest.isEmpty()) error = invalid();
            else if (latest.get().usedAt() != null || !now.isBefore(latest.get().expires())) {
                error = new OtpAccessException(OtpAccessException.Reason.EXPIRED_OR_USED,
                        "El código venció o ya fue usado. Pide otro código.");
            } else if (code == null || !code.matches("[0-9]{6}") || !hasher.matches(code, latest.get().hash())) {
                error = invalid();
            } else {
                // Emisión y consumo comparten la transacción: si falla el emisor, no se consume.
                T session = Objects.requireNonNull(issuer.issue(value.id()));
                value.useCode(latest.get().id(), now);
                value.recordAttempts(0, null);
                return Result.success(session);
            }
            int failures = value.failures() + 1;
            value.recordAttempts(failures, failures >= 5 ? now.plus(BLOCK) : null);
            return Result.failure(failures >= 5 ? blockedError() : error);
        });
        // El error se lanza después del commit, para conservar el contador y el bloqueo.
        if (result.error() != null) throw result.error();
        return result.session();
    }

    private static void resetExpiredBlock(OtpStore.Guest guest, Instant now) {
        if (guest.blockedUntil() != null && !now.isBefore(guest.blockedUntil())) guest.recordAttempts(0, null);
    }
    private static boolean blocked(OtpStore.Guest guest, Instant now) {
        return guest.blockedUntil() != null && now.isBefore(guest.blockedUntil());
    }
    private static String normalize(String email) { return Objects.requireNonNull(email).trim().toLowerCase(Locale.ROOT); }
    private static OtpAccessException invalid() { return new OtpAccessException(OtpAccessException.Reason.INVALID, "El código no es válido."); }
    private static OtpAccessException blockedError() { return new OtpAccessException(OtpAccessException.Reason.BLOCKED, "El acceso está bloqueado por 15 minutos. Intenta más tarde."); }
    private record Result<T>(T session, OtpAccessException error) {
        static <T> Result<T> success(T session) { return new Result<>(session, null); }
        static <T> Result<T> failure(OtpAccessException error) { return new Result<>(null, error); }
    }
}
