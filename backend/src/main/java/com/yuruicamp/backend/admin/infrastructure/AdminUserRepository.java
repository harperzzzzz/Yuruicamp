package com.yuruicamp.backend.admin.infrastructure;

import java.util.Optional;
import java.util.List;

import com.yuruicamp.backend.admin.domain.AdminUser;
import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AdminUserRepository extends JpaRepository<AdminUser, String> {

	Optional<AdminUser> findByEmailIgnoreCase(String email);

	Optional<AdminUser> findByFirebaseUid(String firebaseUid);

	boolean existsByEmailIgnoreCase(String email);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT admin FROM AdminUser admin WHERE admin.id = :id")
	Optional<AdminUser> findByIdForUpdate(@Param("id") String id);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT admin FROM AdminUser admin WHERE admin.active = true ORDER BY admin.id")
	List<AdminUser> findActiveUsersForUpdate();
}
