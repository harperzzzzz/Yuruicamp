package com.yuruicamp.backend.admin.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

import com.yuruicamp.backend.admin.domain.AdminRole;
import com.yuruicamp.backend.admin.infrastructure.AdminPermissionRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import org.junit.jupiter.api.Test;

class AdminPermissionServiceTest {

	@Test
	void effectivePermissionsApplyAllowedAndDeniedOverrides() {
		AdminPermissionRepository repository = mock(AdminPermissionRepository.class);
		when(repository.findRolePermissionCodes("operator"))
				.thenReturn(Set.of("orders.view", "orders.edit"));
		when(repository.findAllowedOverrideCodes("ADMIN-1"))
				.thenReturn(Set.of("products.view"));
		when(repository.findDeniedOverrideCodes("ADMIN-1"))
				.thenReturn(Set.of("orders.edit"));
		AdminPermissionService service = new AdminPermissionService(repository);

		Set<String> result = service.resolveEffectivePermissions("ADMIN-1", AdminRole.operator);

		assertEquals(Set.of("orders.view", "products.view"), result);
	}

	@Test
	void replaceOverridesStoresOnlyDifferencesFromRoleDefaults() {
		AdminPermissionRepository repository = mock(AdminPermissionRepository.class);
		var view = permission("orders.view", "orders", "view");
		var edit = permission("orders.edit", "orders", "edit");
		when(repository.findAllByOrderBySectionAscActionAsc()).thenReturn(java.util.List.of(edit, view));
		when(repository.findRolePermissionCodes("operator")).thenReturn(Set.of("orders.view"));
		AdminPermissionService service = new AdminPermissionService(repository);
		Map<String, Boolean> desired = new LinkedHashMap<>();
		desired.put("orders.view", true);
		desired.put("orders.edit", true);

		service.replaceOverrides("ADMIN-1", AdminRole.operator, desired);

		verify(repository).deleteOverrides("ADMIN-1");
		verify(repository).insertOverride("ADMIN-1", "orders.edit", true);
	}

	@Test
	void editPermissionRequiresMatchingViewPermission() {
		AdminPermissionRepository repository = mock(AdminPermissionRepository.class);
		var view = permission("orders.view", "orders", "view");
		var edit = permission("orders.edit", "orders", "edit");
		when(repository.findAllByOrderBySectionAscActionAsc()).thenReturn(java.util.List.of(edit, view));
		AdminPermissionService service = new AdminPermissionService(repository);

		assertThrows(BusinessException.class, () -> service.replaceOverrides(
				"ADMIN-1",
				AdminRole.operator,
				Map.of("orders.view", false, "orders.edit", true)));
	}

	private com.yuruicamp.backend.admin.domain.AdminPermission permission(
			String code,
			String section,
			String action) {
		var permission = new com.yuruicamp.backend.admin.domain.AdminPermission();
		permission.setCode(code);
		permission.setSection(section);
		permission.setAction(action);

		return permission;
	}
}
