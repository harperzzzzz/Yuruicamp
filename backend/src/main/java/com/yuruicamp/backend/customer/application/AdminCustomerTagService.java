package com.yuruicamp.backend.customer.application;

import java.time.Instant;
import java.util.List;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.customer.api.AdminCustomerTagCreateRequest;
import com.yuruicamp.backend.customer.api.AdminCustomerTagPoolResponse;
import com.yuruicamp.backend.customer.api.AdminCustomerTagUpdateRequest;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerTagRepository;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerTagRepository.TagRow;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台會員標籤池 CRUD：名稱唯一；有指派時禁硬刪、改停用。
 * Admin customer tag pool use-cases.
 */
@Service
public class AdminCustomerTagService {

	private final AdminCustomerTagRepository repository;

	public AdminCustomerTagService(AdminCustomerTagRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public List<AdminCustomerTagPoolResponse> list(boolean includeInactive) {
		return repository.findAll(includeInactive).stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public AdminCustomerTagPoolResponse get(long id) {
		TagRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}
		return toResponse(row);
	}

	@Transactional
	public AdminCustomerTagPoolResponse create(AdminCustomerTagCreateRequest request) {
		String name = normalizeName(request.name());
		String color = normalizeColor(request.color());
		int sortOrder = request.sortOrder() == null ? 0 : request.sortOrder();
		boolean active = request.active() == null || request.active();
		validateWrite(name, color, sortOrder);

		try {
			long id = repository.insert(name, color, sortOrder, active, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Customer tag name already exists");
		}
	}

	@Transactional
	public AdminCustomerTagPoolResponse update(long id, AdminCustomerTagUpdateRequest request) {
		TagRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}

		String name = request.name() == null ? existing.name() : normalizeName(request.name());
		String color = request.color() == null ? existing.color() : normalizeColor(request.color());
		int sortOrder = request.sortOrder() == null ? existing.sortOrder() : request.sortOrder();
		boolean active = request.active() == null ? existing.active() : request.active();
		validateWrite(name, color, sortOrder);

		try {
			repository.update(id, name, color, sortOrder, active, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Customer tag name already exists");
		}
	}

	@Transactional
	public void delete(long id) {
		TagRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		if (repository.countAssignments(id) > 0) {
			throw conflict("Assigned customer tag cannot be deleted; set active=false instead");
		}
		repository.delete(id);
	}

	private void validateWrite(String name, String color, int sortOrder) {
		if (name.isBlank()) {
			throw validation("Customer tag name must not be blank");
		}
		if (color.isBlank()) {
			throw validation("Customer tag color must not be blank");
		}
		if (sortOrder < 0) {
			throw validation("Customer tag sortOrder must be >= 0");
		}
	}

	private String normalizeName(String name) {
		return name == null ? "" : name.trim();
	}

	private String normalizeColor(String color) {
		return color == null ? "" : color.trim();
	}

	private AdminCustomerTagPoolResponse toResponse(TagRow row) {
		return new AdminCustomerTagPoolResponse(
				row.id(),
				row.name(),
				row.color(),
				row.sortOrder(),
				row.active(),
				row.createdAt(),
				row.updatedAt());
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Customer tag not found");
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
