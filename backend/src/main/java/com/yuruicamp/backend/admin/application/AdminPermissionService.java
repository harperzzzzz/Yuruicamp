package com.yuruicamp.backend.admin.application;

import java.util.HashSet;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.yuruicamp.backend.admin.api.AdminPermissionResponse;
import com.yuruicamp.backend.admin.domain.AdminPermission;
import com.yuruicamp.backend.admin.domain.AdminRole;
import com.yuruicamp.backend.admin.infrastructure.AdminPermissionRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 合併角色預設與個人覆寫，產生後端實際用來授權的權限集合。
 */
@Service
public class AdminPermissionService {

	public static final String PERMISSIONS_VIEW = "permissions.view";
	public static final String PERMISSIONS_EDIT = "permissions.edit";

	private final AdminPermissionRepository adminPermissionRepository;

	public AdminPermissionService(AdminPermissionRepository adminPermissionRepository) {
		this.adminPermissionRepository = adminPermissionRepository;
	}

	@Transactional(readOnly = true)
	public Set<String> resolveEffectivePermissions(String adminUserId, AdminRole role) {
		Set<String> permissions = new HashSet<>(adminPermissionRepository.findRolePermissionCodes(role.name()));

		permissions.addAll(adminPermissionRepository.findAllowedOverrideCodes(adminUserId));
		permissions.removeAll(adminPermissionRepository.findDeniedOverrideCodes(adminUserId));

		return permissions;
	}

	@Transactional(readOnly = true)
	public List<AdminPermissionResponse> listPermissionDictionary() {
		Map<String, Set<String>> rolesByCode = new HashMap<>();
		for (AdminRole role : AdminRole.values()) {
			adminPermissionRepository.findRolePermissionCodes(role.name())
					.forEach(code -> rolesByCode
							.computeIfAbsent(code, ignored -> new LinkedHashSet<>())
							.add(role.name()));
		}

		return adminPermissionRepository.findAllByOrderBySectionAscActionAsc()
				.stream()
				.map(permission -> new AdminPermissionResponse(
						permission.getCode(),
						permission.getSection(),
						permission.getAction(),
						rolesByCode.getOrDefault(permission.getCode(), Set.of())))
				.toList();
	}

	@Transactional(readOnly = true)
	public Map<String, Boolean> loadPermissionOverrides(String adminUserId) {
		Map<String, Boolean> overrides = new LinkedHashMap<>();

		adminPermissionRepository.findAllowedOverrideCodes(adminUserId)
				.stream()
				.sorted()
				.forEach(code -> overrides.put(code, true));
		adminPermissionRepository.findDeniedOverrideCodes(adminUserId)
				.stream()
				.sorted()
				.forEach(code -> overrides.put(code, false));

		return overrides;
	}

	@Transactional
	public void replaceOverrides(String adminUserId, AdminRole role, Map<String, Boolean> desiredPermissions) {
		List<AdminPermission> dictionary = adminPermissionRepository.findAllByOrderBySectionAscActionAsc();
		Set<String> knownCodes = dictionary
				.stream()
				.map(AdminPermission::getCode)
				.collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));

		validateDesiredPermissions(knownCodes, desiredPermissions);

		Set<String> rolePermissions = adminPermissionRepository.findRolePermissionCodes(role.name());
		adminPermissionRepository.deleteOverrides(adminUserId);
		desiredPermissions.forEach((code, allowed) -> {
			if (rolePermissions.contains(code) != allowed) {
				adminPermissionRepository.insertOverride(adminUserId, code, allowed);
			}
		});
	}

	private void validateDesiredPermissions(Set<String> knownCodes, Map<String, Boolean> desiredPermissions) {
		if (!knownCodes.equals(desiredPermissions.keySet())) {
			throw new BusinessException(
					ErrorCode.VALIDATION_ERROR,
					"Permissions must contain every known permission code exactly once");
		}

		desiredPermissions.forEach((code, allowed) -> {
			if (code.endsWith(".edit") && Boolean.TRUE.equals(allowed)) {
				String viewCode = code.substring(0, code.length() - 5) + ".view";
				if (!Boolean.TRUE.equals(desiredPermissions.get(viewCode))) {
					throw new BusinessException(
							ErrorCode.VALIDATION_ERROR,
							"Edit permission requires the matching view permission");
				}
			}
		});
	}
}
