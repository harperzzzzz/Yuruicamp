package com.yuruicamp.backend.admin.infrastructure;

import java.util.Optional;

import com.yuruicamp.backend.admin.domain.AdminUser;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminUserRepository extends JpaRepository<AdminUser, String> {

	Optional<AdminUser> findByEmailIgnoreCase(String email);

	Optional<AdminUser> findByFirebaseUid(String firebaseUid);
}
