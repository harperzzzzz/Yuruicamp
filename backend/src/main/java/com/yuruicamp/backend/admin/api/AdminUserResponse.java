package com.yuruicamp.backend.admin.api;

import java.time.Instant;
import java.util.Map;
import java.util.Set;

import com.yuruicamp.backend.admin.domain.AdminRole;

public record AdminUserResponse(
		String id,
		String name,
		String email,
		AdminRole role,
		boolean active,
		String firebaseUid,
		boolean firebaseUidBound,
		Instant createdAt,
		Instant updatedAt,
		Map<String, Boolean> permissionOverrides,
		Set<String> effectivePermissions) {
}
