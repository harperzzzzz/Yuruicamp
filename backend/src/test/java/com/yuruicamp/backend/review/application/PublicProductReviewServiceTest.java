package com.yuruicamp.backend.review.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.yuruicamp.backend.catalog.domain.Product;
import com.yuruicamp.backend.catalog.infrastructure.ProductRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.review.infrastructure.PublicProductReviewRepository;
import com.yuruicamp.backend.review.infrastructure.PublicProductReviewRepository.PublicReviewRow;
import com.yuruicamp.backend.review.infrastructure.PublicProductReviewRepository.RatingSummary;
import org.junit.jupiter.api.Test;

class PublicProductReviewServiceTest {

	@Test
	void returnsPageAndAggregateSummary() {
		PublicProductReviewRepository reviews = mock(PublicProductReviewRepository.class);
		ProductRepository products = mock(ProductRepository.class);
		when(products.findActiveByIdForCatalog("P001")).thenReturn(Optional.of(mock(Product.class)));
		when(reviews.summarize("P001")).thenReturn(
				new RatingSummary(3, new BigDecimal("4.33"), Map.of(1, 0L, 2, 0L, 3, 1L, 4, 0L, 5, 2L)));
		when(reviews.countFiltered("P001", 5, true)).thenReturn(2L);
		when(reviews.findPage("P001", 2, 2, "review.rating DESC, review.created_at DESC", 5, true))
				.thenReturn(List.of(new PublicReviewRow(
						"R3", "王小明", "帳篷", 3, "穩定", Instant.parse("2026-07-23T00:00:00Z"))));
		when(reviews.findPhotos(List.of("R3"))).thenReturn(Map.of("R3", List.of("/r3.jpg")));

		PublicProductReviewService.PagedProductReviews result =
				new PublicProductReviewService(reviews, products)
						.getReviews("P001", 1, 2, "highest", 5, true);

		assertEquals(3, result.data().summary().totalCount());
		assertEquals(new BigDecimal("4.33"), result.data().summary().averageRating());
		assertEquals(2, result.meta().totalElements());
		assertEquals(1, result.meta().totalPages());
		assertEquals(List.of("/r3.jpg"), result.data().items().getFirst().photos());
		verify(reviews).findPage("P001", 2, 2, "review.rating DESC, review.created_at DESC", 5, true);
	}

	@Test
	void missingProductReturnsNotFound() {
		ProductRepository products = mock(ProductRepository.class);
		when(products.findActiveByIdForCatalog("missing")).thenReturn(Optional.empty());
		PublicProductReviewService service =
				new PublicProductReviewService(mock(PublicProductReviewRepository.class), products);

		BusinessException error = assertThrows(
				BusinessException.class,
				() -> service.getReviews("missing", 0, 20, "latest", null, false));

		assertEquals(ErrorCode.NOT_FOUND, error.getErrorCode());
	}

	@Test
	void invalidSortReturnsValidationError() {
		ProductRepository products = mock(ProductRepository.class);
		when(products.findActiveByIdForCatalog(anyString())).thenReturn(Optional.of(mock(Product.class)));
		PublicProductReviewService service =
				new PublicProductReviewService(mock(PublicProductReviewRepository.class), products);

		BusinessException error = assertThrows(
				BusinessException.class,
				() -> service.getReviews("P001", 0, 20, "unknown", null, false));

		assertEquals(ErrorCode.VALIDATION_ERROR, error.getErrorCode());
	}
}
