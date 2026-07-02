# HomePage Spec

**狀態：** 草稿
**類別：** 頁面
**設計參考：** 無 - 源自現有原始檔 `pages/home.html`

---

## 概述
買家首頁，包含首頁橫幅、輪播圖、新品展示和暢銷商品展示。用於廣泛發現和商品輸入。首頁橫幅和商品展示應保持視覺豐富性，但並非獨立的行銷落地頁系統。

## TypeScript Interface

```typescript
export type PageShellVariant = 'main' | 'booking' | 'admin';

export interface NavigationPayload {
  href: string;
  label: string;
  source: 'HomePage';
}

export interface UserSummary {
  id: string;
  displayName: string;
  email?: string;
  avatarUrl?: string;
}

export interface ContentBlock {
  id: string;
  title: string;
  description?: string;
  imageUrl?: string;
  href?: string;
}

export interface HomePageData {
  title: string;
  sourcePath: 'pages/home.html';
  keyAreas: string[];
  blocks?: ContentBlock[];
}

export interface HomePageProps {
  // Required props
  shell: 'main'; // Page shell variant used by this source page.
  data: HomePageData; // Initial page content, records, or mounted section metadata.

  // Optional props
  currentUser?: UserSummary | null; // Logged-in user context. default: null
  loading?: boolean; // Shows skeleton or loading state. default: false
  errorMessage?: string | null; // User-facing error message. default: null

  // Event handlers
  onNavigate?: (payload: NavigationPayload) => void;
  onRefresh?: (sourcePath: 'pages/home.html') => void;

  // Render props / slots
  headerSlot?: React.ReactNode;
  footerSlot?: React.ReactNode;
  actionSlot?: React.ReactNode;
}
```

## Variants

| 變體 | 屬性 | 描述 |
|---------|-------|-------------|
| 預設 | `shell="main"` | 符合目前 `pages/home.html` 的版面配置和共用 CSS。 |
| 載入中 | `loading={true}` | 在資料或部分內容載入時保持頁面框架穩定。 |
| 空 | `data.blocks=[]` | 顯示一個有用的空狀態，而不會折疊頁面框架。 |
| 錯誤 | `errorMessage="..."` | 顯示本地化的錯誤訊息和重試路徑。 |

## States

| 狀態 | 觸發 | 視覺變化 |
|-------|---------|---------------|
| 預設 | 頁面已載入 | 主要內容區域以 Yuruicamp 綠色標記和現有間距渲染。 |
| 懸停 | 互動式卡片、行、標籤或按鈕懸停 | 邊框、陰影或背景變化，佈局不變。 |
| 啟動 | 選取標籤、篩選器、導覽項目或表格行 | 使用 `--yui-primary` 或 `--yui-primary-soft` 加上文字標籤。 |
| 停用 | 操作不可用或表單未填寫 | 降低不透明度，指標被遮擋，元素尺寸不變。 |
| 載入中 | `loading={true}` | 骨架行、停用的提交按鈕或穩定的佔位符區塊。 |
| 錯誤 | `errorMessage` 存在 | 在失敗區域附近顯示內聯警告，並在可能的情況下重試操作。 |

## Design Tokens

```typescript
const spacing = {
  pagePadding: 'clamp(24px, 5vw, 64px)',
  sectionGap: '24px',
  controlGap: '8px',
};

const typography = {
  bodyFontSize: '16px',
  bodyLineHeight: '1.5',
  headingWeight: '700',
};

const colors = {
  background: 'var(--yui-bg)',
  surface: 'var(--yui-surface)',
  text: 'var(--yui-text)',
  mutedText: 'var(--yui-text-muted)',
  border: 'var(--yui-border)',
  focus: 'var(--yui-primary)',
};
```

## Usage Examples

### Basic

```tsx
<HomePage
  shell="main"
  data={{
    title: 'HomePage',
    sourcePath: 'pages/home.html',
    keyAreas: 'heroBanner, newProductsRow, bestsellerProductsRow'.split(', '),
  }}
/>
```

### With Optional Props

```tsx
<HomePage
  shell="main"
  data={homepageData}
  currentUser={currentUser}
  loading={isLoading}
  errorMessage={errorMessage}
  onNavigate={(payload) => router.push(payload.href)}
  onRefresh={(sourcePath) => reloadPageData(sourcePath)}
/>
```

## 輔助功能

- **角色：** `main` 用於主要內容區域；嵌套控制項優先使用原生語意元素。
- **鍵盤：** Tab 鍵順序遵循視覺順序。回車鍵/空白鍵可啟動按鈕、選項卡、手風琴標題和行操作。
- **ARIA 屬性：** 使用 `aria-current` 表示目前導航，`aria-expanded` 表示可折疊面板，`aria-describedby` 表示錯誤訊息。
- **焦點管理：** 模態框和側邊欄面板會捕捉焦點，並在關閉後將焦點返回到開啟面板。
- **螢幕閱讀器：** 以文字形式朗讀頁面標題、載入/錯誤狀態、選定的篩選器和狀態標籤。

## 實作說明

- 原始檔：`pages/home.html`。
- 分享 CSS 原始檔：`css/main.css`。
- 共用元件：components/header.partial、components/footer.partial。
- 主要 UI 區域：heroBanner、newProductsRow、bestsellerProductsRow。
- 在產生新的 UI 之前，請使用 `docs/ai-style-sheet.md` 和 `docs/ai-style-tokens.css`。
- 待解決的問題：沒有 Figma 參考，因此現有程式碼是設計的真實來源。
- 實作此規格時，請勿取代現有的 shell、儲存鍵、模擬資料契約或部分載入器模式。

## 驗收標準

- [ ] 所有變體都能正確渲染
- [ ] 所有狀態在視覺上清晰可辨
- [ ] 鍵盤導航功能正常
- [ ] 螢幕閱讀器播報正確
- [ ] 設計標記與 Yuruicamp AI 樣式表相符
- [ ] 單元測試或冒煙測試涵蓋了必需的屬性和主要事件
