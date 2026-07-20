# Admin 登入系統 — 目前進度紀錄

這份文件記錄「Admin 後台登入系統」目前已經做到哪裡，每一步做了什麼、每個檔案的用途，方便之後接續開發時快速回想上下文。完整規劃在
`C:\Users\user\.claude\plans\admin-entity-repository-controller-rustling-pumpkin.md`（本機 Claude Code 的計畫檔），這份 MD 是「目前已完成部分」的摘要。

## 背景

- `admin/login.html` 目前是純前端 mock：帳號密碼查的是 `localStorage.adminEmployees`，密碼只驗證「不可為空」，完全沒有串接資料庫。程式碼裡有一行預留註解 `// API 預留：POST /api/admin/login`，這就是我們要實作的目標 API 路徑。
- 後端 `backend/` 原本只有一個 `BackendApplication.java`，完全沒有 `entity`、`repository`、`controller`、`service`、`dto`、`config` 分層。這次目標是透過實作 admin 登入，把這幾層的架構骨架建立起來。
- 資料庫是 PostgreSQL，schema 定義在 `docs/latest_schema.sql`（正本，這次不動）與 `docs/latest_schema copy.sql`（副本，這次的 schema 修改都寫在這裡）。
- 認證機制決定用 **Session Cookie**（Spring Security 內建 session 機制，不需要額外加 JWT 套件）。
- 這一輪 **只做後端骨架**，前端 `admin/login.html` 還沒有改，之後才會串接。

## 已完成的步驟

### 1. 資料庫 schema — 加了一個欄位

檔案：`docs/latest_schema copy.sql`

`admin_users` 表原本沒有密碼欄位，無法支援真正的登入驗證。已經加上：

```sql
password_hash character varying(255) NOT NULL,
```

放在 `email` 之後、`role` 之前。之後密碼會用 BCrypt 演算法雜湊過再存進這個欄位，**不會存明文密碼**。

> 注意：只改了 copy 檔，`docs/latest_schema.sql` 正本沒有動，這是刻意的決定，避免影響其他還在參照正本的東西。

### 2. 在 `backend/` 建立 6 個 package（資料夾）

路徑：`backend/src/main/java/com/yuruicamp/backend/` 底下

```
entity/       — 對應資料庫表的 Java 物件
repository/   — 資料庫存取介面
service/      — 商業邏輯（登入驗證、算權限）
controller/   — 對外的 HTTP API 入口
dto/          — 請求/回應用的資料格式
config/       — Spring Security 等設定
```

這些是 Spring Boot 生態系的慣例分層方式：Controller 收 HTTP 請求 → 呼叫 Service 處理商業邏輯 → Service 呼叫 Repository 存取資料庫 → Repository 操作 Entity。DTO 是 Controller 對外溝通用的資料格式（跟 Entity 分開，避免把資料庫欄位、敏感資料直接暴露給前端）。

### 3. 每個 package 先放一個檔案，讓骨架可以先推上 Git

因為 Git 不會追蹤空資料夾，所以先在每個資料夾裡放一個檔案，讓整個骨架結構能被 commit/push。以下是目前每個檔案的實際內容與後續要補的東西：

#### `entity/AdminUser.java`
對應 `admin_users` 表，這個檔案**已經寫完整**（不是佔位）：
- 欄位：`id`、`name`、`email`、`passwordHash`、`role`、`active`、`createdAt`、`updatedAt`，型別/長度都對齊 `docs/latest_schema copy.sql` 的 DDL。
- 因為 `application.properties` 設定 `spring.jpa.hibernate.ddl-auto=validate`，Hibernate 啟動時會逐欄核對 Entity 跟資料庫結構是否一致，所以欄位長度、是否可為空都要精準對應。
- 目前只有 getter，沒有 setter（不可變風格），之後如果 Service 需要更新資料再視情況補。

**還沒做**：另外 3 個 Entity（`AdminPermission`、`AdminRolePermission`、`AdminUserPermission`）還沒建立，之後要對應 `admin_permissions`、`admin_role_permissions`、`admin_user_permissions` 三張表（後兩張表主鍵是複合主鍵，需要用 `@EmbeddedId` 處理）。

#### `repository/AdminUserRepository.java`
目前只是最基本的骨架：

```java
public interface AdminUserRepository extends JpaRepository<AdminUser, String> {
}
```

繼承 `JpaRepository<AdminUser, String>` 已經自動具備 `findById`、`save`、`findAll` 等萬用方法（`String` 是主鍵型別）。

**還沒做**：
- 需要加一個依 id 查帳號、且只查啟用中帳號的方法：`Optional<AdminUser> findByIdAndActiveTrue(String id)`。
- 還要建立 `AdminRolePermissionRepository`、`AdminUserPermissionRepository` 兩個 Repository，用來查角色預設權限、個人權限覆寫。

#### `service/AdminAuthService.java`
目前是空殼：

```java
@Service
public class AdminAuthService {
}
```

**還沒做**：這是登入商業邏輯真正要寫的地方——查帳號、比對密碼（透過 `PasswordEncoder`）、組合角色權限（角色預設值 + 個人覆寫），最後回傳登入結果給 Controller。

#### `controller/AdminAuthController.java`
目前只設定了路徑前綴，還沒有任何 API 方法：

```java
@RestController
@RequestMapping("/api/admin")
public class AdminAuthController {
}
```

**還沒做**：加上 `@PostMapping("/login")` 方法，對應前端預留的 `POST /api/admin/login`，接收 `AdminLoginRequest`、呼叫 `AdminAuthService`、寫入 session、回傳 `AdminLoginResponse` 或 401 錯誤。

#### `dto/AdminLoginRequest.java`
目前是空的 class：

```java
public class AdminLoginRequest {
}
```

**還沒做**：加上 `id`、`password` 兩個欄位，並加 `@NotBlank` 這類 Bean Validation 註解做基本檢查。還要另外建立 `AdminLoginResponse.java`，對應登入成功後要回傳給前端的格式（`id`、`displayName`、`role`、`isActive`、`permissions`）。

#### `config/SecurityConfig.java`
目前是空殼：

```java
@Configuration
public class SecurityConfig {
}
```

**還沒做**：這是整個認證機制的總開關，需要：
- 宣告 `PasswordEncoder`（`BCryptPasswordEncoder`）bean，供 Service 做密碼比對。
- 設定 `SecurityFilterChain`：`/api/admin/login` 開放給未登入者呼叫、其他 `/api/admin/**` 之後預設要求登入、停用 Spring Security 預設產生的登入頁面、決定 CSRF 的處理方式。

## 還沒做（下一步待辦）

1. 補完 3 個 Entity（`AdminPermission`、`AdminRolePermission`、`AdminUserPermission`）。
2. 補完 3 個 Repository 的查詢方法。
3. 把 `AdminAuthService` 的登入邏輯寫出來（查帳號 → 比對密碼 → 算權限）。
4. 補完 `AdminLoginRequest`／新增 `AdminLoginResponse` 的欄位。
5. 把 `SecurityConfig` 的 filter chain、`PasswordEncoder` bean 寫出來。
6. 把 `AdminAuthController` 的 `POST /login` 方法接起來。
7. 用 `PasswordEncoder` 產生種子帳號的 BCrypt 雜湊密碼，回填到 `docs/latest_schema copy.sql` 的 `INSERT INTO admin_users` 種子資料（目前種子資料本身也還沒寫）。
8. 本機用 Docker 重建資料庫（吃到新的 copy schema）、啟動後端、用 curl/Postman 測試登入 API 的 4 種情境（帳號不存在、密碼錯、帳號停用、成功登入）。

## 關鍵決策備忘

- 認證機制：Session Cookie，不用 JWT。
- 密碼加密：BCrypt（`spring-boot-starter-security` 內建 `BCryptPasswordEncoder`，沒有加任何新的 Maven 依賴）。
- Schema 修改只寫在 `docs/latest_schema copy.sql`，不動正本 `docs/latest_schema.sql`。
- 這一輪不動 `admin/login.html`，先把後端 API 做出來，之後才串前端。
