package com.yuruicamp.backend.customer.application;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.customer.api.AdminCustomerDetailResponse;
import com.yuruicamp.backend.customer.api.AdminCustomerListResponse;
import com.yuruicamp.backend.customer.api.AdminCustomerUpdateRequest;
import com.yuruicamp.backend.customer.domain.Customer;
import com.yuruicamp.backend.customer.domain.CustomerStatus;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerReadRepository;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerRow;
import com.yuruicamp.backend.customer.infrastructure.CustomerRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台會員管理用例，列表使用讀模型，更新與狀態轉換鎖定會員主檔。
 */
@Service
public class AdminCustomerService {

	private static final Set<String> STATUS_VALUES = Set.of("", "active", "suspended", "deleted");
	private static final Set<String> TIER_VALUES = Set.of("", "explorer", "guide", "master");
	private static final Set<String> SORT_DIRECTIONS = Set.of("asc", "desc");

	private final CustomerRepository customerRepository;
	private final AdminCustomerReadRepository readRepository;

	public AdminCustomerService(
			CustomerRepository customerRepository,
			AdminCustomerReadRepository readRepository) {
		this.customerRepository = customerRepository;
		this.readRepository = readRepository;
	}

	@Transactional(readOnly = true)
	public PagedCustomers list(
			int page,
			int size,
			String query,
			String status,
			String tier,
			List<Long> tagIds,
			String sort) {
		String normalizedStatus = normalize(status);
		String normalizedTier = normalize(tier);
		SortSpec sortSpec = validateListParameters(page, size, normalizedStatus, normalizedTier, tagIds, sort);

		var idPage = readRepository.findIds(
				page, size, normalize(query), normalizedStatus, normalizedTier, tagIds,
				sortSpec.field(), sortSpec.direction());
		List<AdminCustomerRow> rows = readRepository.findRows(idPage.ids());
		Map<String, AdminCustomerRow> rowsById = new HashMap<>();
		rows.forEach(row -> rowsById.put(row.id(), row));
		var tagsByCustomer = readRepository.findTags(idPage.ids());
		List<AdminCustomerListResponse> data = new ArrayList<>();
		for (String id : idPage.ids()) {
			AdminCustomerRow row = rowsById.get(id);
			data.add(toListResponse(row, tagsByCustomer.getOrDefault(id, List.of())));
		}
		int totalPages = size == 0 ? 0 : (int) Math.ceil((double) idPage.totalElements() / size);

		return new PagedCustomers(data, new PageMeta(page, size, idPage.totalElements(), totalPages));
	}

	@Transactional(readOnly = true)
	public AdminCustomerDetailResponse get(String id) {
		Customer customer = findCustomer(id);
		AdminCustomerRow summary = readRepository.findRows(List.of(id)).getFirst();

		return toDetailResponse(customer, summary);
	}

	@Transactional
	public AdminCustomerDetailResponse update(String id, AdminCustomerUpdateRequest request) {
		Customer customer = findCustomerForUpdate(id);
		if (customer.getStatus() == CustomerStatus.deleted) {
			throw new BusinessException(ErrorCode.CONFLICT, "Deleted customer cannot be updated");
		}
		if (request.name() != null) {
			String name = request.name().trim();
			if (name.isBlank()) {
				throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Customer name cannot be blank");
			}
			customer.setName(name);
		}
		if (request.phone() != null) {
			customer.setPhone(request.phone().trim().isEmpty() ? null : request.phone().trim());
		}
		if (request.birthday() != null) {
			customer.setBirthday(request.birthday());
		}
		if (request.points() != null) {
			customer.setPoints(request.points());
		}
		customer.setUpdatedAt(Instant.now());
		customerRepository.save(customer);

		return get(id);
	}

	@Transactional
	public AdminCustomerDetailResponse suspend(String id) {
		Customer customer = findCustomerForUpdate(id);
		if (customer.getStatus() == CustomerStatus.deleted) {
			throw new BusinessException(ErrorCode.CONFLICT, "Deleted customer cannot be suspended");
		}
		if (customer.getStatus() == CustomerStatus.active) {
			customer.setStatus(CustomerStatus.suspended);
			customer.setDeletedAt(null);
			customer.setUpdatedAt(Instant.now());
			customerRepository.save(customer);
		}

		return get(id);
	}

	@Transactional
	public AdminCustomerDetailResponse reactivate(String id) {
		Customer customer = findCustomerForUpdate(id);
		if (customer.getStatus() == CustomerStatus.deleted) {
			throw new BusinessException(ErrorCode.CONFLICT, "Deleted customer cannot be reactivated in G-2a");
		}
		if (customer.getStatus() == CustomerStatus.suspended) {
			customer.setStatus(CustomerStatus.active);
			customer.setDeletedAt(null);
			customer.setUpdatedAt(Instant.now());
			customerRepository.save(customer);
		}

		return get(id);
	}

	private SortSpec validateListParameters(
			int page,
			int size,
			String status,
			String tier,
			List<Long> tagIds,
			String sort) {
		if (page < 0 || size < 1 || size > 100 || tagIds.stream().anyMatch(id -> id == null || id <= 0)) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Invalid customer pagination or tag filter");
		}
		if (!STATUS_VALUES.contains(status) || !TIER_VALUES.contains(tier)) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Invalid customer status or tier filter");
		}
		String[] parts = sort.split(",", -1);
		if (parts.length != 2
				|| AdminCustomerReadRepository.resolveSortColumn(parts[0]) == null
				|| !SORT_DIRECTIONS.contains(parts[1].toLowerCase(Locale.ROOT))) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Invalid customer sort");
		}

		return new SortSpec(parts[0], parts[1].toUpperCase(Locale.ROOT));
	}

	private AdminCustomerListResponse toListResponse(
			AdminCustomerRow row,
			List<com.yuruicamp.backend.customer.api.AdminCustomerTagResponse> tags) {
		return new AdminCustomerListResponse(
				row.id(), row.name(), row.phone(), row.email(), row.status(), row.registeredAt(),
				row.tier(), row.tierName(), money(row.totalSpent()), row.points(), tags);
	}

	private AdminCustomerDetailResponse toDetailResponse(Customer customer, AdminCustomerRow summary) {
		return new AdminCustomerDetailResponse(
				customer.getId(), customer.getName(), customer.getPhone(), customer.getEmail(),
				customer.getBirthday(), customer.getStatus(), customer.getRegisteredAt(),
				summary.tier(), summary.tierName(), money(summary.totalSpent()), customer.getPoints(),
				customer.isFirstPurchaseUsed(), customer.getAuthProvider(),
				customer.getFirebaseUid() != null && !customer.getFirebaseUid().isBlank(),
				customer.getAvatarUrl(), customer.getCreatedAt(), customer.getUpdatedAt(),
				readRepository.findTags(List.of(customer.getId())).getOrDefault(customer.getId(), List.of()),
				readRepository.findPreferences(customer.getId()),
				readRepository.findDefaultAddress(customer.getId()),
				readRepository.countOrders(customer.getId()),
				readRepository.countBookings(customer.getId()));
	}

	private Customer findCustomer(String id) {
		return customerRepository.findById(id)
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Customer not found"));
	}

	private Customer findCustomerForUpdate(String id) {
		return customerRepository.findByIdForUpdate(id)
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Customer not found"));
	}

	private String normalize(String value) {
		return value == null ? "" : value.trim();
	}

	private String money(BigDecimal value) {
		return value.setScale(2).toPlainString();
	}

	public record PagedCustomers(List<AdminCustomerListResponse> data, PageMeta meta) {
	}

	private record SortSpec(String field, String direction) {
	}
}
