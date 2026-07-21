package com.yuruicamp.backend.admin.api;

import java.util.Map;

import jakarta.validation.constraints.NotEmpty;

public record AdminPermissionUpdateRequest(@NotEmpty Map<String, Boolean> permissions) {
}
