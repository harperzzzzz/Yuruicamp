package com.yuruicamp.backend.branch.api;

import java.util.List;

import com.yuruicamp.backend.branch.application.BranchCatalogService;
import com.yuruicamp.backend.common.api.ApiResponse;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 用途：提供不需登入的門市公開讀取端點。
 * 核心重點：Controller 只負責呼叫 Service 並包裝共用 Envelope。
 */
@RestController
@RequestMapping("/api/branches")
@Tag(name = "Branches", description = "公開門市資料")
public class BranchController {

	private final BranchCatalogService branchCatalogService;

	public BranchController(BranchCatalogService branchCatalogService) {
		this.branchCatalogService = branchCatalogService;
	}

	@GetMapping
	@Operation(summary = "取得全部門市")
	public ApiResponse<List<BranchResponse>> list() {
		return ApiResponse.ok(branchCatalogService.listBranches());
	}
}
