package com.yuruicamp.backend.admin.application;

import java.time.Instant;
import java.util.Collections;
import java.util.Set;
import java.util.UUID;

import com.yuruicamp.backend.admin.api.AdminPermissionUpdateRequest;
import com.yuruicamp.backend.admin.api.AdminUserCreateRequest;
import com.yuruicamp.backend.admin.api.AdminUserResponse;
import com.yuruicamp.backend.admin.api.AdminUserUpdateRequest;
import com.yuruicamp.backend.admin.domain.AdminRole;
import com.yuruicamp.backend.admin.domain.AdminUser;
import com.yuruicamp.backend.admin.infrastructure.AdminUserRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 管理員帳號用例，統一處理白名單建立、啟停與最後管理員保護。
 */
@Service
public class AdminUserService {

	private final AdminUserRepository adminUserRepository;
	private final AdminPermissionService adminPermissionService;

	public AdminUserService(
			AdminUserRepository adminUserRepository,
			AdminPermissionService adminPermissionService) {
		this.adminUserRepository = adminUserRepository;
		this.adminPermissionService = adminPermissionService;
	}

	@Transactional(readOnly = true)
	public Page<AdminUserResponse> listUsers(int page, int size) {
		validatePage(page, size);

		PageRequest pageable = PageRequest.of(
				page,
				size,
				Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id")));

		return adminUserRepository.findAll(pageable)
				.map(this::toSummaryResponse);
	}

	@Transactional(readOnly = true)
	public AdminUserResponse getUser(String id) {
		AdminUser admin = findUser(id);

		return toDetailResponse(admin);
	}

	@Transactional
	public AdminUserResponse createUser(AdminUserCreateRequest request) {
		String normalizedEmail = request.email().trim().toLowerCase(java.util.Locale.ROOT);
		if (adminUserRepository.existsByEmailIgnoreCase(normalizedEmail)) {
			throw new BusinessException(ErrorCode.CONFLICT, "Admin email already exists");
		}

		Instant now = Instant.now();
		AdminUser admin = new AdminUser();
		admin.setId(UUID.randomUUID().toString().replace("-", ""));
		admin.setName(request.name().trim());
		admin.setEmail(normalizedEmail);
		admin.setRole(request.role());
		admin.setActive(true);
		admin.setCreatedAt(now);
		admin.setUpdatedAt(now);

		AdminUser saved = adminUserRepository.save(admin);

		return toDetailResponse(saved);
	}

	@Transactional
	public AdminUserResponse updateUser(String actorId, String targetId, AdminUserUpdateRequest request) {
		// 固定先鎖定全部啟用帳號，避免同時停用或降級造成管理員歸零。
		adminUserRepository.findActiveUsersForUpdate();
		AdminUser target = adminUserRepository.findByIdForUpdate(targetId)
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Admin user not found"));

		validateProtectedUpdate(actorId, target, request);

		if (request.name() != null) {
			target.setName(request.name().trim());
		}
		if (request.role() != null) {
			target.setRole(request.role());
		}
		if (request.active() != null) {
			target.setActive(request.active());
		}
		target.setUpdatedAt(Instant.now());

		AdminUser saved = adminUserRepository.save(target);

		return toDetailResponse(saved);
	}

	@Transactional
	public AdminUserResponse replacePermissions(
			String actorId,
			String targetId,
			AdminPermissionUpdateRequest request) {
		// 權限管理者保護與帳號更新使用相同鎖順序，避免互相等待。
		adminUserRepository.findActiveUsersForUpdate();
		AdminUser target = adminUserRepository.findByIdForUpdate(targetId)
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Admin user not found"));

		if (actorId.equals(targetId)
				&& !Boolean.TRUE.equals(request.permissions().get(AdminPermissionService.PERMISSIONS_EDIT))) {
			throw new BusinessException(ErrorCode.CONFLICT, "You cannot remove your own admin edit permission");
		}
		validateLastPermissionManager(target, request);

		adminPermissionService.replaceOverrides(targetId, target.getRole(), request.permissions());
		target.setUpdatedAt(Instant.now());
		adminUserRepository.save(target);

		return toDetailResponse(target);
	}

	private void validatePage(int page, int size) {
		if (page < 0 || size < 1 || size > 100) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "page must be >= 0 and size must be 1 to 100");
		}
	}

	private void validateProtectedUpdate(String actorId, AdminUser target, AdminUserUpdateRequest request) {
		if (actorId.equals(target.getId()) && Boolean.FALSE.equals(request.active())) {
			throw new BusinessException(ErrorCode.CONFLICT, "You cannot disable your own admin account");
		}

		boolean removesActiveAdmin = target.isActive()
				&& target.getRole() == AdminRole.admin
				&& (Boolean.FALSE.equals(request.active())
						|| request.role() != null && request.role() != AdminRole.admin);
		if (removesActiveAdmin) {
			long activeAdminCount = adminUserRepository.findActiveUsersForUpdate()
					.stream()
					.filter(admin -> admin.getRole() == AdminRole.admin)
					.count();
			if (activeAdminCount <= 1) {
				throw new BusinessException(ErrorCode.CONFLICT, "At least one active admin role account is required");
			}
		}
	}

	private void validateLastPermissionManager(
			AdminUser target,
			AdminPermissionUpdateRequest request) {
		if (!target.isActive()
				|| Boolean.TRUE.equals(request.permissions().get(AdminPermissionService.PERMISSIONS_EDIT))) {
			return;
		}

		boolean anotherManagerExists = adminUserRepository.findActiveUsersForUpdate()
				.stream()
				.filter(admin -> !admin.getId().equals(target.getId()))
				.anyMatch(admin -> adminPermissionService.resolveEffectivePermissions(
						admin.getId(),
						admin.getRole()).contains(AdminPermissionService.PERMISSIONS_EDIT));
		if (!anotherManagerExists) {
			throw new BusinessException(ErrorCode.CONFLICT, "At least one active permission manager is required");
		}
	}

	private AdminUser findUser(String id) {
		return adminUserRepository.findById(id)
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Admin user not found"));
	}

	private AdminUserResponse toSummaryResponse(AdminUser admin) {
		return new AdminUserResponse(
				admin.getId(),
				admin.getName(),
				admin.getEmail(),
				admin.getRole(),
				admin.isActive(),
				admin.getFirebaseUid(),
				admin.getFirebaseUid() != null && !admin.getFirebaseUid().isBlank(),
				admin.getCreatedAt(),
				admin.getUpdatedAt(),
				Collections.emptyMap(),
				Collections.emptySet());
	}

	private AdminUserResponse toDetailResponse(AdminUser admin) {
		Set<String> effectivePermissions = adminPermissionService.resolveEffectivePermissions(
				admin.getId(),
				admin.getRole());

		return new AdminUserResponse(
				admin.getId(),
				admin.getName(),
				admin.getEmail(),
				admin.getRole(),
				admin.isActive(),
				admin.getFirebaseUid(),
				admin.getFirebaseUid() != null && !admin.getFirebaseUid().isBlank(),
				admin.getCreatedAt(),
				admin.getUpdatedAt(),
				adminPermissionService.loadPermissionOverrides(admin.getId()),
				effectivePermissions);
	}
}
