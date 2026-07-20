package com.yuruicamp.backend.catalog.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * 用途：以實際 PostgreSQL 與 HTTP Controller 驗收商品分頁、排序及錯誤 Envelope。
 * 核心重點：測試直接比較資料庫 ORDER BY 結果，避免只驗證 Java 記憶體排序。
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
class ProductPaginationIntegrationTest {

	private static final String SELLABLE_FROM_SQL = """
			from products p
			join equipment_items i on i.id = p.item_id
			where p.status = 'active'
			  and i.active = true
			  and exists (
			      select 1 from product_variants v
			      where v.product_id = p.id and v.status = 'active'
			  )
			""";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JdbcTemplate jdbcTemplate;

	@Test
	void nonEmptyPagesDoNotOverlapOrLoseRows() throws Exception {
		JsonNode firstPage = getProducts(0, 5, "id,asc");
		JsonNode secondPage = getProducts(1, 5, "id,asc");
		JsonNode allProducts = getProducts(0, 100, "id,asc");

		List<String> firstIds = values(firstPage.path("data"), "id");
		List<String> secondIds = values(secondPage.path("data"), "id");
		List<String> combined = new ArrayList<>(firstIds);
		combined.addAll(secondIds);
		Set<String> overlap = new HashSet<>(firstIds);
		overlap.retainAll(secondIds);

		assertFalse(firstIds.isEmpty(), "第一頁必須有實際商品資料");
		assertFalse(secondIds.isEmpty(), "第二頁必須有實際商品資料");
		assertTrue(overlap.isEmpty(), "page=0 與 page=1 不得出現重複商品");
		assertEquals(values(allProducts.path("data"), "id").subList(0, combined.size()), combined,
				"前兩頁合併後必須與完整排序的前段資料一致");
		assertEquals(allProducts.path("meta").path("totalElements").asLong(),
				firstPage.path("meta").path("totalElements").asLong());
	}

	@Test
	void idAscendingAndDescendingMatchPostgreSqlOrder() throws Exception {
		assertApiOrderMatchesDatabase("id,asc", "order by p.id asc", "id", "id");
		assertApiOrderMatchesDatabase("id,desc", "order by p.id desc", "id", "id");
	}

	@Test
	void nameAscendingAndDescendingMatchPostgreSqlOrder() throws Exception {
		assertApiOrderMatchesDatabase("name,asc", "order by i.name asc", "name", "name");
		assertApiOrderMatchesDatabase("name,desc", "order by i.name desc", "name", "name");
	}

	@Test
	void invalidPageAndSizeReturnValidationEnvelope() throws Exception {
		assertValidationError("page", "-1");
		assertValidationError("size", "0");
		assertValidationError("size", "101");
	}

	@Test
	void invalidSortFormatsReturnValidationEnvelope() throws Exception {
		assertSortValidationError("id");
		assertSortValidationError("id,xxx");
		assertSortValidationError("price,asc");
	}

	@Test
	void pageBeyondLastReturnsEmptyDataAndCorrectMeta() throws Exception {
		JsonNode firstPage = getProducts(0, 5, "id,asc");
		long totalElements = firstPage.path("meta").path("totalElements").asLong();
		int totalPages = firstPage.path("meta").path("totalPages").asInt();
		JsonNode beyond = getProducts(totalPages + 10, 5, "id,asc");

		assertTrue(beyond.path("data").isArray());
		assertEquals(0, beyond.path("data").size());
		assertEquals(totalPages + 10, beyond.path("meta").path("page").asInt());
		assertEquals(5, beyond.path("meta").path("size").asInt());
		assertEquals(totalElements, beyond.path("meta").path("totalElements").asLong());
		assertEquals(totalPages, beyond.path("meta").path("totalPages").asInt());
	}

	private void assertApiOrderMatchesDatabase(
			String apiSort,
			String sqlOrder,
			String databaseColumn,
			String apiField) throws Exception {
		String sqlColumn = "name".equals(databaseColumn) ? "i.name" : "p.id";
		List<String> expected = jdbcTemplate.queryForList(
				"select " + sqlColumn + " " + SELLABLE_FROM_SQL + sqlOrder,
				String.class);
		JsonNode response = getProducts(0, 100, apiSort);
		List<String> actual = values(response.path("data"), apiField);
		assertFalse(expected.isEmpty(), "PostgreSQL 必須有可供驗收的商品資料");
		assertEquals(expected, actual, apiSort + " 必須保持 PostgreSQL 的排序結果");
	}

	private void assertValidationError(String parameter, String value) throws Exception {
		mockMvc.perform(get("/api/products").param(parameter, value))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.success").value(false))
				.andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
				.andExpect(jsonPath("$.error.message").isNotEmpty())
				.andExpect(jsonPath("$.error.details").isArray());
	}

	private void assertSortValidationError(String sort) throws Exception {
		mockMvc.perform(get("/api/products").param("sort", sort))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.success").value(false))
				.andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
				.andExpect(jsonPath("$.error.message").value(org.hamcrest.Matchers.containsString("Invalid sort")));
	}

	private JsonNode getProducts(int page, int size, String sort) throws Exception {
		MvcResult result = mockMvc.perform(get("/api/products")
						.param("page", Integer.toString(page))
						.param("size", Integer.toString(size))
						.param("sort", sort))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.success").value(true))
				.andExpect(jsonPath("$.data").isArray())
				.andExpect(jsonPath("$.meta.page").value(page))
				.andExpect(jsonPath("$.meta.size").value(size))
				.andReturn();
		return objectMapper.readTree(result.getResponse().getContentAsByteArray());
	}

	private static List<String> values(JsonNode array, String field) {
		List<String> values = new ArrayList<>();
		array.forEach(node -> values.add(node.path(field).asText()));
		return values;
	}
}
