# 會員本人配送地址

## 用途

讓 Firebase 新會員不依賴前端 Mock JSON，也能把會員中心的預設配送地址保存至 PostgreSQL。

## 流程

1. Security Filter 驗證 Firebase Token，建立 `CustomerPrincipal`。
2. Controller 只把 principal 的 `customerId` 傳入 Service。
3. Service 鎖定會員資料，確認 Request Email 與會員 Email 相同。
4. 已有預設地址就更新，沒有就新增；每位會員仍由 partial unique index 保證最多一筆預設地址。
5. Repository join `customers` 投影 Email 後回傳 canonical DTO。

## 規則

- 不接受前端傳入任意 `customerId`。
- 不新增第二套 Bearer／HTTP 實作。
- Schema 沿用 `recipient_name` 與單一 `address_line`；前端姓／名、鄉鎮與地址補充只在 facade 邊界合併。
- Email 不重複寫入地址表，也不可由地址表單改變登入信箱。

## 驗證結果

- `MemberShippingAddressServiceTest`：新增、更新預設地址及 Email 不一致拒絕，共 3 項通過。
- Maven 編譯與測試成功；PostgreSQL 人工驗證依測試文件執行。
