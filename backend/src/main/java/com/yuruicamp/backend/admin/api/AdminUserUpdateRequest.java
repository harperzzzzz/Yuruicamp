package com.yuruicamp.backend.admin.api;

import com.yuruicamp.backend.admin.domain.AdminRole;
import jakarta.validation.constraints.Size;

public record AdminUserUpdateRequest(
		@Size(min = 1, max = 100) String name,
		AdminRole role,
		Boolean active) {
}
