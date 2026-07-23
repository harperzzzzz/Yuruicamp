package com.yuruicamp.backend.catalog.application;

import java.time.Instant;
import java.util.List;

import com.yuruicamp.backend.catalog.api.AdminBrandCreateRequest;
import com.yuruicamp.backend.catalog.api.AdminBrandResponse;
import com.yuruicamp.backend.catalog.api.AdminBrandUpdateRequest;
import com.yuruicamp.backend.catalog.infrastructure.AdminBrandRepository;
import com.yuruicamp.backend.catalog.infrastructure.AdminBrandRepository.BrandRow;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 品牌主檔 CRUD：無 equipment 引用可硬刪，有引用 → 409。
 * Admin brand CRUD (hard-delete only when unreferenced).
 */
@Service
public class AdminBrandService {

	private final AdminBrandRepository repository;

	public AdminBrandService(AdminBrandRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public List<AdminBrandResponse> list() {
		return repository.findAll().stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public AdminBrandResponse get(String id) {
		BrandRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}
		return toResponse(row);
	}

	@Transactional
	public AdminBrandResponse create(AdminBrandCreateRequest request) {
		String id = normalizeRequired(request.id(), "Brand id");
		String name = normalizeRequired(request.name(), "Brand name");
		String logoUrl = normalizeOptional(request.logoUrl());
		int sortOrder = request.sortOrder() == null ? 0 : request.sortOrder();
		if (sortOrder < 0) {
			throw validation("Brand sortOrder must be >= 0");
		}
		if (repository.findById(id) != null) {
			throw conflict("Brand id already exists");
		}
		try {
			repository.insert(id, name, logoUrl, sortOrder, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Brand id or name already exists");
		}
	}

	@Transactional
	public AdminBrandResponse update(String id, AdminBrandUpdateRequest request) {
		BrandRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		String name = request.name() == null
				? existing.name()
				: normalizeRequired(request.name(), "Brand name");
		// logoUrl：明確傳 null／空字串可清空；省略欄位時 Jackson 也是 null → 這裡用「有 key」較難判斷，
		// 契約採：有傳字串（含空）就更新；Java record 無法區分 omitted／null，故 null 視為清空、與既有一致時可傳回。
		// 為避免 PATCH 只改 name 卻清掉 logo，採：request.logoUrl() == null 時保留既有。
		String logoUrl = request.logoUrl() == null ? existing.logoUrl() : normalizeOptional(request.logoUrl());
		int sortOrder = request.sortOrder() == null ? existing.sortOrder() : request.sortOrder();
		if (sortOrder < 0) {
			throw validation("Brand sortOrder must be >= 0");
		}
		try {
			repository.update(id, name, logoUrl, sortOrder, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Brand name already exists");
		}
	}

	@Transactional
	public void delete(String id) {
		BrandRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		if (repository.countEquipmentReferences(id) > 0) {
			throw conflict("Brand is referenced by equipment items and cannot be deleted");
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

	private AdminBrandResponse toResponse(BrandRow row) {
		return new AdminBrandResponse(
				row.id(),
				row.name(),
				row.logoUrl(),
				row.sortOrder(),
				row.createdAt(),
				row.updatedAt());
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Brand not found");
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
