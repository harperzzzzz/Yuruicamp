package com.yuruicamp.backend.admin.api;

import com.yuruicamp.backend.admin.domain.AdminRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record AdminUserCreateRequest(
		@NotBlank @Size(max = 100) String name,
		@NotBlank @Email @Size(max = 254) String email,
		@NotNull AdminRole role) {
}
