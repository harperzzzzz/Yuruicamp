package com.yuruicamp.backend.common.security;

/**
 * Authenticated storefront member principal (resolved from Firebase UID).
 */
public record CustomerPrincipal(String customerId, String email, String firebaseUid) {
}
