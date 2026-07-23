/**
 * Rental domain — admin write for equipment_items → rental_skus → rental_sku_variants（W2-03）。
 *
 * <p>只管「租借 SKU／規格」主檔本身，**不**寫庫存（on-hand）、**不**寫 rental_listings／
 * campground 定價（那是 {@code W2-04}）。庫存讀寫仍歸 G-3 {@code inventory} 模組。</p>
 *
 * <p>Contract: {@code docs/api/admin-api-contract.md} §6.5</p>
 * <p>Checklist: {@code plans/admin-post-g6/w2/ADM-W2-03-rental-skus.md}</p>
 */
package com.yuruicamp.backend.rental;
