# Care Security — Phase 1A 開發報告

**報告日期：** 2026-03-06
**版本：** v0.0.2-SNAPSHOT
**接續：** 技術選型到 RBAC 重構報告（v0.0.1）
**涵蓋時間：** 2026-03-04 ~ 2026-03-06（兩天）

---

## 一、本階段新增項目總覽

| # | 項目 | 類型 | 涉及模組 |
|---|------|------|---------|
| 1 | 密碼策略系統（規則引擎 + 歷史檢查） | 功能 | core, autoconfigure, demo |
| 2 | LDAP 認證整合 | 功能 | core, autoconfigure, demo, frontend |
| 3 | JWT 精簡 + GET /api/auth/me | 安全 | core, autoconfigure, frontend |
| 4 | TOTP 雙因素驗證（OTP） | 功能 | core, autoconfigure, demo, frontend |
| 5 | Phase 11 OTP 測試（TDD 範本） | 測試 | test |
| 6 | Demo 專案擴充 SaUser 欄位示範 | 示範 | demo |
| 7 | Docker 環境整理（OpenLDAP + init SQL） | 環境 | demo |
| 8 | 程式碼品質修復（SonarQube + CVE） | 品質 | core |
| 9 | Impersonation 審計 + Null Safety | 修復 | core |

### 數據摘要

| 指標 | v0.0.1 | v0.0.2 | 差異 |
|------|--------|--------|------|
| Java 檔案數（src） | 87 | 93 | +6 |
| Java 測試檔案數 | 12 | 13 | +1 |
| 程式碼行數（src） | ~6,200 | ~6,500 | +300 |
| 測試程式碼行數 | ~2,000 | ~2,500 | +500 |
| REST API 端點 | 18 | 41 | +23 |
| Git commits（3 repos） | — | 48 | — |
| 測試案例數 | 95 | 136 | +41 |

---

## 二、密碼策略系統

### 解決的問題

上一版審查發現 C6（無密碼複雜度驗證）和 C7（變更密碼未檢查歷史），本階段完整解決。

### 架構設計

```
                    ┌──────────────────────────────┐
                    │  CareSecurityProperties      │
                    │  care.security.password.*     │
                    │  （yml 外部化設定）             │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │  YamlPasswordPolicyProvider   │
                    │  讀取 yml → 轉為規則物件       │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │  PasswordPolicyService        │
                    │  ├ validate(password)         │
                    │  │  ├ 長度檢查               │
                    │  │  ├ 大小寫/數字/特殊字元    │
                    │  │  ├ 連續字元 (abc, 123)    │
                    │  │  ├ 重複字元 (aaa)         │
                    │  │  └ 常見弱密碼黑名單       │
                    │  │                            │
                    │  └ isRecentlyUsed()           │
                    │     比對最近 N 組密碼歷史     │
                    └──────────────────────────────┘
```

### 新增類別

| 類別 | 模組 | 說明 |
|------|------|------|
| `PasswordPolicyProvider` | core | 策略提供者介面（可被消費端覆蓋） |
| `YamlPasswordPolicyProvider` | core | 從 yml 讀取策略的預設實作 |
| `PasswordPolicyService` | core | 密碼驗證引擎 + 歷史檢查 |
| `PasswordPolicyConfig` | core | 策略 Bean 配置 |
| `PasswordPolicyController` | core | `GET /api/auth/password-policy`（前端取得規則） |
| `CareSecurityProperties.Password` | autoconfigure | 密碼策略外部化參數 |

### 設定方式

```yaml
care:
  security:
    password:
      min-length: 8               # 最小長度
      max-length: 128             # 最大長度
      require-uppercase: true     # 需要大寫字母
      require-lowercase: true     # 需要小寫字母
      require-digit: true         # 需要數字
      require-special-char: true  # 需要特殊字元
      reject-sequential: true     # 拒絕連續字元 (abc, 123)
      reject-repeated: true       # 拒絕重複字元 (aaa)
      reject-common-weak: true    # 拒絕常見弱密碼
      history-count: 3            # 記住最近 N 組密碼（不可重用）
```

### 環境差異範例

| 設定 | Dev | Prod |
|------|-----|------|
| min-length | 8 | 12 |
| history-count | 3 | 6 |
| 其餘規則 | 全開 | 全開 |

Demo 專案提供 `application-password-policy-examples.yml` 作為設定參考。

---

## 三、LDAP 認證整合

### 解決的問題

企業環境使用 Active Directory 管理帳號，使用者不應再記一組本地密碼。

### 架構

```
使用者登入
     │
     ▼
LDAP 啟用？ ─── 否 ──→ 直接走本地認證
     │
     是
     ▼
LdapAuthenticationProvider.authenticate()
     │
     ├── Step 1: 用服務帳號 bind 到 LDAP
     ├── Step 2: 用 filter 搜尋使用者 DN
     ├── Step 3: 用使用者 DN + 密碼做 bind（驗證密碼）
     └── Step 4: 取回 displayName、email
     │
     ├── 成功 ──→ LdapUserSyncService.syncUser()
     │              ├─ 首次：建立本地用戶 + 指派預設角色 + authSource="LDAP"
     │              └─ 再次：更新 displayName / email
     │            ──→ 產生 JWT（authSource claim = "LDAP"）
     │
     └── 失敗 ──→ 降級到本地認證
                   （但 authSource="LDAP" 的用戶會被擋下）
```

### AuthenticationManager 架構筆記

目前系統只有**一個 ProviderManager**（AuthenticationManager 的實作），內含多個 Provider：

```
AuthenticationManager (ProviderManager)
    ├── DaoAuthenticationProvider       ← 本地帳密驗證
    └── LdapAuthenticationProvider      ← LDAP 認證（條件式載入）
```

**一個 Manager 夠用的情況：** 認證入口只有一個，只是來源不同（本地/LDAP），用不同 Provider 區分即可。

**需要多個 Manager 的情況：** 認證入口本身不同（JWT vs 憑證 vs OAuth2），連「怎麼取得認證資訊」都不一樣，需要不同 FilterChain + 不同 Manager。例如：

```
場景：未來接衛福部 SSO

我們的前端登入
    POST /api/auth/login { username, password }
    → FilterChain A → DaoAuthenticationProvider 驗帳密 → 發我們自己的 JWT

外部系統（如 HIS）呼叫我們的 API
    GET /api/patients  Authorization: Bearer <OAuth2 token from SSO>
    → FilterChain B → OpaqueTokenAuthenticationProvider → 去 SSO 伺服器驗 token
```

到時候只需加一個新的 `SecurityFilterChain` Bean，不影響現有登入流程。這是 Phase 2+ 的規劃項目。

### 新增類別

| 類別 | 模組 | 說明 |
|------|------|------|
| `LdapAuthenticationProvider` | core | JNDI bind 認證 + filter injection 防護 + 連線測試 |
| `LdapUserSyncService` | core | LDAP 使用者同步到本地 DB（建立/更新） |
| `LdapController` | core | `GET /api/ldap/status`（ADMIN 限定） |
| `CareSecurityProperties.Ldap` | autoconfigure | LDAP 外部化參數 |

### 設定方式

```yaml
care:
  security:
    ldap:
      enabled: true                              # 啟用開關（預設 false）
      url: ldap://localhost:389                  # LDAP 伺服器位址
      base-dn: dc=care,dc=gov,dc=tw             # 搜尋起點
      user-search-filter: "(uid={0})"           # OpenLDAP 用 uid，AD 用 sAMAccountName
      bind-dn: cn=admin,dc=care,dc=gov,dc=tw    # 服務帳號 DN
      bind-password: "LdapAdmin@2026"            # 服務帳號密碼（建議用環境變數）
      display-name-attr: displayName             # LDAP 顯示名稱屬性
      email-attr: mail                           # LDAP 信箱屬性
      default-roles:                             # 新使用者自動指派角色
        - ROLE_USER
```

### 條件式載入

```java
@Bean
@ConditionalOnProperty(prefix = "care.security.ldap", name = "enabled", havingValue = "true")
public LdapAuthenticationProvider ldapAuthenticationProvider(...) { }
```

- `enabled = false`（預設）→ 不建立 LDAP Bean，零影響
- `enabled = true` → 建立 LDAP Bean，AuthService 透過 `ObjectProvider<>` 注入

### AUTH_SOURCE 欄位

`SAUSER` 表新增 `AUTH_SOURCE VARCHAR(20) DEFAULT 'LOCAL'`：

| 用途 | 說明 |
|------|------|
| 阻擋 LDAP 用戶走本地登入 | authSource = "LDAP" 時拒絕本地密碼驗證 |
| 阻擋 LDAP 用戶改密碼 | 密碼由 LDAP 目錄管理 |
| 阻擋管理員重設 LDAP 密碼 | `UserService.resetPassword()` 拒絕 |
| JWT / 前端標記 | 前端顯示 LDAP badge、隱藏改密碼表單 |

### 安全措施

- **LDAP Filter Injection 防護**：`\`, `*`, `(`, `)`, `\0` 跳脫處理
- **連線 Timeout**：connect 5s / read 10s
- **密碼佔位符**：LDAP 用戶本地密碼為 `{noop}LDAP_MANAGED`，永遠不會通過 matches()
- **PASSWORD_SALT 相容**：NOT NULL 欄位設空字串
- **ORGANIZE_ID 相容**：NOT NULL 欄位用預設組織 (id=1)

### 前端整合

| 功能 | 頁面 | 說明 |
|------|------|------|
| Auth Source badge | Dashboard | LOCAL（綠）/ LDAP（藍）標記 |
| 改密碼禁用 | Dashboard | LDAP 用戶顯示「需透過 LDAP 目錄修改」 |
| LDAP 狀態卡片 | Dashboard | ADMIN 可看連線狀態 + LDAP 說明 |
| LDAP badge | Users | 使用者列表標記 LDAP 用戶 |
| 重設密碼禁用 | Users | LDAP 用戶按鈕 disabled |

---

## 四、JWT 精簡 + GET /api/auth/me

### 解決的問題

上一版審查發現 JWT 權限矩陣精簡（資訊洩漏風險）為 HIGH 等級問題：
- JWT 包含完整 CRUD 權限矩陣（55 個 perm x 5 flags），Token 過長
- 敏感權限資訊暴露在 JWT 中（前端可解碼）
- 權限修改後需等 Token 過期才生效（最長 30 分鐘延遲）

### 改動前後對比

**Before（JWT claims）：**
```json
{
  "sub": "ADMIN",
  "roles": ["ROLE_ADMIN"],
  "userId": 1,
  "cname": "系統管理員",
  "authSource": "LOCAL",
  "orgRoles": [{"orgId": 1, "orgName": "所有單位", "roleAuthority": "ROLE_TEST"}, ...],
  "permissions": {"SC940": {"c": true, "r": true, "u": true, "d": true, "a": false}, ...}
}
```

**After（JWT claims）：**
```json
{
  "sub": "ADMIN",
  "roles": ["ROLE_ADMIN"],
  "userId": 1,
  "cname": "系統管理員",
  "authSource": "LOCAL"
}
```

### 新增 API

| 端點 | 方法 | 說明 |
|------|------|------|
| `/api/auth/me` | GET | 回傳當前使用者完整資訊（permissions、orgRoles、otpEnabled） |

回應格式：
```json
{
  "userId": 1,
  "username": "ADMIN",
  "cname": "系統管理員",
  "authSource": "LOCAL",
  "roles": ["ROLE_ADMIN"],
  "orgRoles": [{"orgId": 1, "orgName": "所有單位", "roleAuthority": "ROLE_TEST"}],
  "permissions": {"SC940": {"c": true, "r": true, "u": true, "d": true, "a": false}},
  "currentOrgId": null,
  "otpEnabled": false
}
```

### 後端改動

| 類別 | 改動 |
|------|------|
| `AuthService` | `generateTokenPair()` 移除 permissions/orgRoles claims，新增 `getUserInfo()` |
| `JwtTokenCustomizer` | 移除 permissions/orgRoles claims |
| `AuthController` | 新增 `GET /api/auth/me` 端點 |
| `UserInfoResponse` | 新增 DTO（含 otpEnabled 欄位） |
| `CrudPermissionEvaluator` | 注入 `CustomUserDetailsService`，改為從 DB 即時查詢權限 |

### 前端改動

| 檔案 | 改動 |
|------|------|
| `AuthContext.tsx` | 登入 / switchUser / exitSwitchUser 後呼叫 `/api/auth/me`，儲存 `userInfo` |
| `DashboardPage.tsx` | 新增 User Info 卡片，顯示 orgRoles 表格 + CRUD 權限矩陣 |

### 效果

- JWT Token 大幅縮短（從數 KB 降到幾百 bytes）
- 權限修改後即時生效（`@PreAuthorize` 從 DB 查詢，不再讀 JWT）
- 敏感權限資訊不再暴露在 Token 中

---

## 五、TOTP 雙因素驗證（OTP）

### 解決的問題

為系統加入 TOTP (Time-based One-Time Password) 雙因素驗證，支援 Google Authenticator / Microsoft Authenticator。
採用與 LDAP 相同的 `ConditionalOnProperty` 模式：做了但不啟用，由使用專案決定。

### 架構設計

```
OTP 在 Spring Security 流程中的位置：

FilterChain → AuthenticationManager → AuthenticationProvider（驗帳密）
                                              │
                                              ▼
                                      AuthService.login()
                                              │
                                    otpEnabled? ─── 否 ──→ 直接發 JWT Token
                                              │
                                              是
                                              ▼
                                    回傳 { requiresOtp: true, accessToken: null }
                                              │
                                    前端收集 OTP code
                                              │
                                              ▼
                                    POST /api/auth/otp/verify
                                              │
                                    OtpService.verifyOtp() → TotpService.verifyCode()
                                              │
                                              ▼
                                    AuthService.completeOtpLogin() → 發 JWT Token
```

### 登入流程

```
使用者登入流程（OTP 啟用時）：

1. POST /api/auth/login     → { requiresOtp: true, accessToken: null }
2. POST /api/auth/otp/verify → { accessToken: "eyJ...", requiresOtp: false }

OTP 設定流程：

1. POST /api/auth/otp/setup        → { secret: "ABCD...", otpAuthUri: "otpauth://totp/..." }
2. 使用者用 Authenticator App 掃描 QR Code
3. POST /api/auth/otp/verify-setup  → OTP 啟用
```

### 新增類別

| 檔案 | 說明 |
|------|------|
| `otp/TotpService.java` | RFC 6238 TOTP 實作（HmacSHA1, 6 位數, 30 秒，含 Base32 編解碼） |
| `otp/OtpService.java` | OTP 業務邏輯（setup / verify / enable / disable） |
| `otp/OtpController.java` | REST 端點（4 個 API），放在 `otp` package 避免 component scan 衝突 |
| `dto/request/OtpVerifyRequest.java` | 驗證碼請求 DTO |
| `dto/request/OtpLoginRequest.java` | OTP 登入請求 DTO |
| `dto/response/OtpSetupResponse.java` | OTP 設定回應 DTO |

### API 端點

| Method | Path | 說明 | 認證 |
|--------|------|------|------|
| POST | `/api/auth/otp/setup` | 產生 TOTP 密鑰 + QR 碼 URI | 需登入 |
| POST | `/api/auth/otp/verify-setup` | 驗證 App 上的碼，啟用 OTP | 需登入 |
| POST | `/api/auth/otp/verify` | 登入時 OTP 驗證，回傳 JWT | 公開 |
| DELETE | `/api/auth/otp` | 停用 OTP | 需登入 |

### 設定方式

```yaml
care:
  security:
    otp:
      enabled: true                 # 啟用 TOTP 雙因素驗證
      issuer: CareSecurityDemo      # Authenticator App 顯示名稱
      allowed-skew: 1               # 允許 ±30 秒時間偏差
```

### 條件式載入

```java
// CareSecurityAutoConfiguration.java — 與 LDAP 相同模式
@Bean
@ConditionalOnProperty(prefix = "care.security.otp", name = "enabled", havingValue = "true")
public TotpService totpService(CareSecurityProperties properties) { ... }

@Bean
@ConditionalOnProperty(prefix = "care.security.otp", name = "enabled", havingValue = "true")
public OtpService otpService(...) { ... }

@Bean
@ConditionalOnProperty(prefix = "care.security.otp", name = "enabled", havingValue = "true")
public OtpController otpController(...) { ... }
```

OtpController 放在 `otp` package（不是 `controller`），避免 component scan 在 OTP 未啟用時找到它卻缺少依賴而報錯。

### 資料庫變更

```sql
ALTER TABLE SAUSER ADD OTP_SECRET NVARCHAR(64) NULL;
ALTER TABLE SAUSER ADD OTP_ENABLED BIT DEFAULT 0;
```

由 Docker init SQL `06-add-otp-columns.sql` 管理（不使用 Flyway）。

### TokenResponse 改動

```java
public record TokenResponse(
    String accessToken,       // OTP required 時為 null
    String refreshToken,      // OTP required 時為 null
    String tokenType,
    long expiresIn,
    String username,
    List<String> roles,
    Long currentOrgId,
    String impersonatedBy,
    String authSource,
    boolean requiresOtp       // 新增欄位
) {
    // 向下相容的建構子（8 參數、9 參數版本都 default requiresOtp=false）
    public static TokenResponse otpRequired(String username) { ... }
}
```

### 前端整合

| 檔案 | 改動 |
|------|------|
| `AuthContext.tsx` | 新增 `otpPending` 狀態、`verifyOtp()` / `cancelOtp()` 方法 |
| `LoginPage.tsx` | OTP 驗證畫面（6 位數輸入框）、login 後判斷 requiresOtp |
| `DashboardPage.tsx` | OTP 管理卡片（setup → QR Code → verify → enabled → disable） |
| `qrcode.react` | 新增套件，產生 QR Code SVG |

### 零外部依賴

TOTP 完全自行實作，不依賴任何第三方 OTP 函式庫。使用 JDK 內建的 `HmacSHA1` + 自製 Base32 編解碼。

---

## 六、Phase 11 OTP 測試（TDD 範本）

### 測試結構

新增 `Phase11_OtpTotpTest.java`，41 個測試案例，按業務場景分組：

| 區塊 | 對應需求 | 測試數 |
|------|---------|-------|
| 11.1 TOTP Algorithm | RFC 6238 演算法規格 | 10 |
| 11.2 OTP Setup Flow | 使用者設定 2FA | 8 |
| 11.3 OTP Login Flow | OTP 登入驗證 | 7 |
| 11.4 OTP Disable Flow | 停用 2FA | 2 |
| 11.5 TokenResponse Contract | 向下相容 | 3 |
| 11.6 HTTP API Contract | REST 端點 + 認證規則 | 11 |

### TDD 範本用途

每個區塊開頭包含：
- **User Story** — 使用者角度描述需求
- **Acceptance Criteria** — 驗收條件清單
- **Implementation Checklist** — 要實作什麼

未來新功能開發流程：先寫測試（Red）→ 寫最小實作（Green）→ 重構（Refactor）

### 測試配置

`application-local.yml` 新增：
```yaml
care:
  security:
    otp:
      enabled: true
      issuer: CareSecurityTest
      allowed-skew: 1
```

### TotpService 可見性調整

為了跨 package 測試，以下方法從 package-private 改為 `public`：
- `generateCode(String secret, Instant time)`
- `verifyCode(String secret, String code, Instant time)`
- `Base32` 內部類別及其 `encode()` / `decode()` 方法

---

## 七、Demo 專案：如何擴充 SaUser 欄位

### 解決的問題

消費端（業務系統）需要在 SaUser 上新增業務欄位（如 phone、department），但不能修改 core 的 Entity。

### 實作方式

Demo 專案示範了 JPA `@MappedSuperclass` 繼承擴充：

```
care-security-core:
  SaUser (Entity, TABLE = SAUSER)
    ├── username, password, enabled, ...
    └── 不可修改

security-starter-demo:
  ExtSaUser (extends SaUser)
    ├── phone       (新增欄位)
    └── department  (新增欄位)

  ExtSaUserConfig (@Configuration)
    └── 覆蓋 SaUserRepository 的 Entity 掃描
```

### 相關檔案

| 檔案 | 說明 |
|------|------|
| `ExtSaUser.java` | 繼承 SaUser，新增 phone / department 欄位 |
| `ExtSaUserConfig.java` | 配置 JPA Entity 掃描，讓 Hibernate 用 ExtSaUser 代替 SaUser |
| `V1__Add_phone_and_department_to_sauser.sql` | Flyway migration（唯一的 Flyway 遷移檔） |

---

## 八、Docker 環境

### 配置檔案

| 檔案 | 用途 |
|------|------|
| `docker-compose.yml` | 標準版（amd64 Linux/Windows） |
| `docker-compose.mac.yml` | Mac Apple Silicon 版（arm64） |

### 服務清單

| 服務 | 標準版 Image | Mac 版 Image | Port |
|------|-------------|-------------|------|
| MSSQL | `mssql/server:2022-latest` | `azure-sql-edge:1.0.7` | 1433 |
| Init | 同 MSSQL image | `mssql-tools:latest` (Rosetta) | — |
| Redis | `redis:7-alpine` | `redis:7-alpine` | 6379 |
| OpenLDAP | `osixia/openldap:1.5.0` | `osixia/openldap:1.5.0` | 389 |

### Init SQL 腳本（01-06）

| 順序 | 檔案 | 用途 |
|------|------|------|
| 01 | `01-create-db.sql` | 建立 `care_security` 資料庫和 `care_dev` 帳號 |
| 02 | `02-dev-schema-and-data.sql` | 建立所有資料表 + 匯入開發測試資料 |
| 03 | `03-change-passwords.sql` | 重設所有使用者密碼為 `Admin@123` |
| 04 | `04-migrate-role-to-org-role.sql` | SAUSER_ROLE 遷移到 SAUSER_ORG_ROLE |
| 05 | `05-add-auth-source.sql` | 新增 AUTH_SOURCE 欄位（LDAP 支援） |
| 06 | `06-add-otp-columns.sql` | 新增 OTP_SECRET、OTP_ENABLED 欄位（TOTP 2FA） |

### 設定檔

| 檔案 | 說明 |
|------|------|
| `application-dev.yml` | 開發環境（LDAP + OTP 啟用） |
| `application-prod.yml` | 生產環境範例（LDAP 註解 + 嚴格密碼策略） |
| `application-ldap-examples.yml` | 4 種 LDAP 設定範例（OpenLDAP / AD / LDAPS / Disabled） |
| `application-password-policy-examples.yml` | 密碼策略設定範例 |

---

## 九、程式碼品質修復

### SonarQube / IntelliJ 靜態分析

| 項目 | 說明 |
|------|------|
| `@NonNull` 替換 | Spring deprecated `@NonNull` → JSpecify `@NonNull` |
| Entity 品質 | 所有 Entity getter/setter 規範化、Boolean 用 `Boolean.TRUE.equals()` |
| Exception Handler | 統一錯誤回應格式 |
| 未使用 import | 全面清理 |

### Jackson CVE（GHSA-72hv-8253-57qq）

Spring Boot 4.0.3 綁定的 `jackson-core 3.0.4` 存在此漏洞，修復版 `3.1.0` 因 API breaking change（`JsonMapper$Builder`）與 Spring Boot 不相容，暫無法升級。

**影響範圍：** 此漏洞僅影響 Jackson 的 **async（非阻塞）parser**，用於 WebFlux / Reactive 場景。本專案使用傳統 Servlet（Spring MVC），**不受影響**。

**處理方式：** 在 `pom.xml` 加註說明，待 Spring Boot 升至 4.0.4+ 後一併升級。

### 其他修復

| 項目 | 說明 |
|------|------|
| Impersonation 審計 | switchUser / exitSwitchUser 寫入 AUDIT_LOG + IP + User-Agent |
| 集合 Null Safety | CustomUserDetails 的 authorities / orgRoles / permissions 保證非 null |
| RequestMap Entity | 移除 Grails 遺留的 RequestMap Entity（Java Config 已取代） |
| LdapUserSyncService | 處理 PASSWORD_SALT / ORGANIZE_ID NOT NULL 欄位相容 |

---

## 十、完整 Commit 記錄

### care-security（15 commits）

| Commit | 說明 |
|--------|------|
| `64ccadb` | feat: 新增組織角色管理、權限 CRUD、全域角色指派功能 |
| `e00b381` | fix: 修復關鍵 Bug 與 SonarQube 程式碼品質全面改善 |
| `d76083b` | refactor: SonarQube / IntelliJ 靜態分析全面修復 |
| `77d8b2d` | fix: 升級 jackson-bom 3.1.0 修復 CVE + 替換 deprecated @NonNull |
| `e46d79c` | revert: 回退 jackson-bom 3.1.0（與 Spring Boot 4.0.3 不相容） |
| `31d0749` | docs: 加註 jackson-bom 漏洞無法升級原因 |
| `5aad016` | feat: SwitchUser 模擬登入 + refresh token 保留 impersonation |
| `89175f7` | feat: 密碼策略系統 + 密碼歷史檢查 + Controller 重構 |
| `ac96e5f` | feat: LDAP authentication integration |
| `b82e49a` | fix: impersonation audit logging + collection null safety |
| `450cf5a` | fix: LdapUserSyncService NOT NULL constraints 相容 |
| `4d24c63` | feat: slim JWT — remove permissions/orgRoles, add GET /api/auth/me |
| `6f7002a` | feat: add TOTP two-factor authentication (OTP) |
| `9d5477d` | test: add Phase 11 OTP/TOTP tests (41 test cases, TDD style) |
| `de414c3` | feat: expose otpEnabled in UserInfoResponse via /api/auth/me |

### security-starter-demo（14 commits）

| Commit | 說明 |
|--------|------|
| `3c89f4e` | feat: Docker 環境重整、新增 PageController 權限測試 API |
| `482c000` | feat: ExtSaUser 擴展欄位 + prod profile + Docker schema 更新 |
| `4d35beb` | feat: LDAP demo environment setup |
| `0aec5b2` | chore: docker docs, password policy examples, migration scripts |
| `e8d37ff` | chore: remove V3 auth_source migration |
| `eb43bdb` | fix: add AUTH_SOURCE to Docker init SQL |
| `43cd5f0` | fix: move AUTH_SOURCE to separate init script |
| `721c7e1` | feat: enable OTP and add migration for OTP columns |
| `f5734ae` | chore: remove V4 Flyway migration, OTP columns by Docker init only |
| `7b5924f` | fix: add missing init SQL steps (05, 06) to all docker-compose files |
| `dc28223` | chore: remove redundant docker-compose.windows.yml, add LDAP to Mac |
| `059de1c` | docs: update Docker README for current setup |
| `36d157e` | docs: add file listing table to Docker README |
| `cbc6f50` | chore: remove start-docker-services.bat |

### security-starter-demo-frontend（7 commits）

| Commit | 說明 |
|--------|------|
| `ec34d6f` | feat: 權限管理完整前端介面 |
| `e475f09` | feat: 全域角色指派、側欄重排、API URL 環境變數化 |
| `c6ef5f1` | feat: SwitchUser 前端介面 + impersonation banner |
| `c04b1e7` | feat: LDAP frontend integration |
| `ac8e9b8` | feat: integrate GET /api/auth/me — Dashboard 顯示權限矩陣 |
| `ea973d6` | feat: frontend OTP support — login flow + dashboard setup/disable |
| `f14065c` | feat: add QR Code to OTP setup + sync otpEnabled from backend |

---

## 十一、待辦事項

### 剩餘 Phase 1B 項目

| 序 | 內容 | 優先級 |
|----|------|--------|
| ~~1~~ | ~~JWT 權限矩陣精簡（資訊洩漏風險）~~ | ~~HIGH~~ done |
| 2 | CORS origin 解析 trim 空白 | HIGH |
| 3 | X-Forwarded-For 信任清單 | HIGH |
| 4 | Refresh endpoint Rate Limiting | MEDIUM |
| 5 | LoginAttemptService 競態條件 | MEDIUM |
| 6 | MSSQL / Redis 啟用 TLS | MEDIUM |
| 7 | 安全 Response Headers（HSTS、CSP） | MEDIUM |
| 8 | 登入流程檢查 passwordExpired | MEDIUM |
| 9 | IP 速率限制 | MEDIUM |

### Phase 2 待辦

| 序 | 內容 | 優先級 |
|----|------|--------|
| ~~1~~ | ~~TOTP 雙因素驗證（OTP）~~ | ~~HIGH~~ done |
| ~~2~~ | ~~OTP 測試案例~~ | ~~MEDIUM~~ done |
| 3 | 測試案例補齊（LDAP、密碼策略、SwitchUser） | MEDIUM |
| 4 | 自然人憑證 / 身分證驗證 / 行動自然人 QRcode | LOW |
| 5 | 分頁 API | MEDIUM |
| 6 | 啟用 @EnableJpaAuditing | LOW |
| 7 | 核心實體加 @Version 樂觀鎖 | LOW |

---

*本報告基於 care-security `de414c3`、security-starter-demo `cbc6f50`、frontend `f14065c` 撰寫。*
