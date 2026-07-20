# 規格書：Frontend Lift & Shift（方案 B · Phase 1）

| 欄位 | 內容 |
|------|------|
| **文件狀態** | 定案（Ready to implement） |
| **版本** | 1.0 |
| **日期** | 2026-07-18 |
| **目標** | 接 Spring Boot 前，把前端整包收進 `frontend/`，改善找檔、劃清前後端邊界 |
| **策略** | Lift & Shift：整包上移，**內部相對結構不變** |
| **明確不做** | 不改 `backend/`；不抽 `shared/`；不改名 `storefront/`；不改業務邏輯／UI |

---

## 1. 背景與動機

### 1.1 問題

1. Repo 根目錄同時放主站、booking、admin、文件、後端，找檔困難。
2. 頁面已大致穩定，希望在接 Spring Boot API 前把目錄邊界釐清。

### 1.2 定案策略

- 採用方案 B：新增 `frontend/`，前端整包搬入。
- 第一天只搬家，不重構內部路徑（主站仍用 `pages/`、`js/`、`css/`，不改名 storefront）。
- npm／Vite 工具鏈放在 `frontend/`。
- `color/` 併入前端；`userguide.md` 留在 repo 根並更新路徑說明。

### 1.3 成功後的心智模型

```text
Yuruicamp/
├── backend/     → 只放 Spring Boot
├── frontend/    → 只放三前端 + mock data + Vite
├── docs/        → 規格／schema（前後端共用閱讀）
├── plans/       → 規劃草稿
└── docker-compose.yml + .env*  → 本機 DB 基礎設施
```

---

## 2. 範圍（In / Out）

### 2.1 In Scope

| 項目 | 說明 |
|------|------|
| 建立 `frontend/` | 新目錄 |
| 搬移前端資產 | 見 §3 搬移清單 |
| 搬移 npm／Vite／lint | `package.json`、lock、vite、eslint、stylelint、prettier 設定 |
| 更新開發文件入口 | README 最上方「專案地圖」+ 啟動指令改為 `cd frontend` |
| 驗證能跑 | smoke、validate:data、build、手動三端抽查 |
| 修正因 cwd 改變而失效的說明 | 僅限文件與少數硬編碼（若有） |

### 2.2 Out of Scope

| 項目 | 原因 |
|------|------|
| 修改 `backend/**` | 已定案不動 |
| 改名 `pages/` → `storefront/` | Phase 3 可選 |
| 抽出 `frontend/shared/` | Phase 3 可選 |
| 改業務功能、UI、假資料內容 | 純架構搬家 |
| 接真 API／改 `API_BASE_URL` 行為 | Phase 2 |
| 刪除或合併重複 docs | 另開文件清理任務 |

### 2.3 Do Not Touch（紅線）

- `backend/**`
- `docker-compose.yml` 內對 `docs/latest_schema.sql` 的掛載路徑
- `.env` / `.env.example` 的語意（留在 repo 根）
- 三前端內部 HTML／JS 相對引用（Phase 1 預期不必改）

---

## 3. 目標目錄結構

```text
Yuruicamp/
├── backend/                          # 不動
├── frontend/                         # NEW — Vite / npm 根
│   ├── index.html
│   ├── pages/
│   ├── js/
│   ├── css/
│   ├── components/
│   ├── booking/
│   ├── admin/
│   ├── data/
│   ├── assets/
│   ├── src/
│   ├── tests/
│   ├── color/
│   ├── package.json
│   ├── package-lock.json
│   ├── vite.config.js
│   ├── eslint.config.js
│   ├── stylelint.config.cjs
│   └── .prettierrc.json
│
├── docs/
├── plans/
├── thoughts/
├── .agents/
├── docker-compose.yml
├── .env / .env.example
├── .gitignore
├── README.md
├── changelog.md
└── userguide.md
```

### 3.1 必須搬入 `frontend/` 的目錄

`admin/`、`booking/`、`pages/`、`js/`、`css/`、`components/`、`data/`、`assets/`、`src/`、`tests/`、`color/`

### 3.2 必須搬入 `frontend/` 的檔案

`index.html`、`package.json`、`package-lock.json`、`vite.config.js`、`eslint.config.js`、`stylelint.config.cjs`、`.prettierrc.json`

### 3.3 必須留在 repo 根

`backend/`、`docs/`、`plans/`、`thoughts/`、`.agents/`、`docker-compose.yml`、`.env*`、`.gitignore`、`README.md`、`changelog.md`、`userguide.md`

---

## 4. 決策記錄

| ID | 決策 | 選擇 |
|----|------|------|
| D1 | npm 位置 | `frontend/package.json`；`cd frontend && npm run dev` |
| D2 | `color/` | 搬入 `frontend/color/` |
| D3 | `userguide.md` | 暫留 repo 根；更新路徑 |
| D4 | `docs/` | 留在 repo 根 |
| D5 | `plans/`、`thoughts/`、`.agents/` | 留在 repo 根 |
| D6 | Phase 1 是否抽 shared / 改名 storefront | 否 |
| D7 | `backend/` | 完全不動 |

---

## 5. 為什麼多數程式碼不用改

| 現況 | 搬移後 | 相對關係 |
|------|--------|----------|
| `booking/pages` → `../../js` | `frontend/booking/pages` → `../../js` | 相同 |
| `admin/dashboard` → `../js` | `frontend/admin/dashboard` → `../js` | 相同 |
| `admin/scripts` → `__dirname/../../data` | `frontend/admin/scripts` → `frontend/data` | 相同 |
| `tests/smoke.mjs` 的 `rootDir = 上一層` | `frontend/tests` → `frontend/` | 相同 |
| `DataPaths` 的 `/data/...` | Vite root = `frontend/` | 仍正確 |

關鍵約定：Vite 與 npm 的 working directory 必須是 `frontend/`。

---

## 6. 驗收標準（Definition of Done）

| # | 檢查項 |
|---|--------|
| 1 | 根目錄無散落前端目錄；僅 `frontend/` 內有三前端與 `data/` |
| 2 | `git diff --name-only -- backend` 為空 |
| 3 | `docker-compose.yml` 仍指向 `./docs/latest_schema.sql` |
| 4 | `cd frontend && npm run smoke` 通過 |
| 5 | `cd frontend && npm run validate:data` 通過 |
| 6 | `cd frontend && npm run build` 通過 |
| 7 | 手動三端抽查通過（主站／booking／admin／`/data` JSON） |
| 8 | 本規格文件已存在 |
| 9 | README 置頂專案地圖 + `cd frontend` 啟動說明已更新 |
| 10 | userguide 樹狀圖與路徑已對齊新結構 |
| 11 | Diff 主體為搬移＋文件；無業務邏輯／JSON 內容大改 |

---

## 7. 後續（不在本次）

### Phase 2 — 接 API 軟整理

- 統一 `js/config.js`：`USE_MOCK`、`API_BASE_URL`
- 頁面禁止新增直接 `fetch('/data/...')`；一律走 API 層

### Phase 3 — 可選美化

- `pages/js/css/components` → `frontend/storefront/`
- 抽出 `frontend/shared/`

沒有 Phase 1 驗收通過前，不做 Phase 2／3。
