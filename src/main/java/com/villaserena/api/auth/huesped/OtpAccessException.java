package com.villaserena.api.auth.huesped;

public final class OtpAccessException extends RuntimeException {
    public enum Reason { INVALID, EXPIRED_OR_USED, BLOCKED }
    private final Reason reason;

    public OtpAccessException(Reason reason, String message) {
        super(message);
        this.reason = reason;
    }

    public Reason reason() { return reason; }
}
