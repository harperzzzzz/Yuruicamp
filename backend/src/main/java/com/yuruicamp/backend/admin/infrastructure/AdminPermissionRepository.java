package com.yuruicamp.backend.admin.infrastructure;

import java.util.List;
import java.util.Set;

import com.yuruicamp.backend.admin.domain.AdminPermission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AdminPermissionRepository extends JpaRepository<AdminPermission, String> {

	List<AdminPermission> findAllByOrderBySectionAscActionAsc();

	@Query(value = "SELECT permission_code FROM admin_role_permissions WHERE role = :role", nativeQuery = true)
	Set<String> findRolePermissionCodes(@Param("role") String role);

	@Query(value = """
			SELECT permission_code
			FROM admin_user_permissions
			WHERE admin_user_id = :adminUserId AND allowed = true
			""", nativeQuery = true)
	Set<String> findAllowedOverrideCodes(@Param("adminUserId") String adminUserId);

	@Query(value = """
			SELECT permission_code
			FROM admin_user_permissions
			WHERE admin_user_id = :adminUserId AND allowed = false
			""", nativeQuery = true)
	Set<String> findDeniedOverrideCodes(@Param("adminUserId") String adminUserId);

	@Modifying
	@Query(value = "DELETE FROM admin_user_permissions WHERE admin_user_id = :adminUserId", nativeQuery = true)
	void deleteOverrides(@Param("adminUserId") String adminUserId);

	@Modifying
	@Query(value = """
			INSERT INTO admin_user_permissions (admin_user_id, permission_code, allowed)
			VALUES (:adminUserId, :permissionCode, :allowed)
			""", nativeQuery = true)
	void insertOverride(
			@Param("adminUserId") String adminUserId,
			@Param("permissionCode") String permissionCode,
			@Param("allowed") boolean allowed);
}
