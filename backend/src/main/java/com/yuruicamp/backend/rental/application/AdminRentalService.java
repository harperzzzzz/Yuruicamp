package com.yuruicamp.backend.rental.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import com.yuruicamp.backend.catalog.infrastructure.AdminBrandRepository;
import com.yuruicamp.backend.catalog.infrastructure.AdminBrandRepository.BrandRow;
import com.yuruicamp.backend.catalog.infrastructure.AdminCategoryRepository;
import com.yuruicamp.backend.catalog.infrastructure.AdminCategoryRepository.CategoryRow;
import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.rental.api.AdminRentalResponse;
import com.yuruicamp.backend.rental.api.AdminRentalUpsertRequest;
import com.yuruicamp.backend.rental.api.AdminRentalVariantRequest;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalReadRepository;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalRepository;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalRepository.RentalSkuRow;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalRepository.VariantRow;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台租借 SKU 用例：在單一交易內同步 equipment_items → rental_skus →
 * rental_sku_variants（W2-03）。
 *
 * <p>寫法對齊 {@code AdminProductService}，差異只在：(1) 用 JDBC 而不是 JPA，
 * (2) 沒有 price／images／stock，(3) 建立時一律新建 equipment_item（不重用既有 itemId）。
 * 這支 Service **永遠不寫**任何庫存欄位，庫存只能靠 G-3 的庫存異動 API 改。</p>
 */
@Service
public class AdminRentalService {

	private static final Set<String> STATUS_VALUES = Set.of("", "active", "inactive");
	private static final Set<String> SORT_DIRECTIONS = Set.of("asc", "desc");

	private final AdminRentalRepository repository;
	private final AdminRentalReadRepository readRepository;
	private final AdminCategoryRepository categoryRepository;
	private final AdminBrandRepository brandRepository;

	public AdminRentalService(
			AdminRentalRepository repository,
			AdminRentalReadRepository readRepository,
			AdminCategoryRepository categoryRepository,
			AdminBrandRepository brandRepository) {
		this.repository = repository;
		this.readRepository = readRepository;
		this.categoryRepository = categoryRepository;
		this.brandRepository = brandRepository;
	}

	@Transactional(readOnly = true)
	public PagedRentals list(
			int page,
			int size,
			String query,
			String status,
			Long categoryId,
			String brandId,
			String sort) {
		String normalizedStatus = normalize(status);
		SortSpec sortSpec = validateListParameters(page, size, normalizedStatus, sort);
		var idPage = readRepository.findIds(
				page,
				size,
				normalize(query),
				normalizedStatus,
				categoryId,
				normalize(brandId),
				sortSpec.field(),
				sortSpec.direction());
		List<AdminRentalResponse> data = readRepository.findRentals(idPage.ids());
		int totalPages = (int) Math.ceil((double) idPage.totalElements() / size);

		return new PagedRentals(data, new PageMeta(page, size, idPage.totalElements(), totalPages));
	}

	@Transactional(readOnly = true)
	public AdminRentalResponse get(String id) {
		List<AdminRentalResponse> rentals = readRepository.findRentals(List.of(id));
		if (rentals.isEmpty()) {
			throw notFound();
		}

		return rentals.getFirst();
	}

	@Transactional
	public AdminRentalResponse create(AdminRentalUpsertRequest request) {
		validateRequest(request, null);
		CategoryRow category = findCategory(request.categoryId());
		BrandRow brand = findBrand(request.brandId());
		Instant now = Instant.now();

		String itemId = generateId("E", 32);
		repository.insertEquipmentItem(
				itemId,
				category.id(),
				brand == null ? null : brand.id(),
				request.name().trim(),
				normalizeNullable(request.description()),
				true,
				now);

		String rentalSkuId = generateId("RS", 32);
		repository.insertRentalSku(rentalSkuId, itemId, request.status(), now);

		syncVariants(rentalSkuId, request.variants(), now);

		return get(rentalSkuId);
	}

	@Transactional
	public AdminRentalResponse update(String id, AdminRentalUpsertRequest request) {
		RentalSkuRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		validateRequest(request, id);
		CategoryRow category = findCategory(request.categoryId());
		BrandRow brand = findBrand(request.brandId());
		Instant now = Instant.now();

		repository.updateEquipmentItem(
				existing.itemId(),
				category.id(),
				brand == null ? null : brand.id(),
				request.name().trim(),
				normalizeNullable(request.description()),
				now);
		repository.updateRentalSkuStatus(id, request.status(), now);

		syncVariants(id, request.variants(), now);

		return get(id);
	}

	@Transactional
	public AdminRentalResponse activate(String id) {
		return changeStatus(id, "active");
	}

	@Transactional
	public AdminRentalResponse deactivate(String id) {
		return changeStatus(id, "inactive");
	}

	private AdminRentalResponse changeStatus(String id, String status) {
		RentalSkuRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		if ("active".equals(status) && repository.countActiveVariants(id) == 0) {
			throw conflict("Active rental SKU must have at least one active variant");
		}
		if (!status.equals(existing.status())) {
			repository.updateRentalSkuStatus(id, status, Instant.now());
		}

		return get(id);
	}

	/**
	 * 同步規格清單：既有 id → 更新內容；沒有 id → 新增；DB 有但 Request 沒送出 → 改 inactive（不硬刪）。
	 * Sync variants: existing id → update; missing id → insert; not-sent-but-existing → inactive.
	 */
	private void syncVariants(String rentalSkuId, List<AdminRentalVariantRequest> requests, Instant now) {
		List<VariantRow> existing = repository.findVariantsByRentalSkuId(rentalSkuId);
		Map<String, VariantRow> existingById = new HashMap<>();
		existing.forEach(variant -> existingById.put(variant.id(), variant));
		Set<String> retainedIds = new HashSet<>();

		try {
			for (AdminRentalVariantRequest request : requests) {
				String requestId = normalizeNullable(request.id());
				String sku = request.sku().trim();
				String color = normalizeNullable(request.color());
				String size = normalizeNullable(request.size());
				String specification = request.specification().trim();

				if (requestId == null) {
					validateSkuAvailability(sku, null);
					String newId = generateId("RSV", 64);
					repository.insertVariant(newId, rentalSkuId, sku, color, size, specification, request.status(), now);
					retainedIds.add(newId);
					continue;
				}

				VariantRow variant = existingById.get(requestId);
				if (variant == null) {
					throw new BusinessException(
							ErrorCode.CONFLICT,
							"Variant does not belong to rental SKU: " + requestId);
				}
				validateSkuAvailability(sku, requestId);
				repository.updateVariant(requestId, sku, color, size, specification, request.status(), now);
				retainedIds.add(requestId);
			}

			for (VariantRow variant : existing) {
				if (!retainedIds.contains(variant.id()) && !"inactive".equals(variant.status())) {
					repository.updateVariantStatus(variant.id(), "inactive", now);
				}
			}
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("SKU already exists or rental SKU variant combination already exists");
		}
	}

	private void validateRequest(AdminRentalUpsertRequest request, String rentalSkuId) {
		Set<String> skuValues = new HashSet<>();
		Set<String> specificationValues = new HashSet<>();
		long activeVariants = 0;
		for (AdminRentalVariantRequest variant : request.variants()) {
			String sku = variant.sku().trim();
			if (!skuValues.add(sku)) {
				throw conflict("Duplicate SKU in request: " + sku);
			}
			String combination = normalize(variant.color()) + "\u0000"
					+ normalize(variant.size()) + "\u0000" + variant.specification().trim();
			if (!specificationValues.add(combination)) {
				throw conflict("Duplicate rental SKU variant specification");
			}
			if ("active".equals(variant.status())) {
				activeVariants++;
			}
		}
		if ("active".equals(request.status()) && activeVariants == 0) {
			throw conflict("Active rental SKU must have at least one active variant");
		}
	}

	private void validateSkuAvailability(String sku, String variantId) {
		boolean exists = variantId == null
				? repository.existsBySku(sku)
				: repository.existsBySkuAndIdNot(sku, variantId);
		if (exists) {
			throw conflict("SKU already exists: " + sku);
		}
	}

	private SortSpec validateListParameters(int page, int size, String status, String sort) {
		if (page < 0 || size < 1 || size > 100 || !STATUS_VALUES.contains(status)) {
			throw validation("Invalid rental list parameters");
		}
		String[] parts = sort.split(",", -1);
		if (parts.length != 2
				|| AdminRentalReadRepository.resolveSortColumn(parts[0]) == null
				|| !SORT_DIRECTIONS.contains(parts[1].toLowerCase(Locale.ROOT))) {
			throw validation("Invalid rental sort");
		}

		return new SortSpec(parts[0], parts[1].toUpperCase(Locale.ROOT));
	}

	private CategoryRow findCategory(Long categoryId) {
		CategoryRow category = categoryRepository.findById(categoryId);
		if (category == null) {
			throw notFound("Product category not found");
		}

		return category;
	}

	private BrandRow findBrand(String brandId) {
		String normalized = normalize(brandId);
		if (normalized.isBlank()) {
			return null;
		}
		BrandRow brand = brandRepository.findById(normalized);
		if (brand == null) {
			throw notFound("Brand not found");
		}

		return brand;
	}

	private String generateId(String prefix, int totalLength) {
		String random = UUID.randomUUID().toString().replace("-", "");
		int remaining = Math.min(random.length(), totalLength - prefix.length());

		return prefix + random.substring(0, remaining);
	}

	private String normalize(String value) {
		return value == null ? "" : value.trim();
	}

	private String normalizeNullable(String value) {
		String normalized = normalize(value);

		return normalized.isBlank() ? null : normalized;
	}

	private BusinessException notFound() {
		return notFound("Rental SKU not found");
	}

	private BusinessException notFound(String message) {
		return new BusinessException(ErrorCode.NOT_FOUND, message);
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}

	public record PagedRentals(List<AdminRentalResponse> data, PageMeta meta) {
	}

	private record SortSpec(String field, String direction) {
	}
}
