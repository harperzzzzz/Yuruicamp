package com.yuruicamp.backend.admin.api;

import java.util.Set;

/**
 * 提供前端繪製權限矩陣的固定權限字典。
 */
public record AdminPermissionResponse(String code, String section, String action, Set<String> defaultRoles) {
}
