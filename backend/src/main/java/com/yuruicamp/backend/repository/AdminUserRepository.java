package com.yuruicamp.backend.repository;

import com.yuruicamp.backend.entity.AdminUser;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminUserRepository extends JpaRepository<AdminUser, String> {
}
