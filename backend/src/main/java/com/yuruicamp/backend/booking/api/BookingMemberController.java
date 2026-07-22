package com.yuruicamp.backend.booking.api;

import java.util.List;

import com.yuruicamp.backend.booking.application.BookingMemberService;
import com.yuruicamp.backend.booking.application.BookingMemberService.PagedBookings;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// E-5 會員預約 API 只使用登入 principal，不接收前端指定 customerId。
@RestController
@Validated
@RequestMapping("/api/booking/bookings")
@Tag(name = "Booking Member", description = "Authenticated member booking history")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class BookingMemberController {

	private final BookingMemberService service;

	public BookingMemberController(BookingMemberService service) {
		this.service = service;
	}

	@GetMapping
	@Operation(summary = "取得目前會員的預約列表")
	public ApiResponse<List<BookingListItemResponse>> list(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@Parameter(description = "從 0 起算的頁碼", example = "0")
			@RequestParam(defaultValue = "0") @Min(0) int page,
			@Parameter(description = "每頁 1～100 筆", example = "20")
			@RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
		PagedBookings result = service.list(principal.customerId(), page, size);

		return ApiResponse.ok(result.data(), result.meta());
	}

	@GetMapping("/{id}")
	@Operation(summary = "取得目前會員的單筆預約詳情")
	public ApiResponse<BookingDetailResponse> getById(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String id) {
		return ApiResponse.ok(service.getBooking(principal.customerId(), id));
	}
}
