package com.yuruicamp.backend.coupon.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.coupon.api.AdminCouponCreateRequest;
import com.yuruicamp.backend.coupon.api.AdminCouponResponse;
import com.yuruicamp.backend.coupon.api.AdminCouponUpdateRequest;
import com.yuruicamp.backend.coupon.infrastructure.AdminCouponRepository;
import com.yuruicamp.backend.coupon.infrastructure.AdminCouponRepository.CouponRow;
import com.yuruicamp.backend.coupon.infrastructure.AdminCouponRepository.CouponWrite;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台優惠券管理用例，主檔更新會鎖定優惠券並保護既有領券名額。
 */
@Service
public class AdminCouponService {

	private static final Set<String> STATUSES = Set.of("", "active", "disabled");
	private static final Set<String> CATEGORIES = Set.of("", "promotion", "birthday", "firstPurchase");
	private static final Set<String> SORT_DIRECTIONS = Set.of("asc", "desc");
	private static final Map<String, String> SORT_COLUMNS = Map.of(
			"createdAt", "created_at",
			"updatedAt", "updated_at",
			"validFrom", "valid_from",
			"validUntil", "valid_until",
			"code", "code");

	private final AdminCouponRepository repository;

	public AdminCouponService(AdminCouponRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public PagedCoupons list(
			int page,
			int size,
			String query,
			String status,
			String category,
			String sort) {
		String normalizedStatus = normalize(status);
		String normalizedCategory = normalize(category);
		SortSpec sortSpec = validateList(page, size, normalizedStatus, normalizedCategory, sort);
		var idPage = repository.findIds(
				page,
				size,
				normalize(query),
				normalizedStatus,
				normalizedCategory,
				sortSpec.column(),
				sortSpec.direction());
		int totalPages = (int) Math.ceil((double) idPage.totalElements() / size);
		List<AdminCouponResponse> data = repository.findByIds(idPage.ids())
				.stream()
				.map(this::toResponse)
				.toList();

		return new PagedCoupons(data, new PageMeta(page, size, idPage.totalElements(), totalPages));
	}

	@Transactional(readOnly = true)
	public AdminCouponResponse get(long id) {
		CouponRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}

		return toResponse(row);
	}

	@Transactional
	public AdminCouponResponse create(AdminCouponCreateRequest request) {
		String code = request.code().trim().toUpperCase(Locale.ROOT);
		CouponWrite write = new CouponWrite(
				code,
				request.name().trim(),
				request.discountType(),
				request.discountValue(),
				request.minimumAmount(),
				request.issueQuantity(),
				request.validFrom(),
				request.validUntil(),
				request.status(),
				request.category());
		validate(write, 0);

		try {
			long id = repository.insert(write, Instant.now());

			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Coupon code already exists or coupon data violates database rules");
		}
	}

	@Transactional
	public AdminCouponResponse update(long id, AdminCouponUpdateRequest request) {
		CouponRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		CouponWrite write = new CouponWrite(
				existing.code(),
				request.name() == null ? existing.name() : request.name().trim(),
				request.discountType() == null ? existing.discountType() : request.discountType(),
				request.discountValue() == null ? existing.discountValue() : request.discountValue(),
				request.minimumAmount() == null ? existing.minimumAmount() : request.minimumAmount(),
				request.issueQuantity() == null ? existing.issueQuantity() : request.issueQuantity(),
				request.validFrom() == null ? existing.validFrom() : request.validFrom(),
				request.validUntil() == null ? existing.validUntil() : request.validUntil(),
				request.status() == null ? existing.status() : request.status(),
				request.category() == null ? existing.category() : request.category());
		validate(write, existing.claimedQuantity());

		try {
			repository.update(id, write, Instant.now());

			return get(id);
		}
		catch (DataIntegrityViolationException ex) {
			throw conflict("Coupon update violates database rules");
		}
	}

	@Transactional
	public void delete(long id) {
		CouponRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		if (existing.claimedQuantity() > 0 || repository.hasClaims(id)) {
			throw conflict("Claimed coupon cannot be deleted; disable it instead");
		}

		repository.delete(id);
	}

	private SortSpec validateList(
			int page,
			int size,
			String status,
			String category,
			String sort) {
		if (page < 0
				|| size < 1
				|| size > 100
				|| !STATUSES.contains(status)
				|| !CATEGORIES.contains(category)) {
			throw validation("Invalid coupon list parameters");
		}
		String[] parts = sort.split(",", -1);
		if (parts.length != 2
				|| !SORT_COLUMNS.containsKey(parts[0])
				|| !SORT_DIRECTIONS.contains(parts[1].toLowerCase(Locale.ROOT))) {
			throw validation("Invalid coupon sort");
		}

		return new SortSpec(SORT_COLUMNS.get(parts[0]), parts[1].toUpperCase(Locale.ROOT));
	}

	private void validate(CouponWrite write, int claimedQuantity) {
		if (write.code().isBlank()
				|| write.name().isBlank()
				|| write.issueQuantity() < claimedQuantity
				|| !write.validUntil().isAfter(write.validFrom())) {
			throw validation("Coupon name, quantity, or validity period is invalid");
		}
		if (write.discountValue().compareTo(BigDecimal.ZERO) <= 0
				|| write.minimumAmount().compareTo(BigDecimal.ZERO) < 0
				|| ("percent".equals(write.discountType())
						&& write.discountValue().compareTo(new BigDecimal("100")) > 0)) {
			throw validation("Coupon discount or minimum amount is invalid");
		}
	}

	private AdminCouponResponse toResponse(CouponRow row) {
		return new AdminCouponResponse(
				row.id(),
				row.code(),
				row.name(),
				row.discountType(),
				money(row.discountValue()),
				money(row.minimumAmount()),
				row.issueQuantity(),
				row.claimedQuantity(),
				Math.max(row.issueQuantity() - row.claimedQuantity(), 0),
				row.validFrom(),
				row.validUntil(),
				row.status(),
				row.category(),
				row.createdAt(),
				row.updatedAt());
	}

	private String normalize(String value) {
		return value == null ? "" : value.trim();
	}

	private String money(BigDecimal value) {
		return value.setScale(2, RoundingMode.HALF_UP).toPlainString();
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}

	private BusinessException conflict(String message) {
		return new BusinessException(ErrorCode.CONFLICT, message);
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Coupon not found");
	}

	public record PagedCoupons(List<AdminCouponResponse> data, PageMeta meta) {
	}

	private record SortSpec(String column, String direction) {
	}
}
