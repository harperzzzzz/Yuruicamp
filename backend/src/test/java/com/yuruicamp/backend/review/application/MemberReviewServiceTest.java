package com.yuruicamp.backend.review.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.review.api.MemberReviewCreateRequest;
import com.yuruicamp.backend.review.api.MemberReviewUpdateRequest;
import com.yuruicamp.backend.review.infrastructure.MemberReviewRepository;
import com.yuruicamp.backend.review.infrastructure.MemberReviewRepository.MemberReviewRow;
import com.yuruicamp.backend.review.infrastructure.MemberReviewRepository.PurchasedItem;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

class MemberReviewServiceTest {

	private static final Instant NOW = Instant.parse("2026-07-23T08:00:00Z");
	private static final String CUSTOMER_ID = "U001";
	private static final long ORDER_ITEM_ID = 602081L;

	@Mock
	private MemberReviewRepository reviews;

	private MemberReviewService service;

	@BeforeEach
	void setUp() {
		MockitoAnnotations.openMocks(this);
		service = new MemberReviewService(
				reviews,
				org.mockito.Mockito.mock(ReviewPhotoStorageService.class),
				Clock.fixed(NOW, ZoneOffset.UTC));
	}

	@Test
	void createsVerifiedReviewForOwnCompletedOrderItem() {
		when(reviews.findPurchasedItemForUpdate(ORDER_ITEM_ID))
				.thenReturn(item("completed"));
		when(reviews.existsByOrderItemId(ORDER_ITEM_ID)).thenReturn(false);

		var result = service.create(
				CUSTOMER_ID,
				new MemberReviewCreateRequest(ORDER_ITEM_ID, 5, "  很實用  ", null));

		assertThat(result.orderItemId()).isEqualTo(ORDER_ITEM_ID);
		assertThat(result.customerId()).isEqualTo(CUSTOMER_ID);
		assertThat(result.rating()).isEqualTo(5);
		assertThat(result.comment()).isEqualTo("很實用");
		assertThat(result.verifiedPurchase()).isTrue();
		assertThat(result.createdAt()).isEqualTo(NOW);
		verify(reviews).insert(any(String.class), eq(ORDER_ITEM_ID), eq(5), eq("很實用"), eq(NOW));
	}

	@Test
	void savesBlankOptionalCommentAsNull() {
		when(reviews.findPurchasedItemForUpdate(ORDER_ITEM_ID))
				.thenReturn(item("completed"));
		when(reviews.existsByOrderItemId(ORDER_ITEM_ID)).thenReturn(false);

		var result = service.create(
				CUSTOMER_ID,
				new MemberReviewCreateRequest(ORDER_ITEM_ID, 5, "   ", null));

		assertThat(result.comment()).isNull();
		verify(reviews).insert(any(String.class), eq(ORDER_ITEM_ID), eq(5), eq(null), eq(NOW));
	}

	@Test
	void rejectsOrderItemsThatDoNotBelongToCurrentCustomer() {
		when(reviews.findPurchasedItemForUpdate(ORDER_ITEM_ID))
				.thenReturn(itemForCustomer("U999", "completed"));

		assertThatThrownBy(() -> service.create(
				CUSTOMER_ID,
				new MemberReviewCreateRequest(ORDER_ITEM_ID, 4, "內容", null)))
				.isInstanceOfSatisfying(BusinessException.class, error ->
						assertThat(error.getErrorCode()).isEqualTo(ErrorCode.REVIEW_ORDER_FORBIDDEN));

		verify(reviews, never()).insert(any(), eq(ORDER_ITEM_ID), eq(4), any(), any());
	}

	@Test
	void rejectsOrderItemsBeforeCompletion() {
		when(reviews.findPurchasedItemForUpdate(ORDER_ITEM_ID))
				.thenReturn(item("unshipped"));

		assertThatThrownBy(() -> service.create(
				CUSTOMER_ID,
				new MemberReviewCreateRequest(ORDER_ITEM_ID, 4, "內容", null)))
				.isInstanceOfSatisfying(BusinessException.class, error ->
						assertThat(error.getErrorCode()).isEqualTo(ErrorCode.REVIEW_ORDER_NOT_COMPLETED));
	}

	@Test
	void rejectsDuplicateReviewForSameOrderItem() {
		when(reviews.findPurchasedItemForUpdate(ORDER_ITEM_ID))
				.thenReturn(item("completed"));
		when(reviews.existsByOrderItemId(ORDER_ITEM_ID)).thenReturn(true);

		assertThatThrownBy(() -> service.create(
				CUSTOMER_ID,
				new MemberReviewCreateRequest(ORDER_ITEM_ID, 4, "內容", null)))
				.isInstanceOfSatisfying(BusinessException.class, error ->
						assertThat(error.getErrorCode()).isEqualTo(ErrorCode.REVIEW_ALREADY_EXISTS));
	}

	@Test
	void updatesOnlyOwnedReview() {
		var current = new MemberReviewRow(
				"R1", ORDER_ITEM_ID, "O001", CUSTOMER_ID, "P001", "V001", "SKU-001",
				"測試商品", "測試會員", 3, "舊內容", NOW, java.util.List.of());
		when(reviews.findByIdForCustomer("R1", CUSTOMER_ID)).thenReturn(current);

		var result = service.update(
				CUSTOMER_ID,
				"R1",
				new MemberReviewUpdateRequest(5, "新內容", java.util.List.of()));

		assertThat(result.rating()).isEqualTo(5);
		assertThat(result.comment()).isEqualTo("新內容");
		verify(reviews).update("R1", 5, "新內容");
		verify(reviews).replacePhotos("R1", java.util.List.of());
	}

	@Test
	void deleteHidesReviewsOwnedByAnotherCustomer() {
		when(reviews.findByIdForCustomer("R1", CUSTOMER_ID)).thenReturn(null);

		assertThatThrownBy(() -> service.delete(CUSTOMER_ID, "R1"))
				.isInstanceOfSatisfying(BusinessException.class, error ->
						assertThat(error.getErrorCode()).isEqualTo(ErrorCode.NOT_FOUND));

		verify(reviews, never()).delete("R1");
	}

	private PurchasedItem item(String status) {
		return itemForCustomer(CUSTOMER_ID, status);
	}

	private PurchasedItem itemForCustomer(String customerId, String status) {
		return new PurchasedItem(
				ORDER_ITEM_ID,
				"O001",
				customerId,
				status,
				"P001",
				"V001",
				"SKU-001",
				"測試商品",
				"測試會員");
	}
}
