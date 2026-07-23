package com.yuruicamp.backend.catalog.application;

import java.time.Instant;
import java.util.List;

import com.yuruicamp.backend.catalog.api.AdminCategoryCreateRequest;
import com.yuruicamp.backend.catalog.api.AdminCategoryResponse;
import com.yuruicamp.backend.catalog.api.AdminCategoryUpdateRequest;
import com.yuruicamp.backend.catalog.infrastructure.AdminCategoryRepository;
import com.yuruicamp.backend.catalog.infrastructure.AdminCategoryRepository.CategoryRow;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 分類主檔 CRUD：無 equipment 引用可硬刪，有引用 → 409。
 * Admin category CRUD (hard-delete only when unreferenced).
 */
@Service
public class AdminCategoryService {

	private final AdminCategoryRepository repository;

	public AdminCategoryService(AdminCategoryRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public List<AdminCategoryResponse> list() {
		return repository.findAll().stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public AdminCategoryResponse get(long id) {
		CategoryRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}
		return toResponse(row);
	}

	@Transactional
	public AdminCategoryResponse create(AdminCategoryCreateRequest request) {
		String code = normalizeRequired(request.code(), "Category code");
		String name = normalizeRequired(request.name(), "Category name");
		int sortOrder = request.sortOrder() == null ? 0 : request.sortOrder();
		if (sortOrder < 0) {
			throw validation("Category sortOrder must be >= 0");
		}
		try {
			long id = repository.insert(code, name, sortOrder, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Category code or name already exists");
		}
	}

	@Transactional
	public AdminCategoryResponse update(long id, AdminCategoryUpdateRequest request) {
		CategoryRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		String code = request.code() == null
				? existing.code()
				: normalizeRequired(request.code(), "Category code");
		String name = request.name() == null
				? existing.name()
				: normalizeRequired(request.name(), "Category name");
		int sortOrder = request.sortOrder() == null ? existing.sortOrder() : request.sortOrder();
		if (sortOrder < 0) {
			throw validation("Category sortOrder must be >= 0");
		}
		try {
			repository.update(id, code, name, sortOrder, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Category code or name already exists");
		}
	}

	@Transactional
	public void delete(long id) {
		CategoryRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		if (repository.countEquipmentReferences(id) > 0) {
			throw conflict("Category is referenced by equipment items and cannot be deleted");
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

	private AdminCategoryResponse toResponse(CategoryRow row) {
		return new AdminCategoryResponse(
				row.id(),
				row.code(),
				row.name(),
				row.sortOrder(),
				row.createdAt(),
				row.updatedAt());
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Category not found");
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
