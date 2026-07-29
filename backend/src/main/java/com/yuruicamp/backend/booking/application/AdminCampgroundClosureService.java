package com.yuruicamp.backend.booking.application;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import com.yuruicamp.backend.booking.api.AdminCampgroundClosureCreateRequest;
import com.yuruicamp.backend.booking.api.AdminCampgroundClosureResponse;
import com.yuruicamp.backend.booking.api.AdminCampgroundClosureUpdateRequest;
import com.yuruicamp.backend.booking.infrastructure.AdminCampgroundClosureRepository;
import com.yuruicamp.backend.booking.infrastructure.AdminCampgroundClosureRepository.ClosureRow;
import com.yuruicamp.backend.booking.infrastructure.AdminCampgroundClosureRepository.ClosureWrite;
import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 後台營區公休管理用例，日期與每週規則都在交易內驗證後寫入。
 */
@Service
public class AdminCampgroundClosureService {

	private static final Set<String> CLOSURE_TYPES = Set.of("", "date_range", "weekly");
	private static final Set<String> SORT_DIRECTIONS = Set.of("asc", "desc");
	private static final Map<String, String> SORT_COLUMNS = Map.of(
			"createdAt", "closure.created_at",
			"updatedAt", "closure.updated_at",
			"startDate", "closure.start_date",
			"campgroundId", "closure.campground_id");

	private final AdminCampgroundClosureRepository repository;

	public AdminCampgroundClosureService(AdminCampgroundClosureRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public PagedClosures list(
			int page,
			int size,
			String query,
			String campgroundId,
			String closureType,
			String sort) {
		String normalizedType = normalize(closureType);
		SortSpec sortSpec = validateList(page, size, normalizedType, sort);
		var idPage = repository.findIds(
				page,
				size,
				normalize(query),
				normalize(campgroundId),
				normalizedType,
				sortSpec.column(),
				sortSpec.direction());
		int totalPages = (int) Math.ceil((double) idPage.totalElements() / size);
		List<AdminCampgroundClosureResponse> data = repository.findByIds(idPage.ids())
				.stream()
				.map(this::toResponse)
				.toList();

		return new PagedClosures(data, new PageMeta(page, size, idPage.totalElements(), totalPages));
	}

	@Transactional(readOnly = true)
	public AdminCampgroundClosureResponse get(long id) {
		ClosureRow row = repository.findById(id);
		if (row == null) {
			throw notFound();
		}

		return toResponse(row);
	}

	@Transactional
	public AdminCampgroundClosureResponse create(
			String actorId,
			AdminCampgroundClosureCreateRequest request) {
		String campgroundId = request.campgroundId().trim();
		if (repository.findActiveCampgroundName(campgroundId) == null) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Active campground not found");
		}
		ClosureWrite write = new ClosureWrite(
				campgroundId,
				request.closureType(),
				request.startDate(),
				request.endDate(),
				request.weekday(),
				request.effectiveFrom(),
				request.effectiveTo(),
				request.reason().trim());
		validate(write);
		long id = repository.insert(write, actorId, java.time.Instant.now());

		return get(id);
	}

	@Transactional
	public AdminCampgroundClosureResponse update(
			long id,
			AdminCampgroundClosureUpdateRequest request) {
		ClosureRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}
		String type = request.closureType() == null ? existing.closureType() : request.closureType();
		ClosureWrite write = new ClosureWrite(
				existing.campgroundId(),
				type,
				"date_range".equals(type)
						? (request.startDate() == null ? existing.startDate() : request.startDate())
						: null,
				"date_range".equals(type)
						? (request.endDate() == null ? existing.endDate() : request.endDate())
						: null,
				"weekly".equals(type)
						? (request.weekday() == null ? existing.weekday() : request.weekday())
						: null,
				"weekly".equals(type)
						? (request.effectiveFrom() == null ? existing.effectiveFrom() : request.effectiveFrom())
						: null,
				"weekly".equals(type)
						? (request.effectiveTo() == null ? existing.effectiveTo() : request.effectiveTo())
						: null,
				request.reason() == null ? existing.reason() : request.reason().trim());
		validate(write);
		repository.update(id, write, java.time.Instant.now());

		return get(id);
	}

	@Transactional
	public void delete(long id) {
		ClosureRow existing = repository.lockById(id);
		if (existing == null) {
			throw notFound();
		}

		repository.delete(id);
	}

	private SortSpec validateList(int page, int size, String closureType, String sort) {
		if (page < 0 || size < 1 || size > 100 || !CLOSURE_TYPES.contains(closureType)) {
			throw validation("Invalid campground closure list parameters");
		}
		String[] parts = sort.split(",", -1);
		if (parts.length != 2
				|| !SORT_COLUMNS.containsKey(parts[0])
				|| !SORT_DIRECTIONS.contains(parts[1].toLowerCase(Locale.ROOT))) {
			throw validation("Invalid campground closure sort");
		}

		return new SortSpec(SORT_COLUMNS.get(parts[0]), parts[1].toUpperCase(Locale.ROOT));
	}

	private void validate(ClosureWrite write) {
		if (write.reason().isBlank()) {
			throw validation("Campground closure reason cannot be blank");
		}
		if ("date_range".equals(write.closureType())) {
			if (write.startDate() == null
					|| write.endDate() == null
					|| !write.endDate().isAfter(write.startDate())
					|| write.weekday() != null
					|| write.effectiveFrom() != null
					|| write.effectiveTo() != null) {
				throw validation("Date-range closure requires a non-empty [startDate, endDate) only");
			}

			return;
		}
		if (!"weekly".equals(write.closureType())
				|| write.weekday() == null
				|| write.weekday() < 0
				|| write.weekday() > 6
				|| write.effectiveFrom() == null
				|| write.effectiveTo() == null
				|| write.effectiveTo().isBefore(write.effectiveFrom())
				|| write.startDate() != null
				|| write.endDate() != null) {
			throw validation("Weekly closure requires weekday and inclusive effective period only");
		}
	}

	private AdminCampgroundClosureResponse toResponse(ClosureRow row) {
		return new AdminCampgroundClosureResponse(
				row.id(),
				row.campgroundId(),
				row.campgroundName(),
				row.closureType(),
				row.startDate(),
				row.endDate(),
				row.weekday(),
				row.effectiveFrom(),
				row.effectiveTo(),
				row.reason(),
				row.createdBy(),
				row.createdByName(),
				row.createdAt(),
				row.updatedAt());
	}

	private String normalize(String value) {
		return value == null ? "" : value.trim();
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "Campground closure not found");
	}

	public record PagedClosures(List<AdminCampgroundClosureResponse> data, PageMeta meta) {
	}

	private record SortSpec(String column, String direction) {
	}
}
