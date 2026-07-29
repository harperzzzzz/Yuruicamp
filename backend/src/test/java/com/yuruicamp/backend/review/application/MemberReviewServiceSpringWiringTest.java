package com.yuruicamp.backend.review.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.yuruicamp.backend.review.infrastructure.MemberReviewRepository;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

class MemberReviewServiceSpringWiringTest {

	@Test
	void springUsesTheProductionConstructor() {
		try (var context = new AnnotationConfigApplicationContext()) {
			context.registerBean(MemberReviewRepository.class, () -> mock(MemberReviewRepository.class));
			context.registerBean(ReviewPhotoStorageService.class, () -> mock(ReviewPhotoStorageService.class));
			context.registerBean(MemberReviewService.class);

			context.refresh();

			assertThat(context.getBean(MemberReviewService.class)).isNotNull();
		}
	}
}
