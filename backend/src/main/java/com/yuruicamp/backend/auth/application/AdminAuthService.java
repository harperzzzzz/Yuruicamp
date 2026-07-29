package com.yuruicamp.backend.auth.application;

import java.time.Instant;

import com.yuruicamp.backend.admin.domain.AdminUser;
import com.yuruicamp.backend.admin.infrastructure.AdminUserRepository;
import com.yuruicamp.backend.admin.application.AdminPermissionService;
import com.yuruicamp.backend.auth.api.AdminSessionResponse;
import com.yuruicamp.backend.auth.infrastructure.FirebaseTokenVerifier;
import com.yuruicamp.backend.auth.infrastructure.VerifiedFirebaseToken;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Admin login: email must already exist in {@code admin_users} (whitelist).
 * Skeleton A only checks active + binds firebase_uid; full RBAC later.
 */
@Service
public class AdminAuthService {

	private final FirebaseTokenVerifier tokenVerifier;
	private final AdminUserRepository adminUserRepository;
	private final AdminPermissionService adminPermissionService;

	public AdminAuthService(
			FirebaseTokenVerifier tokenVerifier,
			AdminUserRepository adminUserRepository,
			AdminPermissionService adminPermissionService) {
		this.tokenVerifier = tokenVerifier;
		this.adminUserRepository = adminUserRepository;
		this.adminPermissionService = adminPermissionService;
	}

	@Transactional
	public AdminSessionResponse establishSession(String idToken) {
		VerifiedFirebaseToken verified = tokenVerifier.verify(idToken);

		AdminUser admin = adminUserRepository.findByEmailIgnoreCase(verified.email())
				.orElseThrow(() -> new BusinessException(
						ErrorCode.ADMIN_NOT_WHITELISTED,
						"Admin email is not whitelisted"));

		if (!admin.isActive()) {
			throw new BusinessException(ErrorCode.ADMIN_INACTIVE, "Admin account is disabled");
		}

		boolean boundNow = false;
		if (admin.getFirebaseUid() == null || admin.getFirebaseUid().isBlank()) {
			admin.setFirebaseUid(verified.uid());
			boundNow = true;
		}
		else if (!admin.getFirebaseUid().equals(verified.uid())) {
			throw new BusinessException(ErrorCode.FORBIDDEN,
					"Admin email is already bound to a different Firebase account");
		}

		admin.setUpdatedAt(Instant.now());
		adminUserRepository.save(admin);

		return new AdminSessionResponse(
				admin.getId(),
				admin.getEmail(),
				admin.getName(),
				admin.getRole().name(),
				admin.getFirebaseUid(),
				boundNow,
				adminPermissionService.resolveEffectivePermissions(admin.getId(), admin.getRole()));
	}
}
