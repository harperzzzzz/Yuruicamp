package com.yuruicamp.backend.branch.application;

import java.util.List;

import com.yuruicamp.backend.branch.api.BranchResponse;
import com.yuruicamp.backend.branch.domain.Branch;
import com.yuruicamp.backend.branch.infrastructure.BranchRepository;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 用途：提供公開門市列表用例。
 * 核心重點：Service 負責 Entity 到 DTO 的轉換，Controller 不接觸資料庫物件。
 */
@Service
public class BranchCatalogService {

	private final BranchRepository branchRepository;

	public BranchCatalogService(BranchRepository branchRepository) {
		this.branchRepository = branchRepository;
	}

	@Transactional(readOnly = true)
	public List<BranchResponse> listBranches() {
		// 公開 API 只回啟用門市；停用門市改由 /api/admin/branches 查看（ADM-W2-07）。
		return branchRepository.findAllByActiveTrueOrderByIdAsc().stream()
				.map(this::toResponse)
				.toList();
	}

	private BranchResponse toResponse(Branch branch) {
		return new BranchResponse(
				branch.getId(),
				branch.getName(),
				branch.getAddress(),
				branch.getPhone(),
				branch.getLatitude(),
				branch.getLongitude(),
				branch.getMapQuery(),
				branch.getBusinessHours(),
				branch.getImageUrl());
	}
}
