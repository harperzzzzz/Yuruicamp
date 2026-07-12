# branches 是門市主檔
# branch_features 是門市提供的服務／特色清單

## OneToMany
* branches (1) < branch_features (N)
一間門市可有多個特色；每個特色只屬於一間門市。

1. branches 
id  唯一識別碼，例如 branch-001
name
address
phone
hours 分店營業時段
`image (AI應該有誤會，這個是合作營地 可能?)`
latitude 緯度
longitude 經度
map_query 地圖搜尋字串，沒有精準位置時提供協助(專題位置都寫死的可刪 可不刪)
`description (至少網頁和後台沒有顯示過)`

*使用網頁: pages/branches.html*
## Note : 沒有針對分店做過詳細規劃，基本上資料表不會太詳細，要完善也是專案大致完成時。但是整體沒有錯誤。


2. branch_features：門市特色詳細
### id (可考慮做branch_id, feature 複合鍵，有id 的好處是未來可以引用給其他表使用)
branch_id 所屬門市 ID
feature 特色，「裝備租借」、「停車場」、「寵物友善」

*使用網頁: pages/branches.html*
## Note : 為符合第一正規化分割資料表，有相同特色可以經過此表


## example :
branches
| id | name | address | phone | hours |
|---|---|---|---|---|
| `branch-001` | 台北中山店 | 台北市中山區 A 路 1 號 | `02-1234-5678` | `10:00-21:00` |
| `branch-002` | 台中西屯店 | 台中市西屯區 B 路 2 號 | `04-2345-6789` | `10:00-21:00` |
| `branch-003` | 高雄前鎮店 | 高雄市前鎮區 C 路 3 號 | `07-3456-7890` | `11:00-20:00` |

branch_features
| id | branch_id | feature |
|---:|---|---|
| `1` | `branch-001` | 裝備租借 |
| `2` | `branch-001` | 停車場 |
| `3` | `branch-001` | 寵物友善 |
| `4` | `branch-002` | 裝備租借 |
| `5` | `branch-002` | 維修服務 |
| `6` | `branch-003` | 停車場 |
| `7` | `branch-003` | 無障礙空間 |
| `8` | `branch-003` | 試搭帳篷區 |