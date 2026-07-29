package com.yuruicamp.backend.review.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.review.api.MemberReviewCreateRequest;
import com.yuruicamp.backend.review.api.MemberReviewResponse;
import com.yuruicamp.backend.review.api.MemberReviewUpdateRequest;
import com.yuruicamp.backend.review.infrastructure.MemberReviewRepository;
import com.yuruicamp.backend.review.infrastructure.MemberReviewRepository.MemberReviewRow;
import com.yuruicamp.backend.review.infrastructure.MemberReviewRepository.PurchasedItem;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MemberReviewService {

	private final MemberReviewRepository reviews;
	private final Clock clock;
	private final ReviewPhotoStorageService photoStorage;

	// 指定正式執行時由 Spring 注入 Repository 與照片儲存服務。
	@Autowired
	public MemberReviewService(MemberReviewRepository reviews, ReviewPhotoStorageService photoStorage) {
		this(reviews, photoStorage, Clock.systemUTC());
	}

	MemberReviewService(MemberReviewRepository reviews, ReviewPhotoStorageService photoStorage, Clock clock) {
		this.reviews = reviews;
		this.photoStorage = photoStorage;
		this.clock = clock;
	}

	@Transactional(readOnly = true)
	public List<MemberReviewResponse> list(String customerId) {
		validateCustomer(customerId);
		return reviews.findAllForCustomer(customerId).stream()
				.map(this::toResponse)
				.toList();
	}

	@Transactional
	public MemberReviewResponse create(String customerId, MemberReviewCreateRequest request) {
		validateCustomer(customerId);
		PurchasedItem item = reviews.findPurchasedItemForUpdate(request.orderItemId());
		if (item == null) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Order item not found");
		}
		if (!customerId.equals(item.customerId())) {
			throw new BusinessException(ErrorCode.REVIEW_ORDER_FORBIDDEN, "Order item does not belong to customer");
		}
		if (!"completed".equals(item.orderStatus())) {
			throw new BusinessException(
					ErrorCode.REVIEW_ORDER_NOT_COMPLETED,
					"Only completed order items can be reviewed");
		}
		if (reviews.existsByOrderItemId(item.orderItemId())) {
			throw duplicateReview();
		}

		String reviewId = UUID.randomUUID().toString().replace("-", "");
		Instant createdAt = clock.instant();
		String comment = normalizeComment(request.comment());
		List<String> photoUrls = validatePhotoUrls(customerId, item.orderItemId(), request.photoUrls());
		try {
			reviews.insert(reviewId, item.orderItemId(), request.rating(), comment, createdAt);
			reviews.insertPhotos(reviewId, photoUrls);
		} catch (DuplicateKeyException error) {
			throw duplicateReview();
		}

		return new MemberReviewResponse(
				reviewId,
				item.orderItemId(),
				item.orderId(),
				item.customerId(),
				item.productId(),
				item.variantId(),
				item.sku(),
				item.productName(),
				item.buyerName(),
				request.rating(),
				comment,
				photoUrls,
				true,
				createdAt);
	}

	@Transactional
	public List<String> uploadPhotos(String customerId, long orderItemId, MultipartFile[] files) {
		validateCustomer(customerId);
		PurchasedItem item = reviews.findPurchasedItemForUpdate(orderItemId);
		if (item == null) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Order item not found");
		}
		if (!customerId.equals(item.customerId())) {
			throw new BusinessException(ErrorCode.REVIEW_ORDER_FORBIDDEN, "Order item does not belong to customer");
		}
		if (!"completed".equals(item.orderStatus())) {
			throw new BusinessException(
					ErrorCode.REVIEW_ORDER_NOT_COMPLETED,
					"This order item cannot accept review photos");
		}
		return photoStorage.store(customerId, orderItemId, files);
	}

	@Transactional
	public MemberReviewResponse update(String customerId, String reviewId, MemberReviewUpdateRequest request) {
		validateCustomer(customerId);
		MemberReviewRow current = requireOwnedReview(customerId, reviewId);
		String comment = normalizeComment(request.comment());
		List<String> photoUrls = validatePhotoUrls(customerId, current.orderItemId(), request.photoUrls());
		reviews.update(reviewId, request.rating(), comment);
		reviews.replacePhotos(reviewId, photoUrls);
		photoStorage.delete(current.photos().stream().filter(url -> !photoUrls.contains(url)).toList());
		return toResponse(new MemberReviewRow(
				current.id(), current.orderItemId(), current.orderId(), current.customerId(),
				current.productId(), current.variantId(), current.sku(), current.productName(),
				current.buyerName(), request.rating(), comment, current.createdAt(), photoUrls));
	}

	@Transactional
	public void delete(String customerId, String reviewId) {
		validateCustomer(customerId);
		MemberReviewRow current = requireOwnedReview(customerId, reviewId);
		reviews.delete(reviewId);
		photoStorage.delete(current.photos());
	}

	private MemberReviewRow requireOwnedReview(String customerId, String reviewId) {
		MemberReviewRow review = reviews.findByIdForCustomer(reviewId, customerId);
		if (review == null) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Review not found");
		}
		return review;
	}

	private List<String> validatePhotoUrls(String customerId, long orderItemId, List<String> urls) {
		if (urls == null || urls.isEmpty()) {
			return List.of();
		}
		if (urls.size() > 5) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "At most 5 review photos are allowed");
		}
		String safeCustomer = customerId.replaceAll("[^A-Za-z0-9_-]", "_");
		String prefix = "/assets/uploads/reviews/" + safeCustomer + "/" + orderItemId + "/";
		if (urls.stream().anyMatch(url -> url == null
				|| !url.startsWith(prefix)
				|| !url.substring(prefix.length()).matches("[a-f0-9]{32}\\.(jpg|png|webp)"))) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Invalid review photo URL");
		}
		return List.copyOf(urls);
	}

	private MemberReviewResponse toResponse(MemberReviewRow row) {
		return new MemberReviewResponse(
				row.id(),
				row.orderItemId(),
				row.orderId(),
				row.customerId(),
				row.productId(),
				row.variantId(),
				row.sku(),
				row.productName(),
				row.buyerName(),
				row.rating(),
				row.comment(),
				row.photos(),
				true,
				row.createdAt());
	}

	private String normalizeComment(String comment) {
		if (comment == null) {
			return null;
		}
		String normalized = comment.trim();
		return normalized.isEmpty() ? null : normalized;
	}

	private void validateCustomer(String customerId) {
		if (customerId == null || customerId.isBlank()) {
			throw new BusinessException(ErrorCode.UNAUTHORIZED, "Authenticated customer is required");
		}
	}

	private BusinessException duplicateReview() {
		return new BusinessException(ErrorCode.REVIEW_ALREADY_EXISTS, "This order item was already reviewed");
	}
}
