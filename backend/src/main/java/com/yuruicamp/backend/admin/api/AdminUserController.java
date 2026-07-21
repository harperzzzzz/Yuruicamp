package com.yuruicamp.backend.admin.api;

import java.util.List;

import com.yuruicamp.backend.admin.application.AdminPermissionService;
import com.yuruicamp.backend.admin.application.AdminUserService;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.security.AdminPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin RBAC", description = "管理員白名單帳號與細權限")
public class AdminUserController {

	private final AdminUserService adminUserService;
	private final AdminPermissionService adminPermissionService;

	public AdminUserController(
			AdminUserService adminUserService,
			AdminPermissionService adminPermissionService) {
		this.adminUserService = adminUserService;
		this.adminPermissionService = adminPermissionService;
	}

	@GetMapping("/users")
	@PreAuthorize("hasAuthority('permissions.view')")
	@Operation(summary = "管理員列表", description = "RBAC: permissions.view")
	public ApiResponse<List<AdminUserResponse>> listUsers(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size) {
		var result = adminUserService.listUsers(page, size);
		PageMeta meta = new PageMeta(result.getNumber(), result.getSize(), result.getTotalElements(), result.getTotalPages());

		return ApiResponse.ok(result.getContent(), meta);
	}

	@GetMapping("/users/{id}")
	@PreAuthorize("hasAuthority('permissions.view')")
	@Operation(summary = "管理員詳情", description = "RBAC: permissions.view")
	public ApiResponse<AdminUserResponse> getUser(@PathVariable String id) {
		return ApiResponse.ok(adminUserService.getUser(id));
	}

	@PostMapping("/users")
	@PreAuthorize("hasAuthority('permissions.edit')")
	@Operation(summary = "建立管理員白名單", description = "RBAC: permissions.edit")
	public ApiResponse<AdminUserResponse> createUser(@Valid @RequestBody AdminUserCreateRequest request) {
		return ApiResponse.ok(adminUserService.createUser(request));
	}

	@PatchMapping("/users/{id}")
	@PreAuthorize("hasAuthority('permissions.edit')")
	@Operation(summary = "更新管理員", description = "RBAC: permissions.edit")
	public ApiResponse<AdminUserResponse> updateUser(
			@AuthenticationPrincipal AdminPrincipal principal,
			@PathVariable String id,
			@Valid @RequestBody AdminUserUpdateRequest request) {
		return ApiResponse.ok(adminUserService.updateUser(principal.adminUserId(), id, request));
	}

	@PutMapping("/users/{id}/permissions")
	@PreAuthorize("hasAuthority('permissions.edit')")
	@Operation(summary = "取代個別權限覆寫", description = "RBAC: permissions.edit")
	public ApiResponse<AdminUserResponse> replacePermissions(
			@AuthenticationPrincipal AdminPrincipal principal,
			@PathVariable String id,
			@Valid @RequestBody AdminPermissionUpdateRequest request) {
		return ApiResponse.ok(adminUserService.replacePermissions(principal.adminUserId(), id, request));
	}

	@GetMapping("/permissions")
	@PreAuthorize("hasAuthority('permissions.view')")
	@Operation(summary = "權限字典", description = "RBAC: permissions.view")
	public ApiResponse<List<AdminPermissionResponse>> listPermissions() {
		return ApiResponse.ok(adminPermissionService.listPermissionDictionary());
	}
}
