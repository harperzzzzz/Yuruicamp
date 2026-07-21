# Branch API Contract（v0.1）

| 欄位 | 內容 |
|------|------|
| **狀態** | Locked（B-7 已實作） |
| **日期** | 2026-07-21 |
| **版本** | 0.1 |

## 端點

`GET /api/branches` 為公開端點，不需要 Token。成功時回傳共用 Envelope，`data` 為依 `id` 遞增排序的門市陣列。

## Branch 欄位

| JSON | 型別 | DB |
|------|------|----|
| `id` | string | `branches.id` |
| `name` | string | `name` |
| `address` | string | `address` |
| `phone` | string | `phone` |
| `latitude` | number \| null | `latitude` |
| `longitude` | number \| null | `longitude` |
| `mapQuery` | string \| null | `map_query` |
| `businessHours` | string | `business_hours` |
| `imageUrl` | string \| null | `image_url` |

舊 Mock 的 `features` 不存在於資料庫，因此不屬於本契約。
