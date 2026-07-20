package com.yuruicamp.backend.catalog.application;

import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import com.yuruicamp.backend.catalog.api.ProductResponse;
import com.yuruicamp.backend.catalog.domain.EquipmentImage;
import com.yuruicamp.backend.catalog.domain.Product;
import com.yuruicamp.backend.catalog.infrastructure.EquipmentImageRepository;
import com.yuruicamp.backend.catalog.infrastructure.ProductRepository;
import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Public catalog use-cases (B-1 list, B-2 detail).
 *
 * <h2>給新手：這支 Service 在做什麼？</h2>
 * <ol>
 *   <li>從 Repository 讀「可販售」商品（active product + active equipment）</li>
 *   <li>只保留 active variants；沒有規格的商品直接丟掉</li>
 *   <li>查主圖（equipment_images.sort_order = 0）</li>
 *   <li>組裝成 Product API Contract v0.1 的 DTO</li>
 * </ol>
 *
 * <h2>如何自己完成 B-3～B-5？（複製這套流程）</h2>
 * <ul>
 *   <li><b>B-3 分頁</b>：把 {@link #listProducts()} 改成接收 {@code page,size,sort}，
 *       Repository 改用 {@code Pageable}，並在 {@code ApiResponse.ok(data, meta)} 放
 *       {@code { page, size, totalElements, totalPages }}。契約要先升到 v0.2 再加 meta。</li>
 *   <li><b>B-4 篩選</b>：加 query 參數（category／brand／minPrice／maxPrice），
 *       在 JPQL {@code where} 加條件，或先查出再在 memory filter（資料少時可接受）。
 *       篩選參數名稱要寫進 {@code docs/api/product-api-contract.md}。</li>
 *   <li><b>B-5 庫存</b>：不要塞進本契約亂加欄位；另開讀模型或升版契約，
 *       可查 {@code product_stock_summary}／{@code sellable_product_variants}。</li>
 *   <li><b>B-7 branches</b>：新建 {@code branch} package，照
 *       Controller → Service → Repository → DTO 四層，公開 GET 即可。</li>
 * </ul>
 */
@Service
public class ProductCatalogService {

	private final ProductRepository productRepository;
	private final EquipmentImageRepository equipmentImageRepository;
	private final ProductCatalogAssembler assembler;

	public ProductCatalogService(
			ProductRepository productRepository,
			EquipmentImageRepository equipmentImageRepository,
			ProductCatalogAssembler assembler) {
		this.productRepository = productRepository;
		this.equipmentImageRepository = equipmentImageRepository;
		this.assembler = assembler;
	}

	/**
	 * B-1: GET /api/products
	 */
	@Transactional(readOnly = true)
	public List<ProductResponse> listProducts() {
		List<Product> products = productRepository.findAllActiveForCatalog();
		Map<String, String> images = loadMainImages(products);

		return products.stream()
				.map(p -> assembler.toResponse(p, images))
				.filter(dto -> !dto.variants().isEmpty())
				.sorted(Comparator.comparing(ProductResponse::id))
				.toList();
	}

	/** B-3: GET /api/products?page=&size=&sort= (Contract v0.2). */
	@Transactional(readOnly = true)
	public PagedProducts listProducts(int page, int size, String sort) {
		Page<String> idPage = productRepository.findActiveIdsForCatalog(PageRequest.of(page, size, toSort(sort)));
		if (idPage.isEmpty()) {
			return new PagedProducts(List.of(), toMeta(idPage));
		}

		Map<String, Product> productById = productRepository.findAllByIdInForCatalog(idPage.getContent()).stream()
				.collect(Collectors.toMap(Product::getId, product -> product));
		List<Product> productsInPageOrder = idPage.getContent().stream()
				.map(productById::get)
				.filter(Objects::nonNull)
				.toList();
		Map<String, String> images = loadMainImages(productsInPageOrder);
		List<ProductResponse> data = productsInPageOrder.stream()
				.map(product -> assembler.toResponse(product, images))
				.filter(dto -> !dto.variants().isEmpty())
				.toList();
		return new PagedProducts(data, toMeta(idPage));
	}

	private Sort toSort(String sort) {
		String[] parts = sort.split(",", -1);
		if (parts.length != 2) {
			throw invalidSort(sort);
		}
		String property = switch (parts[0]) {
			case "id" -> "id";
			case "name" -> "item.name";
			default -> throw invalidSort(sort);
		};
		try {
			return Sort.by(Sort.Direction.fromString(parts[1]), property);
		} catch (IllegalArgumentException ex) {
			throw invalidSort(sort);
		}
	}

	private BusinessException invalidSort(String sort) {
		return new BusinessException(
				ErrorCode.VALIDATION_ERROR,
				"Invalid sort: " + sort + ". Allowed values: id,asc|desc; name,asc|desc");
	}

	private PageMeta toMeta(Page<?> page) {
		return new PageMeta(page.getNumber(), page.getSize(), page.getTotalElements(), page.getTotalPages());
	}

	public record PagedProducts(List<ProductResponse> data, PageMeta meta) {
	}

	/**
	 * B-2: GET /api/products/{id}
	 */
	@Transactional(readOnly = true)
	public ProductResponse getProduct(String id) {
		Product product = productRepository.findActiveByIdForCatalog(id)
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Product not found: " + id));

		String image = equipmentImageRepository.findByItemIdAndSortOrder(product.getItem().getId(), 0)
				.map(EquipmentImage::getUrl)
				.orElse(null);

		ProductResponse dto = assembler.toResponse(product, image);
		if (dto.variants().isEmpty()) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Product not found: " + id);
		}
		return dto;
	}

	private Map<String, String> loadMainImages(List<Product> products) {
		Set<String> itemIds = products.stream()
				.map(p -> p.getItem().getId())
				.filter(Objects::nonNull)
				.collect(Collectors.toSet());
		if (itemIds.isEmpty()) {
			return Map.of();
		}
		return equipmentImageRepository.findByItemIdInAndSortOrder(itemIds, 0).stream()
				.collect(Collectors.toMap(EquipmentImage::getItemId, EquipmentImage::getUrl, (a, b) -> a));
	}
}
