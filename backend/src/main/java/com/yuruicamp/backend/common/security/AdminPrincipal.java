package com.yuruicamp.backend.common.security;

/**
 * Authenticated admin principal (whitelist + active only in skeleton A).
 * Full RBAC permissions come in a later slice.
 */
public record AdminPrincipal(String adminUserId, String email, String role, String firebaseUid) {
}
