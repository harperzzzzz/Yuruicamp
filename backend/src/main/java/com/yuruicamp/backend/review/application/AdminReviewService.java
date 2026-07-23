package com.yuruicamp.backend.review.application;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.review.api.AdminReviewResponse;
import com.yuruicamp.backend.review.infrastructure.AdminReviewRepository;
import com.yuruicamp.backend.review.infrastructure.AdminReviewRepository.ReviewRow;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台評論查詢與硬刪（W1-06）。
 * Admin review list/detail/hard-delete use-cases.
 */
@Service
public class AdminReviewService {

	private static final Set<String> SORT_DIRECTIONS = Set.of("asc", "desc");
	private static final Map<String, String> SORT_COLUMNS = Map.of(
			"createdAt", "review.created_at",
			"rating", "review.rating");

	private final AdminReviewRepository repository;

	public AdminReviewService(AdminReviewRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public PagedReviews list(
			int page,
			int size,
			String query,
			String productId,
			Integer rating,
			Instant createdFrom,
			Instant createdTo,
			String sort) {
		SortSpec sortSpec = validateList(page, size, rating, createdFrom, createdTo, sort);
		var idPage = repository.findIds(
				page,
				size,
				normalize(query),
				normalize(productId),
				rating,
				createdFrom,
				createdTo,
				sortSpec.column(),
				sortSpec.direction());
		List<AdminReviewResponse> data = toResponses(repository.findByIds(idPage.ids()));
		int totalPages = size == 0 ? 0 : (int) Math.ceil((double) idPage.totalElements() / size);
		return new PagedReviews(data, new PageMeta(page, size, idPage.totalElements(), totalPages));
	}

	@Transactional(readOnly = true)
	public AdminReviewResponse get(String id) {
		ReviewRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}
		return toResponses(List.of(row)).getFirst();
	}

	@Transactional
	public void delete(String id) {
		if (!repository.exists(id)) {
			throw notFound();
		}
		repository.delete(id);
	}

	private List<AdminReviewResponse> toResponses(List<ReviewRow> rows) {
		List<String> ids = rows.stream().map(ReviewRow::id).toList();
		Map<String, List<String>> photos = repository.findPhotos(ids);
		return rows.stream()
				.map(row -> new AdminReviewResponse(
						row.id(),
						row.orderItemId(),
						row.orderId(),
						row.customerId(),
						row.productId(),
						row.variantId(),
						row.sku(),
						row.productName(),
						row.buyerName(),
						row.buyerAvatar(),
						row.rating(),
						row.comment(),
						photos.getOrDefault(row.id(), List.of()),
						true,
						row.createdAt()))
				.toList();
	}

	private SortSpec validateList(
			int page,
			int size,
			Integer rating,
			Instant createdFrom,
			Instant createdTo,
			String sort) {
		if (page < 0 || size < 1 || size > 100) {
			throw validation("Invalid review pagination");
		}
		if (rating != null && (rating < 1 || rating > 5)) {
			throw validation("rating must be between 1 and 5");
		}
		if (createdFrom != null && createdTo != null && createdTo.isBefore(createdFrom)) {
			throw validation("createdTo must be >= createdFrom");
		}
		String[] parts = (sort == null ? "createdAt,desc" : sort).split(",", -1);
		if (parts.length != 2
				|| !SORT_COLUMNS.containsKey(parts[0])
				|| !SORT_DIRECTIONS.contains(parts[1].toLowerCase(Locale.ROOT))) {
			throw validation("Invalid review sort");
		}
		return new SortSpec(SORT_COLUMNS.get(parts[0]), parts[1].toUpperCase(Locale.ROOT));
	}

	private String normalize(String value) {
		return value == null ? "" : value.trim();
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Review not found");
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}

	public record PagedReviews(List<AdminReviewResponse> data, PageMeta meta) {
	}

	private record SortSpec(String column, String direction) {
	}
}
