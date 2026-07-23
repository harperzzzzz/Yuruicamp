package com.yuruicamp.backend.inventory.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.inventory.api.AdminInventoryMovementCreateRequest;
import com.yuruicamp.backend.inventory.api.AdminInventoryMovementItemRequest;
import com.yuruicamp.backend.inventory.api.AdminInventoryMovementLookupResponse;
import com.yuruicamp.backend.inventory.api.AdminInventoryMovementResponse;
import com.yuruicamp.backend.inventory.infrastructure.AdminInventoryMovementRepository;
import com.yuruicamp.backend.inventory.infrastructure.AdminInventoryMovementRepository.LocationRecord;
import com.yuruicamp.backend.inventory.infrastructure.AdminInventoryMovementRepository.MovementState;
import com.yuruicamp.backend.inventory.infrastructure.AdminInventoryMovementRepository.VariantSnapshot;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台庫存異動用例，所有正式庫存寫入只能在過帳交易內發生。
 */
@Service
public class AdminInventoryMovementService {

	private static final Set<String> DOMAINS = Set.of("", "store", "rental");
	private static final Set<String> STATUSES = Set.of("", "draft", "posted", "cancelled");
	private static final Set<String> MOVEMENT_TYPES = Set.of("", "receipt", "write_off", "transfer");
	private static final Set<String> SORT_DIRECTIONS = Set.of("asc", "desc");
	private static final Map<String, String> SORT_COLUMNS = Map.of(
			"occurredAt", "movement.occurred_at",
			"createdAt", "movement.created_at",
			"updatedAt", "movement.updated_at",
			"movementNo", "movement.movement_no");

	private final AdminInventoryMovementRepository repository;

	public AdminInventoryMovementService(AdminInventoryMovementRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public PagedMovements list(
			int page,
			int size,
			String query,
			String inventoryDomain,
			String status,
			String movementType,
			String sort) {
		String normalizedDomain = normalize(inventoryDomain);
		String normalizedStatus = normalize(status);
		String normalizedType = normalize(movementType);
		SortSpec sortSpec = validateListParameters(
				page,
				size,
				normalizedDomain,
				normalizedStatus,
				normalizedType,
				sort);
		var idPage = repository.findIds(
				page,
				size,
				normalize(query),
				normalizedDomain,
				normalizedStatus,
				normalizedType,
				sortSpec.column(),
				sortSpec.direction());
		int totalPages = (int) Math.ceil((double) idPage.totalElements() / size);

		return new PagedMovements(
				repository.findByIds(idPage.ids()),
				new PageMeta(page, size, idPage.totalElements(), totalPages));
	}

	@Transactional(readOnly = true)
	public AdminInventoryMovementResponse get(long id) {
		List<AdminInventoryMovementResponse> movements = repository.findByIds(List.of(id));
		if (movements.isEmpty()) {
			throw notFound();
		}

		return movements.getFirst();
	}

	@Transactional(readOnly = true)
	public AdminInventoryMovementLookupResponse getLookups() {
		return repository.findLookups();
	}

	@Transactional
	public AdminInventoryMovementResponse createDraft(
			String actorId,
			AdminInventoryMovementCreateRequest request) {
		String sourceLocationId = normalizeNullable(request.sourceLocationId());
		String destinationLocationId = normalizeNullable(request.destinationLocationId());
		validateLocationPayload(
				request.inventoryDomain(),
				request.movementType(),
				sourceLocationId,
				destinationLocationId);
		Instant now = Instant.now();
		Instant occurredAt = request.occurredAt() == null ? now : request.occurredAt();
		if (occurredAt.isAfter(now.plusSeconds(300))) {
			throw validation("Movement occurredAt cannot be in the future");
		}
		long id = repository.insertMovement(
				generateMovementNo(now),
				request.inventoryDomain(),
				request.movementType(),
				sourceLocationId,
				destinationLocationId,
				actorId,
				request.reason().trim(),
				occurredAt,
				now);

		return get(id);
	}

	@Transactional
	public AdminInventoryMovementResponse addItem(
			long id,
			AdminInventoryMovementItemRequest request) {
		MovementState movement = requireLockedMovement(id);
		requireNotConversion(movement, "Conversion movement items must be managed via /api/admin/inventory-conversions");
		requireDraft(movement, "Only draft movement can add items");
		String variantId = request.variantId().trim();
		VariantSnapshot variant = repository.findVariant(movement.inventoryDomain(), variantId);
		if (variant == null) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Inventory variant not found");
		}
		if (!"active".equals(variant.status())) {
			throw conflict("Inactive inventory variant cannot be added to a new movement");
		}
		if (repository.movementContainsVariant(id, movement.inventoryDomain(), variantId)) {
			throw conflict("Movement already contains this variant");
		}
		repository.insertItem(id, movement.inventoryDomain(), variant, request.quantity());

		return get(id);
	}

	@Transactional
	public AdminInventoryMovementResponse post(long id, String actorId) {
		MovementState movement = requireLockedMovement(id);
		requireNotConversion(movement, "Conversion movement must be posted via /api/admin/inventory-conversions");
		if ("posted".equals(movement.status())) {
			return get(id);
		}
		if ("cancelled".equals(movement.status())) {
			throw conflict("Cancelled movement cannot be posted");
		}
		var items = repository.findItems(id);
		if (items.isEmpty()) {
			throw conflict("Movement must contain at least one item before posting");
		}
		Instant now = Instant.now();
		List<StockKey> lockOrder = buildLockOrder(movement, items);
		Map<StockKey, Integer> quantities = new LinkedHashMap<>();
		for (StockKey key : lockOrder) {
			int quantity = repository.ensureAndLockStock(
					movement.inventoryDomain(),
					key.locationId(),
					key.variantId(),
					now);
			quantities.put(key, quantity);
		}

		for (var item : items) {
			if (movement.sourceLocationId() != null) {
				StockKey sourceKey = new StockKey(movement.sourceLocationId(), item.variantId());
				int current = quantities.get(sourceKey);
				int reserved = repository.findActiveReservedQuantity(
						movement.inventoryDomain(),
						sourceKey.locationId(),
						sourceKey.variantId());
				int next = current - item.quantity();
				if (next < 0 || next < reserved) {
					throw conflict("Insufficient unreserved inventory for SKU: " + item.sku());
				}
				quantities.put(sourceKey, next);
			}
			if (movement.destinationLocationId() != null) {
				StockKey destinationKey = new StockKey(movement.destinationLocationId(), item.variantId());
				quantities.put(destinationKey, quantities.get(destinationKey) + item.quantity());
			}
		}

		for (Map.Entry<StockKey, Integer> entry : quantities.entrySet()) {
			repository.updateStock(
					movement.inventoryDomain(),
					entry.getKey().locationId(),
					entry.getKey().variantId(),
					entry.getValue(),
					now);
		}
		repository.markPosted(id, actorId, now);

		return get(id);
	}

	@Transactional
	public AdminInventoryMovementResponse cancel(long id, String actorId) {
		MovementState movement = requireLockedMovement(id);
		requireNotConversion(movement, "Conversion movement must be cancelled via /api/admin/inventory-conversions");
		if ("cancelled".equals(movement.status())) {
			return get(id);
		}
		if ("posted".equals(movement.status())) {
			throw conflict("Posted movement cannot be cancelled");
		}
		repository.markCancelled(id, actorId, Instant.now());

		return get(id);
	}

	private void validateLocationPayload(
			String inventoryDomain,
			String movementType,
			String sourceLocationId,
			String destinationLocationId) {
		if ("receipt".equals(movementType)) {
			if (sourceLocationId != null || destinationLocationId == null) {
				throw validation("Receipt requires destinationLocationId only");
			}
		} else if ("write_off".equals(movementType)) {
			if (sourceLocationId == null || destinationLocationId != null) {
				throw validation("Write-off requires sourceLocationId only");
			}
		} else if ("transfer".equals(movementType)) {
			if (sourceLocationId == null
					|| destinationLocationId == null
					|| sourceLocationId.equals(destinationLocationId)) {
				throw validation("Transfer requires different source and destination locations");
			}
		}
		validateLocation(inventoryDomain, sourceLocationId);
		validateLocation(inventoryDomain, destinationLocationId);
	}

	private void validateLocation(String inventoryDomain, String locationId) {
		if (locationId == null) {
			return;
		}
		LocationRecord location = repository.findActiveLocation(locationId);
		if (location == null || !location.active()) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Active inventory location not found");
		}
		if (!inventoryDomain.equals(location.inventoryDomain())) {
			throw validation("Inventory location domain does not match movement domain");
		}
	}

	private List<StockKey> buildLockOrder(
			MovementState movement,
			List<com.yuruicamp.backend.inventory.api.AdminInventoryMovementItemResponse> items) {
		Set<StockKey> keys = new LinkedHashSet<>();
		for (var item : items) {
			if (movement.sourceLocationId() != null) {
				keys.add(new StockKey(movement.sourceLocationId(), item.variantId()));
			}
			if (movement.destinationLocationId() != null) {
				keys.add(new StockKey(movement.destinationLocationId(), item.variantId()));
			}
		}
		List<StockKey> sorted = new ArrayList<>(keys);
		sorted.sort(Comparator
				.comparing(StockKey::variantId)
				.thenComparing(StockKey::locationId));

		return sorted;
	}

	private SortSpec validateListParameters(
			int page,
			int size,
			String inventoryDomain,
			String status,
			String movementType,
			String sort) {
		if (page < 0
				|| size < 1
				|| size > 100
				|| !DOMAINS.contains(inventoryDomain)
				|| !STATUSES.contains(status)
				|| !MOVEMENT_TYPES.contains(movementType)) {
			throw validation("Invalid inventory movement list parameters");
		}
		String[] parts = sort.split(",", -1);
		if (parts.length != 2
				|| !SORT_COLUMNS.containsKey(parts[0])
				|| !SORT_DIRECTIONS.contains(parts[1].toLowerCase(Locale.ROOT))) {
			throw validation("Invalid inventory movement sort");
		}

		return new SortSpec(
				SORT_COLUMNS.get(parts[0]),
				parts[1].toUpperCase(Locale.ROOT));
	}

	private MovementState requireLockedMovement(long id) {
		MovementState movement = repository.lockMovement(id);
		if (movement == null) {
			throw notFound();
		}

		return movement;
	}

	private void requireDraft(MovementState movement, String message) {
		if (!"draft".equals(movement.status())) {
			throw conflict(message);
		}
	}

	// ADM-W2-05：conversion_out／conversion_in 一律成對處理，禁止透過本通用端點單邊
	// 新增明細／過帳／作廢，避免產生「單邊假轉換」（商城扣了但租借沒加，或反之）。
	private void requireNotConversion(MovementState movement, String message) {
		if ("conversion_out".equals(movement.movementType()) || "conversion_in".equals(movement.movementType())) {
			throw conflict(message);
		}
	}

	private String generateMovementNo(Instant now) {
		String date = java.time.format.DateTimeFormatter.BASIC_ISO_DATE
				.withZone(java.time.ZoneId.of("Asia/Taipei"))
				.format(now);
		String random = UUID.randomUUID()
				.toString()
				.replace("-", "")
				.substring(0, 10)
				.toUpperCase(Locale.ROOT);

		return "MOV-" + date + "-" + random;
	}

	private String normalize(String value) {
		return value == null ? "" : value.trim();
	}

	private String normalizeNullable(String value) {
		String normalized = normalize(value);

		return normalized.isBlank() ? null : normalized;
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Inventory movement not found");
	}

	public record PagedMovements(List<AdminInventoryMovementResponse> data, PageMeta meta) {
	}

	private record SortSpec(String column, String direction) {
	}

	private record StockKey(String locationId, String variantId) {
	}
}
