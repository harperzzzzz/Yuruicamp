package com.yuruicamp.backend.review.api;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;

class MemberReviewCreateRequestValidationTest {

	@Test
	void rejectsCommentLongerThanOneThousandCharacters() {
		try (var validatorFactory = Validation.buildDefaultValidatorFactory()) {
			var violations = validatorFactory.getValidator().validate(
					new MemberReviewCreateRequest(1L, 5, "a".repeat(1001), null));

			assertThat(violations)
					.anySatisfy(violation -> assertThat(violation.getPropertyPath().toString()).isEqualTo("comment"));
		}
	}

	@Test
	void allowsBlankOptionalComment() {
		try (var validatorFactory = Validation.buildDefaultValidatorFactory()) {
			var violations = validatorFactory.getValidator().validate(
					new MemberReviewCreateRequest(1L, 5, "   ", null));

			assertThat(violations).isEmpty();
		}
	}
}
