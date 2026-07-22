# E-1 Booking 公開讀

## 用途

提供前台讀取有效營區、營位、租借裝備、預約政策與公休規則，不需要登入。

## 流程

```text
GET /api/booking/**
→ BookingPublicController
→ BookingPublicService
→ PostgreSQL read query
→ Contract v0.3 DTO + Envelope
```

## 規則

- 營區只回 `active=true`；詳情只含 active zones。
- 租借裝備以 `active_rental_listing_view` 為起點，並確認營區與 rental location 有效。
- 不輸出前端 Mock `stock`；租借庫存以 PostgreSQL 為真相。
- 金額以 `BigDecimal` 處理，輸出固定兩位字串。
- Policy 固定讀取 `id=1` 與 occupying statuses。
- 不存在或停用的營區詳情回 `404 NOT_FOUND`。

## 驗證結果

- 完整 schema + dev seed 在獨立 PostgreSQL 初始化成功。
- `BookingPublicIntegrationTest` 共 7 項，0 失敗、0 略過。
- 已驗證公開 Security、active 過濾、金額格式、404、必填參數、policy 與 closures。
- 暫存 PostgreSQL 已移除，未修改既有開發資料卷。
