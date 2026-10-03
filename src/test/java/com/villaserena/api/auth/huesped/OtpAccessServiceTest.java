package com.villaserena.api.auth.huesped;

import static org.junit.jupiter.api.Assertions.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class OtpAccessServiceTest {
    private final MutableClock clock = new MutableClock();
    private final MemoryStore store = new MemoryStore();
    private final List<String> delivered = new ArrayList<>();
    private final AtomicInteger sessions = new AtomicInteger();
    private OtpAccessService<String> service;
    @BeforeEach void setup() {
        service = service(id -> { sessions.incrementAndGet(); return "session-" + id; });
    }
    private OtpAccessService<String> service(GuestSessionIssuer<String> issuer) {
        return new OtpAccessService<>(store, (email, code, expires) -> {
            assertEquals("ana@example.com", email);
            assertEquals(clock.instant().plusSeconds(600), expires);
            delivered.add(code);
        }, issuer, clock);
    }
    private String request() { service.requestCode(" ANA@EXAMPLE.COM "); return delivered.getLast(); }
    private void reason(OtpAccessException.Reason reason, Runnable action) {
        assertEquals(reason, assertThrows(OtpAccessException.class, action::run).reason());
    }
    @Test void sendsSixDigitsAndStoresOnlySaltedHash() {
        String code = request();
        assertTrue(code.matches("[0-9]{6}"));
        assertNotEquals(code, store.guest.code.hash());
        assertTrue(store.guest.code.hash().length() <= 100);
        assertEquals("session-7", service.verifyCode("ana@example.com", code));
    }
    @Test void unknownAddressReturnsSameMessageWithoutEmailOrSession() {
        assertEquals(service.requestCode("ana@example.com"), service.requestCode("unknown@example.com"));
        assertEquals(1, delivered.size());
        reason(OtpAccessException.Reason.INVALID, () -> service.verifyCode("unknown@example.com", delivered.getFirst()));
        assertEquals(0, sessions.get());
    }
    @Test void expiresAtExactlyTenMinutes() {
        String code = request(); clock.advance(600);
        reason(OtpAccessException.Reason.EXPIRED_OR_USED, () -> service.verifyCode("ana@example.com", code));
        assertEquals(0, sessions.get());
    }
    @Test void rejectsUsedCode() {
        String code = request(); service.verifyCode("ana@example.com", code);
        reason(OtpAccessException.Reason.EXPIRED_OR_USED, () -> service.verifyCode("ana@example.com", code));
        assertEquals(1, sessions.get());
    }
    @Test void fifthFailureBlocksAndResendingDoesNotResetAttempts() {
        request();
        for (int i = 0; i < 4; i++) {
            reason(OtpAccessException.Reason.INVALID, () -> service.verifyCode("ana@example.com", "bad"));
            request();
        }
        reason(OtpAccessException.Reason.BLOCKED, () -> service.verifyCode("ana@example.com", "bad"));
        assertEquals(5, store.guest.failures);
        int emails = delivered.size();
        assertEquals(OtpAccessService.REQUEST_MESSAGE, service.requestCode("ana@example.com"));
        assertEquals(emails, delivered.size());
        reason(OtpAccessException.Reason.BLOCKED, () -> service.verifyCode("ana@example.com", delivered.getLast()));
        clock.advance(900);
        String code = request();
        assertEquals("session-7", service.verifyCode("ana@example.com", code));
        assertEquals(0, store.guest.failures);
        assertNull(store.guest.blocked);
    }
    @Test void newCodeInvalidatesPreviousCode() {
        request(); long oldId = store.guest.code.id();
        request(); assertNotEquals(oldId, store.guest.code.id());
        assertEquals("session-7", service.verifyCode("ana@example.com", delivered.getLast()));
        assertEquals(1, sessions.get());
    }
    @Test void validSessionResetsFailedAttempts() {
        String code = request();
        reason(OtpAccessException.Reason.INVALID, () -> service.verifyCode("ana@example.com", "bad"));
        service.verifyCode("ana@example.com", code);
        assertEquals(0, store.guest.failures);
    }
    @Test void issuerFailureLeavesCodeAvailable() {
        String code = request();
        var failing = service(id -> { throw new IllegalStateException("Emisor no disponible"); });
        assertThrows(IllegalStateException.class, () -> failing.verifyCode("ana@example.com", code));
        assertNull(store.guest.code.usedAt());
        assertEquals("session-7", service.verifyCode("ana@example.com", code));
    }
    @Test void emailFailureRollsBackCode() {
        var failing = new OtpAccessService<>(store, (email, code, expires) -> { throw new IllegalStateException("Outbox no disponible"); }, id -> "session", clock);
        assertThrows(IllegalStateException.class, () -> failing.requestCode("ana@example.com"));
        assertNull(store.guest.code);
    }
    @Test void concurrentVerificationIssuesOnlyOneSession() throws Exception {
        String code = request();
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            Callable<Boolean> verify = () -> { start.await(); try { service.verifyCode("ana@example.com", code); return true; } catch (OtpAccessException e) { return false; } };
            var first = executor.submit(verify); var second = executor.submit(verify); start.countDown();
            assertNotEquals(first.get(5, TimeUnit.SECONDS), second.get(5, TimeUnit.SECONDS));
            assertEquals(1, sessions.get());
        }
    }
    @Test void wrongSixDigitCodeDoesNotAuthenticate() {
        String code = request(); String wrong = code.equals("000000") ? "000001" : "000000";
        reason(OtpAccessException.Reason.INVALID, () -> service.verifyCode("ana@example.com", wrong));
        assertEquals(1, store.guest.failures); assertEquals(0, sessions.get());
    }
    @Test void hashesAreSaltedAndMalformedHashesFailClosed() {
        var hasher = new OtpHasher();
        assertNotEquals(hasher.hash("123456"), hasher.hash("123456"));
        assertFalse(hasher.matches("123456", "broken"));
        assertFalse(hasher.matches("123456", "210000.x.y"));
    }
    private static class MutableClock extends Clock {
        private Instant now = Instant.parse("2026-10-03T16:00:00Z");
        void advance(long seconds) { now = now.plusSeconds(seconds); }
        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
    }
    private static class MemoryStore implements OtpStore {
        MemoryGuest guest = new MemoryGuest();
        @Override public synchronized <T> T withGuest(String email, Function<Optional<Guest>, T> operation) {
            MemoryGuest snapshot = guest.copy();
            try { return operation.apply(email.equals("ana@example.com") ? Optional.of(guest) : Optional.empty()); }
            catch (RuntimeException error) { guest = snapshot; throw error; }
        }
    }
    private static class MemoryGuest implements OtpStore.Guest {
        int failures; Instant blocked; OtpStore.Code code; long nextId;
        MemoryGuest copy() { var copy = new MemoryGuest(); copy.failures = failures; copy.blocked = blocked; copy.code = code; copy.nextId = nextId; return copy; }
        @Override public long id() { return 7; }
        @Override public String email() { return "ana@example.com"; }
        @Override public int failures() { return failures; }
        @Override public Instant blockedUntil() { return blocked; }
        @Override public Optional<OtpStore.Code> latestCode() { return Optional.ofNullable(code); }
        @Override public void replaceCode(String hash, Instant expires, Instant now) { code = new OtpStore.Code(++nextId, hash, expires, null); }
        @Override public void recordAttempts(int count, Instant until) { failures = count; blocked = until; }
        @Override public void useCode(long id, Instant now) { code = new OtpStore.Code(id, code.hash(), code.expires(), now); }
    }
}
