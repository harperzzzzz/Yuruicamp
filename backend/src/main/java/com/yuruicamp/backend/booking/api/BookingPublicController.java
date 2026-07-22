package com.yuruicamp.backend.booking.api;

import java.util.List;

import com.yuruicamp.backend.booking.application.BookingPublicService;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.api.PageMeta;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// Booking 公開 API；Controller 只接參數、呼叫 Service 與包裝 Envelope。
@RestController
@Validated
@RequestMapping("/api/booking")
@Tag(name = "Booking", description = "Booking public reads and availability (Contract v0.4)")
public class BookingPublicController {

	private final BookingPublicService bookingPublicService;

	public BookingPublicController(BookingPublicService bookingPublicService) {
		this.bookingPublicService = bookingPublicService;
	}

	@GetMapping("/campgrounds")
	@Operation(summary = "列出有效營區")
	public ApiResponse<List<CampgroundResponse>> listCampgrounds() {
		return listResponse(bookingPublicService.listCampgrounds());
	}

	@GetMapping("/campgrounds/{id}")
	@Operation(summary = "取得營區詳情與有效營位")
	public ApiResponse<CampgroundResponse> getCampground(
			@Parameter(example = "C002") @PathVariable String id) {
		return ApiResponse.ok(bookingPublicService.getCampground(id));
	}

	@GetMapping("/equipment")
	@Operation(summary = "列出指定營區的有效租借裝備")
	public ApiResponse<List<RentalEquipmentResponse>> listEquipment(
			@Parameter(example = "C002")
			@RequestParam @NotBlank(message = "campgroundId must not be blank") String campgroundId) {
		return listResponse(bookingPublicService.listEquipment(campgroundId));
	}

	@GetMapping("/policy")
	@Operation(summary = "取得單例預約政策")
	public ApiResponse<BookingPolicyResponse> getPolicy() {
		return ApiResponse.ok(bookingPublicService.getPolicy());
	}

	@GetMapping("/closures")
	@Operation(summary = "列出有效營區的公休規則")
	public ApiResponse<List<CampgroundClosureResponse>> listClosures() {
		return listResponse(bookingPublicService.listClosures());
	}

	@PostMapping("/check-availability")
	@Operation(summary = "查詢住宿期間的營位最低剩餘量")
	public ApiResponse<BookingAvailabilityResponse> checkAvailability(
			@Valid @RequestBody BookingAvailabilityRequest request) {
		return ApiResponse.ok(bookingPublicService.checkAvailability(request));
	}

	// 無分頁參數的列表仍依共用契約附上單頁 meta。
	private <T> ApiResponse<List<T>> listResponse(List<T> data) {
		int totalPages = data.isEmpty() ? 0 : 1;
		PageMeta meta = new PageMeta(0, data.size(), data.size(), totalPages);

		return ApiResponse.ok(data, meta);
	}
}
