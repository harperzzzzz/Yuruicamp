package com.yuruicamp.backend.booking.api;

import java.util.List;

import com.yuruicamp.backend.booking.application.AdminCampgroundClosureService;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.AdminPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/campground-closures")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Campground Closures", description = "後台營區公休查詢、建立、更新與刪除")
public class AdminCampgroundClosureController {

	private final AdminCampgroundClosureService service;

	public AdminCampgroundClosureController(AdminCampgroundClosureService service) {
		this.service = service;
	}

	// 查詢營區公休分頁列表，支援營區、類型、關鍵字與白名單排序。
	@GetMapping
	@PreAuthorize("hasAuthority('booking-calendar.view')")
	@Operation(summary = "營區公休列表", description = "RBAC: booking-calendar.view")
	public ApiResponse<List<AdminCampgroundClosureResponse>> list(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "100") int size,
			@RequestParam(defaultValue = "") String q,
			@RequestParam(defaultValue = "") String campgroundId,
			@RequestParam(defaultValue = "") String closureType,
			@RequestParam(defaultValue = "createdAt,desc") String sort) {
		var result = service.list(page, size, q, campgroundId, closureType, sort);

		return ApiResponse.ok(result.data(), result.meta());
	}

	// 取得單一營區公休規則與建立者資訊。
	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('booking-calendar.view')")
	@Operation(summary = "營區公休詳情", description = "RBAC: booking-calendar.view")
	public ApiResponse<AdminCampgroundClosureResponse> get(@PathVariable long id) {
		return ApiResponse.ok(service.get(id));
	}

	// 建立營區公休規則，建立者由目前登入管理員決定。
	@PostMapping
	@PreAuthorize("hasAuthority('booking-calendar.edit')")
	@Operation(summary = "建立營區公休", description = "RBAC: booking-calendar.edit")
	public ApiResponse<AdminCampgroundClosureResponse> create(
			@AuthenticationPrincipal AdminPrincipal principal,
			@Valid @RequestBody AdminCampgroundClosureCreateRequest request) {
		return ApiResponse.ok(service.create(principal.adminUserId(), request));
	}

	// 更新單一營區公休的類型、日期、星期或原因。
	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('booking-calendar.edit')")
	@Operation(summary = "更新營區公休", description = "RBAC: booking-calendar.edit")
	public ApiResponse<AdminCampgroundClosureResponse> update(
			@PathVariable long id,
			@Valid @RequestBody AdminCampgroundClosureUpdateRequest request) {
		return ApiResponse.ok(service.update(id, request));
	}

	// 刪除公休規則，後續公開可用性查詢會立即不再套用。
	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('booking-calendar.edit')")
	@Operation(summary = "刪除營區公休", description = "RBAC: booking-calendar.edit")
	public ApiResponse<Void> delete(@PathVariable long id) {
		service.delete(id);

		return ApiResponse.ok(null);
	}
}
