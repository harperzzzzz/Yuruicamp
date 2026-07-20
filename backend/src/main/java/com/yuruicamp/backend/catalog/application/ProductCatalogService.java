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
 * Public catalog use-cases (B-1 list, B-2 detail, B-3 pagination and sorting).
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
 *   <li><b>B-3 分頁（已完成）</b>：{@link #listProducts(int, int, String)} 接收
 *       {@code page,size,sort}，Repository 使用 {@code Pageable}，Controller 透過
 *       {@code ApiResponse.ok(data, meta)} 回傳分頁資訊。</li>
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
		// 用途：透過建構式注入商品、圖片 Repository 與 DTO 組裝器。
		// 核心重點：所有相依物件均為必要依賴，交由 Spring 建立並管理此 Service。
		this.productRepository = productRepository;
		this.equipmentImageRepository = equipmentImageRepository;
		this.assembler = assembler;
	}

	/**
	 * B-1: GET /api/products
	 */
	@Transactional(readOnly = true)
	public List<ProductResponse> listProducts() {
		// 用途：取得未分頁的公開商品清單。
		// 核心重點：批次載入主圖、排除沒有 active 規格的商品，最後依商品 ID 穩定排序。
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
		// 用途：依頁碼、筆數及排序條件取得公開商品清單與分頁資訊。
		// 核心重點：先分頁查 ID，再一次載入完整關聯資料，並依 ID 頁面的順序還原結果。
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
		// 用途：把 API 的「欄位,方向」字串轉成 Spring Data Sort。
		// 核心重點：只允許 id、name 與 asc、desc，避免任意欄位被帶入資料庫排序。
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
		// 用途：建立統一的排序參數驗證例外。
		// 核心重點：使用 VALIDATION_ERROR，並在訊息中列出允許格式供呼叫端修正。
		return new BusinessException(
				ErrorCode.VALIDATION_ERROR,
				"Invalid sort: " + sort + ". Allowed values: id,asc|desc; name,asc|desc");
	}

	private PageMeta toMeta(Page<?> page) {
		// 用途：把 Spring Data Page 的分頁狀態轉成 API 契約的 PageMeta。
		// 核心重點：僅輸出頁碼、每頁筆數、總筆數與總頁數，不暴露框架物件。
		return new PageMeta(page.getNumber(), page.getSize(), page.getTotalElements(), page.getTotalPages());
	}

	/**
	 * 用途：封裝分頁商品資料與分頁中繼資訊。
	 * 核心重點：以不可變 record 保證 Service 回傳的資料與 meta 成對存在。
	 */
	public record PagedProducts(List<ProductResponse> data, PageMeta meta) {
	}

	/**
	 * B-2: GET /api/products/{id}
	 */
	@Transactional(readOnly = true)
	public ProductResponse getProduct(String id) {
		// 用途：依商品 ID 取得單一公開商品詳情。
		// 核心重點：商品不存在、不可販售或沒有 active 規格時，一律視為 NOT_FOUND。
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
		// 用途：批次載入一批商品所屬器材的主圖，回傳「器材 ID → 圖片網址」對照表。
		// 核心重點：先去除重複 ID，再用單次查詢避免 N+1；重複圖片資料保留第一筆。
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
