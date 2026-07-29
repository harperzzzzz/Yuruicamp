package com.yuruicamp.backend.rental.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.rental.api.AdminRentalListingRequest;
import com.yuruicamp.backend.rental.api.AdminRentalListingResponse;
import com.yuruicamp.backend.rental.api.AdminRentalListingSyncRequest;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalListingRepository;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalListingRepository.ListingRow;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalRepository;
import com.yuruicamp.backend.rental.infrastructure.AdminRentalRepository.VariantRow;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台租借上架（{@code rental_listings}）用例（W2-04）。
 * Admin rental listing use-cases: campground pricing/upsell for a rental SKU.
 *
 * <p><b>範圍界線（新手必讀）</b>：這支 Service 只管「一個租借規格在某個營區賣多少錢、
 * 有沒有上架」，<b>完全不碰庫存數字</b>——庫存永遠只能用 G-3
 * {@code /api/admin/inventory-movements} 改，這裡的價格／上下架跟數量無關。</p>
 */
@Service
public class AdminRentalListingService {

	private final AdminRentalRepository rentalRepository;
	private final AdminRentalListingRepository listingRepository;

	public AdminRentalListingService(
			AdminRentalRepository rentalRepository,
			AdminRentalListingRepository listingRepository) {
		this.rentalRepository = rentalRepository;
		this.listingRepository = listingRepository;
	}

	@Transactional(readOnly = true)
	public List<AdminRentalListingResponse> list(String rentalSkuId) {
		requireRentalSku(rentalSkuId);
		List<String> variantIds = variantIdsOf(rentalSkuId);
		return listingRepository.findListingsForVariants(variantIds).stream()
				.map(this::toResponse)
				.toList();
	}

	/**
	 * 整組取代（sync）：body 出現的組合 upsert，既有但沒出現的組合改成 {@code active=false}。
	 * 語意與檔頭註解、契約文件一致；不做硬刪（listing 曾被訂過就刪不掉）。
	 */
	@Transactional
	public List<AdminRentalListingResponse> replace(String rentalSkuId, AdminRentalListingSyncRequest request) {
		if (rentalRepository.lockById(rentalSkuId) == null) {
			throw notFoundRentalSku();
		}
		List<VariantRow> variants = rentalRepository.findVariantsByRentalSkuId(rentalSkuId);
		Set<String> variantIds = new HashSet<>();
		variants.forEach(variant -> variantIds.add(variant.id()));

		List<AdminRentalListingRequest> items = request.listings() == null ? List.of() : request.listings();
		Set<String> keepKeys = new HashSet<>();
		Instant now = Instant.now();

		for (AdminRentalListingRequest item : items) {
			String campgroundId = requireText(item.campgroundId(), "campgroundId");
			String variantId = requireText(item.rentalSkuVariantId(), "rentalSkuVariantId");
			if (!variantIds.contains(variantId)) {
				throw new BusinessException(
						ErrorCode.NOT_FOUND,
						"Rental SKU variant does not belong to this rental SKU: " + variantId);
			}
			if (!listingRepository.campgroundRentalLocationExists(campgroundId)) {
				throw new BusinessException(
						ErrorCode.NOT_FOUND,
						"Campground rental location not found: " + campgroundId);
			}
			String key = combinationKey(campgroundId, variantId);
			if (!keepKeys.add(key)) {
				throw validation("Duplicate campgroundId + rentalSkuVariantId in request: " + key);
			}

			BigDecimal discount = item.discount() == null ? new BigDecimal("0.00") : item.discount();
			listingRepository.upsertListing(
					generateId("RL", 64),
					campgroundId,
					variantId,
					item.pricePerDayWeekday(),
					item.pricePerDayHoliday(),
					discount,
					normalizeNullable(item.terrain()),
					normalizeNullable(item.description()),
					item.active(),
					now);
		}

		// 沒出現在這次 request、但這個 SKU 底下還存在的 listing → 軟停用（不硬刪）。
		List<ListingRow> existing = listingRepository.findListingsForVariants(new ArrayList<>(variantIds));
		for (ListingRow row : existing) {
			String key = combinationKey(row.campgroundId(), row.rentalSkuVariantId());
			if (!keepKeys.contains(key) && row.active()) {
				listingRepository.deactivate(row.id(), now);
			}
		}

		return list(rentalSkuId);
	}

	private List<String> variantIdsOf(String rentalSkuId) {
		List<VariantRow> variants = rentalRepository.findVariantsByRentalSkuId(rentalSkuId);
		List<String> ids = new ArrayList<>();
		variants.forEach(variant -> ids.add(variant.id()));
		return ids;
	}

	private void requireRentalSku(String rentalSkuId) {
		if (rentalRepository.findById(rentalSkuId) == null) {
			throw notFoundRentalSku();
		}
	}

	private String combinationKey(String campgroundId, String variantId) {
		return campgroundId + "\u0000" + variantId;
	}

	private AdminRentalListingResponse toResponse(ListingRow row) {
		return new AdminRentalListingResponse(
				row.id(), row.campgroundId(), row.campgroundName(),
				row.rentalSkuVariantId(), row.sku(), row.specification(),
				money(row.pricePerDayWeekday()), money(row.pricePerDayHoliday()), money(row.discount()),
				row.terrain(), row.description(), row.active(),
				row.createdAt(), row.updatedAt());
	}

	// 金額固定格式化成兩位小數的字串，跟公開契約（RentalEquipmentResponse）慣例一致。
	private String money(BigDecimal value) {
		return value.setScale(2, RoundingMode.HALF_UP).toPlainString();
	}

	private String generateId(String prefix, int totalLength) {
		String random = UUID.randomUUID().toString().replace("-", "");
		int remaining = Math.min(random.length(), totalLength - prefix.length());
		return prefix + random.substring(0, remaining);
	}

	private String requireText(String value, String field) {
		if (value == null || value.isBlank()) {
			throw validation(field + " must not be blank");
		}
		return value.trim();
	}

	private String normalizeNullable(String value) {
		if (value == null || value.isBlank()) {
			return null;
		}
		return value.trim();
	}

	private BusinessException notFoundRentalSku() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Rental SKU not found");
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
