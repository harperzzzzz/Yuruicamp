package com.yuruicamp.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import com.yuruicamp.backend.admin.api.AdminUserController;
import com.yuruicamp.backend.booking.api.AdminBookingController;
import com.yuruicamp.backend.booking.api.AdminCampgroundClosureController;
import com.yuruicamp.backend.catalog.api.AdminProductController;
import com.yuruicamp.backend.coupon.api.AdminCouponController;
import com.yuruicamp.backend.customer.api.AdminCustomerController;
import com.yuruicamp.backend.inventory.api.AdminInventoryMovementController;
import com.yuruicamp.backend.order.api.AdminOrderController;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import org.junit.jupiter.api.Test;

class AdminOpenApiSecurityTest {

	@Test
	void protectedAdminControllersDeclareFirebaseBearer() {
		// 所有受保護的後台 Controller 都必須讓 Swagger 自動帶入 Firebase Token。
		List<Class<?>> protectedControllers = List.of(
				AdminUserController.class,
				AdminCustomerController.class,
				AdminOrderController.class,
				AdminBookingController.class,
				AdminProductController.class,
				AdminInventoryMovementController.class,
				AdminCouponController.class,
				AdminCampgroundClosureController.class);

		assertThat(protectedControllers)
				.allSatisfy(controller -> assertThat(controller.getAnnotation(SecurityRequirement.class))
						.isNotNull()
						.extracting(SecurityRequirement::name)
						.isEqualTo(OpenApiConfig.FIREBASE_BEARER));
	}
}
