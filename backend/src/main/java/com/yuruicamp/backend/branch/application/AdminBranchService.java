package com.yuruicamp.backend.branch.application;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import com.yuruicamp.backend.branch.api.AdminBranchCreateRequest;
import com.yuruicamp.backend.branch.api.AdminBranchResponse;
import com.yuruicamp.backend.branch.api.AdminBranchUpdateRequest;
import com.yuruicamp.backend.branch.infrastructure.AdminBranchRepository;
import com.yuruicamp.backend.branch.infrastructure.AdminBranchRepository.BranchRow;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 用途：門市主檔 CRUD 與安全刪除（ADM-W2-07）。
 * 核心重點（給新手）：
 *   1. 「啟停」不是獨立按鈕，而是 PATCH body 傳 `active: true/false`（跟會員標籤池同一套邏輯）。
 *   2. 硬刪前一定要先數「有沒有人在用這間門市」：
 *      - `orders.pickup_branch_id`（有人選這間門市取貨）
 *      - `inventory_locations.branch_id`（這間門市底下還有庫位）
 *      只要任何一個 > 0，就回 409，訊息引導改用 `active=false` 軟停用，不真的刪資料。
 *   3. 公開 `GET /api/branches` 已經在別的 Service（BranchCatalogService）只回 active=true，
 *      這裡的後台 CRUD 永遠看得到全部門市，方便管理員決定要不要復用。
 * Admin branch CRUD; hard-delete is blocked (409) when referenced by orders or inventory locations.
 */
@Service
public class AdminBranchService {

	private final AdminBranchRepository repository;

	public AdminBranchService(AdminBranchRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public List<AdminBranchResponse> list() {
		return repository.findAll().stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public AdminBranchResponse get(String id) {
		BranchRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}
		return toResponse(row);
	}

	@Transactional
	public AdminBranchResponse create(AdminBranchCreateRequest request) {
		String id = normalizeRequired(request.id(), "Branch id");
		String name = normalizeRequired(request.name(), "Branch name");
		String address = normalizeRequired(request.address(), "Branch address");
		String phone = normalizeRequired(request.phone(), "Branch phone");
		String businessHours = normalizeRequired(request.businessHours(), "Branch businessHours");
		String mapQuery = normalizeOptional(request.mapQuery());
		String imageUrl = normalizeOptional(request.imageUrl());
		BigDecimal latitude = request.latitude();
		BigDecimal longitude = request.longitude();
		boolean active = request.active() == null || request.active();

		if (repository.findById(id) != null) {
			throw conflict("Branch id already exists");
		}
		try {
			repository.insert(id, name, address, phone, latitude, longitude, mapQuery,
					businessHours, imageUrl, active, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Branch id already exists");
		}
	}

	@Transactional
	public AdminBranchResponse update(String id, AdminBranchUpdateRequest request) {
		BranchRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}

		String name = request.name() == null ? existing.name() : normalizeRequired(request.name(), "Branch name");
		String address = request.address() == null
				? existing.address()
				: normalizeRequired(request.address(), "Branch address");
		String phone = request.phone() == null ? existing.phone() : normalizeRequired(request.phone(), "Branch phone");
		String businessHours = request.businessHours() == null
				? existing.businessHours()
				: normalizeRequired(request.businessHours(), "Branch businessHours");
		// mapQuery／imageUrl／latitude／longitude：省略（null）時保留原值；
		// 這幾個欄位本身允許清空，但 record 分不出「沒傳」跟「故意傳 null」，
		// 所以跟品牌主檔的 logoUrl 一樣，統一採「null＝不改」，之後真的需要清空可另開欄位處理。
		String mapQuery = request.mapQuery() == null ? existing.mapQuery() : normalizeOptional(request.mapQuery());
		String imageUrl = request.imageUrl() == null ? existing.imageUrl() : normalizeOptional(request.imageUrl());
		BigDecimal latitude = request.latitude() == null ? existing.latitude() : request.latitude();
		BigDecimal longitude = request.longitude() == null ? existing.longitude() : request.longitude();
		boolean active = request.active() == null ? existing.active() : request.active();

		try {
			repository.update(id, name, address, phone, latitude, longitude, mapQuery,
					businessHours, imageUrl, active, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Branch update violates a database constraint");
		}
	}

	@Transactional
	public void delete(String id) {
		BranchRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		if (repository.countOrderReferences(id) > 0 || repository.countInventoryLocationReferences(id) > 0) {
			throw conflict("Branch is referenced by orders or inventory locations; set active=false instead");
		}
		repository.delete(id);
	}

	private String normalizeRequired(String value, String label) {
		String trimmed = value == null ? "" : value.trim();
		if (trimmed.isBlank()) {
			throw validation(label + " must not be blank");
		}
		return trimmed;
	}

	private String normalizeOptional(String value) {
		if (value == null) {
			return null;
		}
		String trimmed = value.trim();
		return trimmed.isEmpty() ? null : trimmed;
	}

	private AdminBranchResponse toResponse(BranchRow row) {
		return new AdminBranchResponse(
				row.id(),
				row.name(),
				row.address(),
				row.phone(),
				row.latitude(),
				row.longitude(),
				row.mapQuery(),
				row.businessHours(),
				row.imageUrl(),
				row.active(),
				row.createdAt(),
				row.updatedAt());
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Branch not found");
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
