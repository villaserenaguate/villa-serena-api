package com.villaserena.api.auth.huesped;

import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** Hash lento con sal aleatoria; cabe en codigo_hash VARCHAR(100). */
public final class OtpHasher {
    private static final int ITERATIONS = 210_000;
    private final SecureRandom random = new SecureRandom();

    public String hash(String code) {
        byte[] salt = new byte[16];
        random.nextBytes(salt);
        var encoder = Base64.getUrlEncoder().withoutPadding();
        return ITERATIONS + "." + encoder.encodeToString(salt) + "." + encoder.encodeToString(derive(code, salt));
    }

    public boolean matches(String code, String hash) {
        try {
            String[] parts = hash.split("\\.");
            if (parts.length != 3 || !parts[0].equals(Integer.toString(ITERATIONS))) return false;
            var decoder = Base64.getUrlDecoder();
            byte[] salt = decoder.decode(parts[1]);
            byte[] expected = decoder.decode(parts[2]);
            if (salt.length != 16 || expected.length != 32) return false;
            return MessageDigest.isEqual(expected, derive(code, salt));
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private byte[] derive(String code, byte[] salt) {
        var spec = new PBEKeySpec(code.toCharArray(), salt, ITERATIONS, 256);
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("No fue posible proteger el código de acceso.", e);
        } finally {
            spec.clearPassword();
        }
    }
}
