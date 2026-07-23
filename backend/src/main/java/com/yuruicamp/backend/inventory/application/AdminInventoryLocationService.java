package com.yuruicamp.backend.inventory.application;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.inventory.api.AdminInventoryLocationCreateRequest;
import com.yuruicamp.backend.inventory.api.AdminInventoryLocationResponse;
import com.yuruicamp.backend.inventory.api.AdminInventoryLocationUpdateRequest;
import com.yuruicamp.backend.inventory.infrastructure.AdminInventoryLocationRepository;
import com.yuruicamp.backend.inventory.infrastructure.AdminInventoryLocationRepository.LocationRow;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 庫位主檔 CRUD：停用前檢查 on-hand／active 保留；硬刪另檢查異動引用。
 * Admin inventory location CRUD with safe deactivate／delete rules.
 */
@Service
public class AdminInventoryLocationService {

	private static final Set<String> STORE_TYPES =
			Set.of("main", "branch", "inspection", "repair", "damaged");
	private static final Set<String> RENTAL_TYPES =
			Set.of("main", "campground", "inspection", "repair", "damaged");

	private final AdminInventoryLocationRepository repository;

	public AdminInventoryLocationService(AdminInventoryLocationRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public List<AdminInventoryLocationResponse> list(boolean includeInactive) {
		return repository.findAll(includeInactive).stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public AdminInventoryLocationResponse get(String id) {
		LocationRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}
		return toResponse(row);
	}

	@Transactional
	public AdminInventoryLocationResponse create(AdminInventoryLocationCreateRequest request) {
		String id = requireText(request.id(), "Location id");
		String code = requireText(request.code(), "Location code");
		String domain = requireText(request.inventoryDomain(), "inventoryDomain");
		String type = requireText(request.type(), "type");
		String name = requireText(request.name(), "Location name");
		boolean active = request.active() == null || request.active();
		String branchId = normalizeOptional(request.branchId());
		validateDomainTypeBranch(domain, type, branchId);

		if (repository.findById(id) != null) {
			throw conflict("Location id already exists");
		}
		try {
			repository.insert(id, code, domain, type, branchId, name, active, Instant.now());
			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Location id or code already exists, or branch/domain rules violated");
		}
	}

	@Transactional
	public AdminInventoryLocationResponse update(String id, AdminInventoryLocationUpdateRequest request) {
		LocationRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		String name = request.name() == null
				? existing.name()
				: requireText(request.name(), "Location name");
		boolean active = request.active() == null ? existing.active() : request.active();

		// 從啟用改停用時檢查庫存／保留
		if (existing.active() && !active) {
			assertCanDeactivate(id);
		}

		repository.update(id, name, active, Instant.now());
		return get(id);
	}

	@Transactional
	public void delete(String id) {
		LocationRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		assertCanDeactivate(id);
		if (repository.countMovementReferences(id) > 0) {
			throw conflict("Location is referenced by inventory movements; set active=false instead");
		}
		try {
			repository.delete(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Location is still referenced and cannot be deleted");
		}
	}

	private void assertCanDeactivate(String locationId) {
		if (repository.sumStoreOnHand(locationId) > 0 || repository.sumRentalOnHand(locationId) > 0) {
			throw conflict("Location still has on-hand stock; transfer or write-off before deactivating");
		}
		if (repository.countActiveProductReservations(locationId) > 0
				|| repository.countActiveRentalReservations(locationId) > 0) {
			throw conflict("Location has active stock reservations and cannot be deactivated");
		}
	}

	private void validateDomainTypeBranch(String domain, String type, String branchId) {
		if (!"store".equals(domain) && !"rental".equals(domain)) {
			throw validation("inventoryDomain must be store or rental");
		}
		Set<String> allowed = "store".equals(domain) ? STORE_TYPES : RENTAL_TYPES;
		if (!allowed.contains(type)) {
			throw validation("type is not allowed for inventoryDomain=" + domain);
		}
		if ("branch".equals(type)) {
			if (!"store".equals(domain)) {
				throw validation("branch type is only allowed for store domain");
			}
			if (branchId == null || branchId.isBlank()) {
				throw validation("branchId is required when type=branch");
			}
			if (!repository.branchExists(branchId)) {
				throw new BusinessException(ErrorCode.NOT_FOUND, "Branch not found");
			}
		}
		else if (branchId != null) {
			throw validation("branchId must be null when type is not branch");
		}
	}

	private String requireText(String value, String label) {
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

	private AdminInventoryLocationResponse toResponse(LocationRow row) {
		return new AdminInventoryLocationResponse(
				row.id(),
				row.code(),
				row.inventoryDomain(),
				row.type(),
				row.branchId(),
				row.name(),
				row.active(),
				row.createdAt(),
				row.updatedAt());
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Inventory location not found");
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
