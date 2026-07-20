package com.yuruicamp.backend.payment;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import org.springframework.stereotype.Component;

@Component
public class EcpayCheckMacValue {

    public String generate(Map<String, String> fields, String hashKey, String hashIv) {
        TreeMap<String, String> sorted = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        sorted.putAll(fields);
        sorted.remove("CheckMacValue");

        StringBuilder raw = new StringBuilder("HashKey=").append(hashKey);
        sorted.forEach((key, value) -> raw.append('&').append(key).append('=').append(value));
        raw.append("&HashIV=").append(hashIv);

        String encoded = ecpayUrlEncode(raw.toString()).toLowerCase(Locale.ROOT);
        return sha256(encoded).toUpperCase(Locale.ROOT);
    }

    public boolean verify(Map<String, String> fields, String hashKey, String hashIv) {
        String received = fields.get("CheckMacValue");
        if (received == null || received.isBlank()) {
            return false;
        }
        String expected = generate(fields, hashKey, hashIv);
        return MessageDigest.isEqual(
                received.toUpperCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8),
                expected.getBytes(StandardCharsets.UTF_8));
    }

    private String ecpayUrlEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8)
                .replace("%2D", "-")
                .replace("%5F", "_")
                .replace("%2E", ".")
                .replace("%21", "!")
                .replace("%2A", "*")
                .replace("%28", "(")
                .replace("%29", ")")
                .replace("~", "%7e");
    }

    private String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 is not available", ex);
        }
    }
}
