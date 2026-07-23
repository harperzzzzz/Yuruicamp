package com.yuruicamp.backend.branch.infrastructure;

import java.util.List;

import com.yuruicamp.backend.branch.domain.Branch;

import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 用途：依固定門市 ID 順序讀取全部門市。
 * 核心重點：公開列表的排序由資料庫完成，確保每次回應一致。
 */
public interface BranchRepository extends JpaRepository<Branch, String> {

	List<Branch> findAllByOrderByIdAsc();

	/** 公開 API 只回啟用門市（ADM-W2-07）。 / Public API only returns active branches. */
	List<Branch> findAllByActiveTrueOrderByIdAsc();
}
