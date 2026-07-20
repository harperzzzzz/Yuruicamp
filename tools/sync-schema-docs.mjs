/**
 * Generate docs/schema-enums.md and docs/database-schema-guide.md
 * from docs/latest_schema.sql (source of truth).
 *
 * Usage: node tools/sync-schema-docs.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const sqlPath = path.join(root, 'docs', 'latest_schema.sql');
const sql = fs.readFileSync(sqlPath, 'utf8');

function extractEnums(text) {
  const enums = [];
  const re = /CREATE TYPE public\.(\w+) AS ENUM \(\s*([\s\S]*?)\);/g;
  let m;
  while ((m = re.exec(text))) {
    const values = m[2]
      .split(',')
      .map((s) => s.replace(/['\s]/g, ''))
      .filter(Boolean);
    enums.push({ name: m[1], values });
  }
  return enums;
}

function extractViews(text) {
  const views = [];
  // Handle LF / CRLF after AS
  const re = /CREATE VIEW public\.(\w+) AS\r?\n([\s\S]*?);/g;
  let m;
  while ((m = re.exec(text))) {
    views.push({ name: m[1], body: m[2].trim() });
  }
  return views;
}

function extractTriggers(text) {
  const out = [];
  const re =
    /CREATE TRIGGER (\w+) ([\s\S]*?) ON public\.(\w+) FOR EACH ROW EXECUTE FUNCTION public\.(\w+)\(\);/g;
  let m;
  while ((m = re.exec(text))) {
    out.push({
      name: m[1],
      timing: m[2].replace(/\s+/g, ' ').trim(),
      table: m[3],
      fn: m[4],
    });
  }
  return out;
}

function extractFunctions(text) {
  const out = [];
  const re = /CREATE FUNCTION public\.(\w+)\(([^)]*)\) RETURNS ([^\n]+)\n/g;
  let m;
  while ((m = re.exec(text))) {
    out.push({ name: m[1], args: m[2].trim(), returns: m[3].trim() });
  }
  const seen = new Set();
  return out.filter((f) => (seen.has(f.name) ? false : seen.add(f.name)));
}

function extractTableBlocks(text) {
  const re = /CREATE TABLE public\.(\w+) \(\s*([\s\S]*?)\n\);/g;
  const tables = [];
  let m;
  while ((m = re.exec(text))) {
    const name = m[1];
    const lines = m[2]
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean);
    const cols = [];
    const pks = [];
    const uniques = [];
    const fks = [];
    for (const line of lines) {
      const clean = line.replace(/,$/, '');
      if (/^CONSTRAINT /i.test(clean)) {
        const pk = clean.match(/PRIMARY KEY \(([^)]+)\)/i);
        if (pk) pks.push(pk[1]);
        const uq = clean.match(/UNIQUE \(([^)]+)\)/i);
        if (uq) uniques.push(uq[1]);
        const fk = clean.match(
          /FOREIGN KEY \(([^)]+)\) REFERENCES public\.(\w+)\(([^)]+)\)/i,
        );
        if (fk) {
          fks.push({ cols: fk[1], refTable: fk[2], refCols: fk[3] });
        }
        continue;
      }
      const cm = clean.match(/^(\w+)\s+(.+)$/);
      if (!cm) continue;
      const col = cm[1];
      const rest = cm[2];
      const notNull = /NOT NULL/i.test(rest);
      let def = '—';
      const dm = rest.match(
        /DEFAULT\s+((?:'[^']*'|\([^)]*\)|[^\s,])+)/i,
      );
      if (dm) def = dm[1];
      let type = rest
        .replace(/DEFAULT\s+(?:'[^']*'|\([^)]*\)|[^\s,]+)/i, '')
        .replace(/\bNOT NULL\b/gi, '')
        .replace(/\bNULL\b/gi, '')
        .trim();
      type = type.split(/\s+CHECK\b/i)[0].trim().replace(/,$/, '').trim();
      cols.push({ col, type, notNull, def });
    }
    tables.push({ name, cols, pks, uniques, fks });
  }
  return tables;
}

function extractAlterFks(text) {
  const re =
    /ALTER TABLE ONLY public\.(\w+)\s+ADD CONSTRAINT \w+ FOREIGN KEY \(([^)]+)\) REFERENCES public\.(\w+)\(([^)]+)\)/g;
  const map = {};
  let m;
  while ((m = re.exec(text))) {
    (map[m[1]] = map[m[1]] || []).push({
      cols: m[2],
      refTable: m[3],
      refCols: m[4],
    });
  }
  return map;
}

function extractComments(text) {
  const tableComments = {};
  let m;
  const re = /COMMENT ON TABLE public\.(\w+) IS '([^']*)';/g;
  while ((m = re.exec(text))) tableComments[m[1]] = m[2];
  const viewComments = {};
  const re2 = /COMMENT ON VIEW public\.(\w+) IS '([^']*)';/g;
  while ((m = re2.exec(text))) viewComments[m[1]] = m[2];
  return { tableComments, viewComments };
}

const enums = extractEnums(sql);
const tables = extractTableBlocks(sql);
const alterFks = extractAlterFks(sql);
const views = extractViews(sql);
const triggers = extractTriggers(sql);
const functions = extractFunctions(sql);
const { tableComments, viewComments } = extractComments(sql);

for (const t of tables) {
  for (const fk of alterFks[t.name] || []) {
    if (!t.fks.some((x) => x.cols === fk.cols && x.refTable === fk.refTable)) {
      t.fks.push(fk);
    }
  }
}

tables.sort((a, b) => a.name.localeCompare(b.name));
views.sort((a, b) => a.name.localeCompare(b.name));

const enumDesc = {
  article_block_type: '文章內容區塊類型',
  auth_provider: '會員 OAuth 登入來源',
  booking_status: '預約狀態',
  closure_type: '營區公休類型',
  coupon_category: '優惠券分類',
  coupon_claim_status: '會員領券狀態',
  coupon_status: '優惠券主檔狀態',
  coupon_type: '折扣計算方式（與 coupons.discount_type 對應概念）',
  min_stock_target_type: '最低庫存目標領域',
  order_status: '訂單履約狀態',
  payment_method: '付款方式（≠ payment_status）',
  payment_status: '付款狀態（≠ payment_method）',
  product_status: '商品／規格上下架',
  customer_status: '會員狀態（軟刪用 deleted）',
  refund_status: '退款狀態',
  shipping_method: '配送方式',
};

// ---- schema-enums.md ----
let enumsMd = `# Yuruicamp Schema 枚舉（ENUM）

> **來源**：[\`docs/latest_schema.sql\`](./latest_schema.sql) 的 \`CREATE TYPE ... AS ENUM\`。  
> **用途**：前後端／Mock 對齊允許值時查這份；若與 SQL 不一致，以 SQL 為準。

| ENUM | 說明 | 允許值 |
| --- | --- | --- |
`;
for (const e of enums) {
  enumsMd += `| \`${e.name}\` | ${enumDesc[e.name] || '—'} | ${e.values.map((v) => `\`${v}\``).join(', ')} |\n`;
}
enumsMd += `
## 常見易混提醒

- \`payment_method\`（ecpay-credit / ecpay-atm / ecpay-cvs / ecpay-other / cod）**不是** \`payment_status\`（unpaid / paid / refunded）。
- 預約禁止 \`cod\`（\`ck_bookings_no_cod\`）；商城 COD 建立為 unpaid，履約後再標 paid。
- 商品下架用 \`product_status = inactive\`；\`disabled\` 僅用於 \`coupon_status\`。
- \`booking_status\` 含 \`completed\`，但 \`booking_policy_occupying_statuses\` 的 CHECK **只允許** \`pending\`、\`confirmed\` 占用營位。
- 會員無 password；\`auth_provider\` 僅 google / facebook / line；\`firebase_uid\` 綁定 Firebase。
`;
fs.writeFileSync(path.join(root, 'docs', 'schema-enums.md'), enumsMd, 'utf8');

// ---- database-schema-guide.md ----
const lines = [];
const push = (s = '') => lines.push(s);

push('# Yuruicamp 資料庫結構導覽');
push('');
push(
  '> 來源：[`docs/latest_schema.sql`](./latest_schema.sql)（現行可運作 DDL；已排除 archive／reconciliation 物件）。',
);
push(
  '> 欄位與約束以 SQL 為最終準則；本文件協助快速導覽。業務細節見 [`docs/database-documents/`](./database-documents/)。',
);
push('');
push('## 先說結論');
push('');
push('- **資料庫**：PostgreSQL 16（`jsonb`、`timestamp with time zone`、自訂 ENUM、dump 格式）。');
push(
  '- **Schema 定義方式**：資料庫優先（database-first）。**唯一建表來源**是 `docs/latest_schema.sql`。',
);
push(
  '- **套用方式**：`docker-compose.yml` 在**資料卷第一次建立**時掛載並執行此檔；之後改 schema 需 `docker compose down -v` 後重建（會清資料），或手動對空庫執行整檔。',
);
push(
  '- **不跑 Flyway／migration schema**：`latest_schema.sql` 註解已寫明本專案不以 migration 升級既有庫；後端 `application.properties` 亦註明須先套用此檔。',
);
push(
  '- **ORM**：Spring Data JPA 存在時，`spring.jpa.hibernate.ddl-auto=validate` 只驗證、不建表。',
);
push(
  `- **規模**：public **${tables.length}** 張業務表、**${views.length}** 個 View、**${enums.length}** 個 ENUM、**${functions.length}** 個函式、**${triggers.length}** 個 Trigger。無 \`migration\` schema。`,
);
push('');
push('## ERD（業務主幹）');
push('');
push('```mermaid');
push('erDiagram');
push('  CUSTOMERS ||--o{ ORDERS : places');
push('  ORDERS ||--|{ ORDER_ITEMS : contains');
push('  ORDERS ||--o{ ORDER_COUPONS : uses');
push('  COUPONS ||--o{ COUPON_CLAIMS : claimed_as');
push('  COUPON_CLAIMS ||--o| ORDER_COUPONS : consumed_by');
push('  PRODUCTS ||--|{ PRODUCT_VARIANTS : has');
push('  EQUIPMENT_ITEMS ||--o| PRODUCTS : sold_as');
push('  EQUIPMENT_ITEMS ||--o| RENTAL_SKUS : rented_as');
push('  CUSTOMERS ||--o{ BOOKINGS : makes');
push('  CAMPGROUNDS ||--|{ CAMPGROUND_ZONES : contains');
push('  BOOKINGS ||--|{ BOOKING_SELECTED_ZONES : selects');
push('  BOOKINGS ||--o{ BOOKING_SELECTED_RENTALS : adds');
push('  RENTAL_SKUS ||--|{ RENTAL_SKU_VARIANTS : has');
push('  RENTAL_SKU_VARIANTS ||--o{ RENTAL_LISTINGS : listed_at');
push('  INVENTORY_LOCATIONS ||--o{ INVENTORY_STOCKS : holds');
push('  INVENTORY_LOCATIONS ||--o{ RENTAL_SKU_VARIANT_STOCKS : holds');
push('  INVENTORY_MOVEMENTS ||--o{ STORE_INVENTORY_MOVEMENT_ITEMS : details');
push('  INVENTORY_MOVEMENTS ||--o{ RENTAL_INVENTORY_MOVEMENT_ITEMS : details');
push('  ORDER_ITEMS ||--o| REVIEWS : reviewed_by');
push('  ARTICLES ||--|{ ARTICLE_CONTENT_BLOCKS : contains');
push('  ADMIN_USERS ||--o{ ADMIN_USER_PERMISSIONS : grants');
push('  ADMIN_PERMISSIONS ||--o{ ADMIN_ROLE_PERMISSIONS : role_defaults');
push('  ORDERS ||--o{ PAYMENT_NOTIFICATIONS : notified_as');
push('  BOOKINGS ||--o{ PAYMENT_NOTIFICATIONS : notified_as');
push('```');
push('');
push(
  '這張圖只放主要路徑；完整 FK 見各表「關聯」。複合 FK（例如含 `inventory_domain`）避免商城與租借庫存混用。',
);
push('');
push('## 資料庫會主動做什麼？（函式與 Trigger）');
push('');
push('### 函式');
push('');
for (const f of functions) {
  push(`- \`public.${f.name}(...)\` → \`${f.returns}\``);
}
push('');
push('重點：');
push('');
push(
  '- `get_zone_availability(...)`：按日期展開營位，扣占用預約與 `zone_blocks`；公休日可用量為 0。',
);
push(
  '- `allocate_coupon_claim_capacity` / `sync_coupon_claim_capacity`：領券新增／刪除時同步 `coupons.claimed_quantity`。',
);
push(
  '- `reject_customer_hard_delete` + `soft_delete_customer` / `suspend_customer` / `reactivate_customer`：會員禁止硬刪，改走狀態函式。',
);
push('- `set_updated_at`、`touch_equipment_item_from_child`：時間戳與裝備主檔連動。');
push('- `validate_zone_block_capacity`：人工鎖位不可超過營位總量。');
push('');
push('### Trigger');
push('');
push('| Trigger | 表 | 時機／函式 |');
push('| --- | --- | --- |');
for (const t of triggers) {
  push(`| \`${t.name}\` | \`${t.table}\` | ${t.timing} → \`${t.fn}\` |`);
}
push('');
push('## Spring Boot 後端待完成的規則');
push('');
push('- 營地租借庫位必須是 `rental/campground`；最低庫存設定與庫位領域相容。');
push(
  '- 優惠券領取狀態轉換（claimed → consumed / revoked / expired）；訂單用券的 claim 必須屬於該會員。',
);
push('- 庫存異動 `draft/posted/cancelled` 流程與過帳後不可改。');
push('- 庫存轉換只能 store → rental。');
push('- 商城／租借保留帳建立、釋放、到期、完成；進結帳寫 `checkout_expires_at`（約 15 分鐘）並與保留帳 `expires_at` 對齊。');
push('- Firebase：`customers.firebase_uid`／`admin_users.firebase_uid` 綁定；後台 email 白名單。');
push('- ECPay webhook 寫入 `payment_notifications`（冪等）；付款真相仍在 `orders`／`bookings`。');
push('- 多數業務狀態流（訂單、預約）以 Service 管理；DB 負責 CHECK／FK／上述 Trigger。');
push('');
push('## 資料如何流動');
push('');
push(
  '1. **商品下單**：`equipment_items` → `products` → `product_variants`；進結帳寫待付款 `orders`、`order_items`（快照）、`product_stock_reservations` 與 `checkout_expires_at`。狀態寫 `order_status_history`；ECPay 通知寫 `payment_notifications`／`order_event_history`。用券：`coupon_claims`（consumed）+ `order_coupons`。',
);
push(
  '2. **營區預約**：讀 `campgrounds`／zones／closures／`zone_blocks`，呼叫 `get_zone_availability()`。成立後寫 `bookings`（含付款欄位、禁止 COD）、選取明細與 `rental_stock_reservations`。入住區間 `[check_in, check_out)`。占用狀態僅政策允許的 `pending`／`confirmed`。',
);
push(
  '3. **庫存異動**：`inventory_movements` 草稿 + store／rental 明細；`posted` 才正式生效。`inventory_conversions` 將商城規格轉入租借規格。',
);
push(
  '4. **內容與評價**：`articles` + 區塊／標籤／關聯商品。正式評論僅能對 `order_items` 一筆 `reviews`；圖在 `review_photos`。',
);
push('');
push('## 設計上值得注意的地方');
push('');
push(
  '- **整檔重建，不是增量 migration**：改結構請更新 `latest_schema.sql` 後重建開發庫；勿假設有 V00x Flyway 鏈。',
);
push('- **交易快照刻意去正規化**：訂單／預約 `*_snapshot` 不應回頭同步主檔。');
push(
  '- **庫存領域隔離**：`product_variants` 與 `rental_sku_variants` 分開；以 domain／複合 FK 防混接。',
);
push(
  '- **讀模型優先用 View**：例如 `sellable_product_variants`、`article_dto_view`、`review_dto_view`、`coupon_claim_stats`。',
);
push(
  '- **時間與金額**：多用 timestamptz；金額用 `numeric(12,2)`／`numeric(14,2)`，勿用浮點累加。',
);
push('');
push('## 完整資料字典（public 表）');
push('');
push(
  '「必填」依 `NOT NULL`；「預設值」取自 DDL。業務語意見各 domain 的 `database-documents/`。',
);
push('');

for (const t of tables) {
  push(`### \`public.${t.name}\``);
  const comment = tableComments[t.name];
  push(comment ? `**用途：** ${comment}` : '**用途：** （見 DDL／database-documents）');
  const keyBits = [];
  if (t.pks.length) keyBits.push(`PRIMARY KEY: ${t.pks.join('; ')}`);
  if (t.uniques.length) keyBits.push(`UNIQUE: ${t.uniques.join('; ')}`);
  push(`**鍵：** ${keyBits.length ? keyBits.join('；') : '見 DDL'}`);
  if (t.fks.length) {
    push(
      '**關聯：** ' +
        t.fks.map((fk) => `${fk.cols} → ${fk.refTable}(${fk.refCols})`).join('；'),
    );
  } else {
    push('**關聯：** 無外鍵（或僅由他表參照）。');
  }
  push('');
  push('| 欄位 | 型別 | 必填 | 預設值 |');
  push('| --- | --- | --- | --- |');
  for (const c of t.cols) {
    const type = c.type.replace(/\|/g, '\\|');
    push(
      `| \`${c.col}\` | \`${type}\` | ${c.notNull ? '是' : '否'} | \`${c.def}\` |`,
    );
  }
  push('');
}

push('## 讀模型（Views）');
push('');
push('| View | 說明（COMMENT 或用途） |');
push('| --- | --- |');
for (const v of views) {
  push(`| \`public.${v.name}\` | ${viewComments[v.name] || '見 DDL SELECT'} |`);
}
push('');
push('## 讀這份文件的實用順序');
push('');
push('1. 先從 ERD 選流程（下單、預約或庫存）。');
push('2. 讀主表後再讀明細／歷程；用券看 `coupon_claims` + `order_coupons`。');
push('3. 遇到 `*_snapshot`、複合鍵或 inventory domain，回看注意事項與 DDL CHECK。');
push(
  '4. 要改結構：更新 [`latest_schema.sql`](./latest_schema.sql)，開發環境以 `docker compose down -v && docker compose up -d` 重建。',
);
push(
  '5. 枚舉允許值見 [`schema-enums.md`](./schema-enums.md)；領域說明見 [`database-documents/`](./database-documents/)。',
);
push('');

fs.writeFileSync(
  path.join(root, 'docs', 'database-schema-guide.md'),
  lines.join('\n'),
  'utf8',
);

console.log(
  `OK: ${tables.length} tables, ${views.length} views, ${enums.length} enums, ${functions.length} functions, ${triggers.length} triggers`,
);
