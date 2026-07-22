package com.yuruicamp.backend.admin.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * 後台功能權限字典，每筆權限由功能區與 view 或 edit 動作組成。
 */
@Entity
@Table(name = "admin_permissions")
public class AdminPermission {

	@Id
	@Column(length = 64)
	private String code;

	@Column(nullable = false, length = 32)
	private String section;

	@Column(nullable = false, length = 16)
	private String action;

	public String getCode() {
		return code;
	}

	public void setCode(String code) {
		this.code = code;
	}

	public String getSection() {
		return section;
	}

	public void setSection(String section) {
		this.section = section;
	}

	public String getAction() {
		return action;
	}

	public void setAction(String action) {
		this.action = action;
	}
}
