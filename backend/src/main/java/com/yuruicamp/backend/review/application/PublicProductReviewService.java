package com.yuruicamp.backend.review.application;

import java.util.List;
import java.util.Map;

import com.yuruicamp.backend.catalog.infrastructure.ProductRepository;
import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.review.api.ProductReviewSummaryResponse;
import com.yuruicamp.backend.review.api.ProductReviewsResponse;
import com.yuruicamp.backend.review.api.PublicProductReviewResponse;
import com.yuruicamp.backend.review.infrastructure.PublicProductReviewRepository;
import com.yuruicamp.backend.review.infrastructure.PublicProductReviewRepository.PublicReviewRow;
import com.yuruicamp.backend.review.infrastructure.PublicProductReviewRepository.RatingSummary;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PublicProductReviewService {

	private static final Map<String, String> SORTS = Map.of(
			"latest", "review.created_at DESC",
			"highest", "review.rating DESC, review.created_at DESC",
			"lowest", "review.rating ASC, review.created_at DESC");

	private final PublicProductReviewRepository reviews;
	private final ProductRepository products;

	public PublicProductReviewService(PublicProductReviewRepository reviews, ProductRepository products) {
		this.reviews = reviews;
		this.products = products;
	}

	@Transactional(readOnly = true)
	public PagedProductReviews getReviews(
			String productId,
			int page,
			int size,
			String sort,
			Integer rating,
			boolean hasPhotos) {
		if (products.findActiveByIdForCatalog(productId).isEmpty()) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Product not found: " + productId);
		}

		String orderBy = SORTS.get(sort);
		if (orderBy == null) {
			throw new BusinessException(
					ErrorCode.VALIDATION_ERROR,
					"Invalid sort: " + sort + ". Allowed values: latest, highest, lowest");
		}

		RatingSummary summary = reviews.summarize(productId);
		long filteredTotal = reviews.countFiltered(productId, rating, hasPhotos);
		List<PublicReviewRow> rows = reviews.findPage(
				productId,
				size,
				page * size,
				orderBy,
				rating,
				hasPhotos);
		Map<String, List<String>> photos = reviews.findPhotos(
				rows.stream()
						.map(PublicReviewRow::id)
						.toList());
		List<PublicProductReviewResponse> items = rows.stream()
				.map(row -> new PublicProductReviewResponse(
						row.id(),
						row.buyerName(),
						row.productName(),
						row.rating(),
						row.comment(),
						photos.getOrDefault(row.id(), List.of()),
						true,
						row.createdAt()))
				.toList();
		int totalPages = filteredTotal == 0 ? 0 : (int) Math.ceil((double) filteredTotal / size);

		return new PagedProductReviews(
				new ProductReviewsResponse(
						items,
						new ProductReviewSummaryResponse(
								summary.totalCount(),
								summary.averageRating(),
								summary.ratingCounts())),
				new PageMeta(page, size, filteredTotal, totalPages));
	}

	public record PagedProductReviews(ProductReviewsResponse data, PageMeta meta) {
	}
}
