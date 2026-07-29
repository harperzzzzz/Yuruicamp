package com.yuruicamp.backend.inventory.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.inventory.api.AdminMinStockItemRequest;
import com.yuruicamp.backend.inventory.api.AdminMinStockResponse;
import com.yuruicamp.backend.inventory.api.AdminMinStockUpsertRequest;
import com.yuruicamp.backend.inventory.infrastructure.AdminMinStockRepository;
import com.yuruicamp.backend.inventory.infrastructure.AdminMinStockRepository.LocationRow;
import com.yuruicamp.backend.inventory.infrastructure.AdminMinStockRepository.MinStockRow;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台最低庫存閾值：只 upsert 閾值表，絕不改 on_hand。
 * Admin min-stock use-cases: threshold tables only, never on_hand.
 */
@Service
public class AdminMinStockService {

	private final AdminMinStockRepository repository;

	public AdminMinStockService(AdminMinStockRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public List<AdminMinStockResponse> list(
			String inventoryDomain,
			String variantId,
			String locationId,
			String productId) {
		String domain = requireDomain(inventoryDomain);
		List<MinStockRow> rows = "store".equals(domain)
				? repository.findStore(blankToNull(variantId), blankToNull(locationId), blankToNull(productId))
				: repository.findRental(blankToNull(variantId), blankToNull(locationId), blankToNull(productId));
		return rows.stream().map(this::toResponse).toList();
	}

	@Transactional
	public List<AdminMinStockResponse> upsert(AdminMinStockUpsertRequest request) {
		String domain = requireDomain(request.inventoryDomain());
		List<AdminMinStockItemRequest> items = request.items();
		if (items == null || items.isEmpty()) {
			throw validation("Min-stock items must not be empty");
		}

		// 同一請求內不可重複 (variantId, locationId)
		// Reject duplicate keys inside one bulk request
		Set<String> seen = new HashSet<>();
		for (AdminMinStockItemRequest item : items) {
			String variantId = requireText(item.variantId(), "variantId");
			String locationId = requireText(item.locationId(), "locationId");
			if (item.minimumQuantity() == null || item.minimumQuantity() < 0) {
				throw validation("minimumQuantity must be >= 0");
			}
			String key = variantId + "\0" + locationId;
			if (!seen.add(key)) {
				throw validation("Duplicate variantId and locationId in request");
			}
			validateVariant(domain, variantId);
			validateLocation(domain, locationId);
		}

		Instant now = Instant.now();
		List<AdminMinStockResponse> results = new ArrayList<>();
		for (AdminMinStockItemRequest item : items) {
			String variantId = item.variantId().trim();
			String locationId = item.locationId().trim();
			int qty = item.minimumQuantity();
			if ("store".equals(domain)) {
				repository.upsertStore(variantId, locationId, qty, now);
				results.add(toResponse(repository.findStoreOne(variantId, locationId)));
			}
			else {
				repository.upsertRental(variantId, locationId, qty, now);
				results.add(toResponse(repository.findRentalOne(variantId, locationId)));
			}
		}
		return results;
	}

	private void validateVariant(String domain, String variantId) {
		boolean exists = "store".equals(domain)
				? repository.storeVariantExists(variantId)
				: repository.rentalVariantExists(variantId);
		if (!exists) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Inventory variant not found");
		}
	}

	private void validateLocation(String domain, String locationId) {
		LocationRow location = repository.findActiveLocation(locationId);
		if (location == null || !location.active()) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Active inventory location not found");
		}
		if (!domain.equals(location.inventoryDomain())) {
			throw validation("Inventory location domain does not match request domain");
		}
	}

	private String requireDomain(String inventoryDomain) {
		String domain = inventoryDomain == null ? "" : inventoryDomain.trim();
		if (!"store".equals(domain) && !"rental".equals(domain)) {
			throw validation("inventoryDomain must be store or rental");
		}
		return domain;
	}

	private String requireText(String value, String field) {
		if (value == null || value.isBlank()) {
			throw validation(field + " must not be blank");
		}
		return value.trim();
	}

	private String blankToNull(String value) {
		return value == null || value.isBlank() ? null : value.trim();
	}

	private AdminMinStockResponse toResponse(MinStockRow row) {
		return new AdminMinStockResponse(
				row.inventoryDomain(),
				row.variantId(),
				row.productId(),
				row.locationId(),
				row.minimumQuantity(),
				row.updatedAt());
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
