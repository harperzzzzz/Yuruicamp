package com.yuruicamp.backend.catalog.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

import com.yuruicamp.backend.catalog.api.ProductResponse;
import com.yuruicamp.backend.catalog.api.ProductVariantResponse;
import com.yuruicamp.backend.catalog.domain.Brand;
import com.yuruicamp.backend.catalog.domain.EquipmentItem;
import com.yuruicamp.backend.catalog.domain.Product;
import com.yuruicamp.backend.catalog.domain.ProductCategory;
import com.yuruicamp.backend.catalog.domain.ProductVariant;

import org.springframework.stereotype.Component;

/**
 * Maps JPA entities → Product API Contract v0.1 DTOs.
 * Entity → 契約 DTO；金額格式化集中在這裡，Controller 不要自己 toString。
 */
@Component
public class ProductCatalogAssembler {

	public ProductResponse toResponse(Product product, String imageUrl) {
		List<ProductVariantResponse> variants = product.getVariants().stream()
				.filter(v -> "active".equals(v.getStatus()))
				.sorted(Comparator.comparing(ProductVariant::getId))
				.map(this::toVariant)
				.toList();

		EquipmentItem item = product.getItem();
		ProductCategory category = item.getCategory();
		Brand brand = item.getBrand();

		return new ProductResponse(
				product.getId(),
				item.getId(),
				product.getStatus(),
				item.getName(),
				category != null ? category.getName() : null,
				brand != null ? brand.getName() : null,
				item.getDescription(),
				imageUrl,
				minPrice(variants),
				variants);
	}

	public ProductResponse toResponse(Product product, Map<String, String> imageByItemId) {
		String image = imageByItemId.get(product.getItem().getId());
		return toResponse(product, image);
	}

	private ProductVariantResponse toVariant(ProductVariant variant) {
		return new ProductVariantResponse(
				variant.getId(),
				variant.getSku(),
				variant.getColor(),
				variant.getSize(),
				variant.getSpecification(),
				money(variant.getPrice()));
	}

	/** Contract: always two decimal places as string. */
	static String money(BigDecimal value) {
		return value.setScale(2, RoundingMode.HALF_UP).toPlainString();
	}

	private static String minPrice(List<ProductVariantResponse> variants) {
		return variants.stream()
				.map(ProductVariantResponse::price)
				.map(BigDecimal::new)
				.min(Comparator.naturalOrder())
				.map(ProductCatalogAssembler::money)
				.orElse("0.00");
	}
}
