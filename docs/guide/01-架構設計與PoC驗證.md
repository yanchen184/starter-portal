# Care Security Spring Boot Starter — 專案現況報告

**報告日期：** 2026-03-04
**版本：** v1.0 (PoC 完成)
**技術棧：** Spring Boot 4.0.3 + Spring Security 7.0.3 + Java 21

---

## 一、專案概述

### 1.1 目標

將現行 Grails 5 的權限核心模組遷移至 Spring Boot 4，以 **Spring Boot Starter** 形式封裝，讓各業務系統只需加入一個 Maven 依賴，即可獲得完整的認證、授權、帳號管理功能。

### 1.2 什麼是 Spring Boot Starter

Spring Boot Starter 是 Spring 官方推薦的**模組封裝模式**，核心概念：

> **消費端不需要知道內部實作細節，只需要加依賴 + 寫 yml 設定。**

```
┌─────────────────────────────────────────────────────────────────┐
│  業務系統（消費端）                                                │
│                                                                 │
│  pom.xml:                                                       │
│    <dependency>                                                 │
│      <groupId>gov.mohw.care</groupId>                          │
│      <artifactId>care-security-starter</artifactId>            │
│    </dependency>                                                │
│                                                                 │
│  application.yml:                                               │
│    care:                                                        │
│      security:                                                  │
│        jwt:                                                     │
│          access-token-ttl-minutes: 30                           │
│          keystore-path: file:./keys/jwt-keys.json              │
│        login:                                                   │
│          max-attempts: 5                                        │
│          lock-duration-minutes: 30                              │
│        cors:                                                    │
│          allowed-origins: http://localhost:3000                 │
│                                                                 │
│  Java 程式碼：只需寫業務邏輯，安全機制全部自動生效                      │
│  ├── DemoApplication.java    (@SpringBootApplication)           │
│  └── HelloController.java    (@PreAuthorize 直接用)              │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 四模組架構

本專案拆分為 4 個 Maven 子模組，符合 Spring Boot 官方 Starter 設計規範：

```
care-security/                          ← Parent POM
├── care-security-core                  ← 核心實作（Entity、Service、Config）
├── care-security-autoconfigure         ← 自動配置 + 外部參數
├── care-security-starter               ← Starter JAR（依賴聚合，無程式碼）
└── care-security-test                  ← 分階段整合測試
```

| 模組 | 職責 | 包含 |
|------|------|------|
| **core** | 所有實作程式碼 | Entity、Repository、Service、Controller、Config、Security 元件 |
| **autoconfigure** | 自動配置 + 外部化參數 | `CareSecurityAutoConfiguration`、`CareSecurityProperties` |
| **starter** | 依賴聚合（無程式碼） | 只有 pom.xml，引入 autoconfigure（間接引入 core） |
| **test** | 測試驗證 | 10 Phase / 120 個測試案例 |

### 1.4 AutoConfiguration 機制

**核心問題**：消費端如何不寫任何 `@Bean`，就能拿到完整的安全功能？

**答案**：透過 Spring Boot 的 `AutoConfiguration.imports` 機制。

```
                         Spring Boot 啟動
                              │
                              ▼
              掃描 META-INF/spring/
              org.springframework.boot.autoconfigure.AutoConfiguration.imports
                              │
                              ▼
              找到 CareSecurityAutoConfiguration
                              │
                              ▼
              @EnableConfigurationProperties(CareSecurityProperties.class)
              → 讀取 application.yml 中 care.security.* 的設定
                              │
                              ▼
              @ConditionalOnMissingBean 條件註冊所有 Bean
              → 消費端沒自己定義的 Bean，自動用 Starter 提供的
              → 消費端有自己定義的 Bean，優先用消費端的（可覆蓋）
```

**外部化參數的運作方式**：

```java
// CareSecurityProperties.java（autoconfigure 模組）
@ConfigurationProperties(prefix = "care.security")
public class CareSecurityProperties {
    private Jwt jwt = new Jwt();        // care.security.jwt.*
    private Login login = new Login();  // care.security.login.*
    private Cors cors = new Cors();     // care.security.cors.*

    public static class Jwt {
        private int accessTokenTtlMinutes = 30;      // 預設值
        private int refreshTokenTtlDays = 7;
        private String keystorePath;                  // 金鑰持久化路徑
    }
}
```

```java
// CareSecurityAutoConfiguration.java（autoconfigure 模組）
@AutoConfiguration
@EnableConfigurationProperties(CareSecurityProperties.class)
public class CareSecurityAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean  // ← 消費端可覆蓋
    public LoginAttemptService loginAttemptService(SaUserRepository repo,
                                                   CareSecurityProperties props) {
        return new LoginAttemptService(repo,
                props.getLogin().getMaxAttempts(),      // ← yml 參數注入
                props.getLogin().getLockDurationMinutes());
    }
}
```

**消費端使用時**，只需在 `application.yml` 寫設定，不需碰任何 Java 程式碼：

```yaml
care:
  security:
    jwt:
      access-token-ttl-minutes: 60    # 覆蓋預設值 30 → 60
    login:
      max-attempts: 3                 # 覆蓋預設值 5 → 3
```

---

## 二、技術選型

| 項目 | 選型 | 版本 |
|------|------|------|
| **Spring Boot** | Spring Boot | 4.0.3 |
| **Spring Security** | Spring Security（含 OAuth2 Auth Server） | 7.0.3 |
| **Java** | Java LTS | 21 |
| **ORM** | Hibernate | 7.2.4 |
| **資料庫** | MSSQL Server | 現行 |
| **快取** | Redis | 現行 |
| **認證協定** | OAuth2 + JWT（RS256） | — |
| **密碼編碼** | Password4j BCrypt + Legacy SHA-512 相容 | 1.8.2 |
| **建置工具** | Maven（多模組） | 3.9.9 |
| **測試** | JUnit 6 + AssertJ + MockMvc | — |

### 選型說明

- **Spring Boot 4.0.3**：最新 LTS 主版本，底層升級至 Jakarta EE 11、Hibernate 7、Spring Security 7。選用最新穩定版確保長期維護支援。
- **Java 21**：LTS 版本，支援 Virtual Threads、Pattern Matching 等新特性，配合 Spring Boot 4 的最低要求。
- **OAuth2 + JWT（RS256）**：無狀態認證，前後端分離架構下不需依賴 Server-Side Session，RSA 非對稱簽章確保 Token 不可偽造。
- **Password4j**：專業密碼雜湊函式庫，原生支援 BCrypt/SCrypt/Argon2，同時可自訂 Legacy 格式相容 Grails 5 既有密碼。
- **Maven 多模組**：Spring Boot 官方 Starter 慣例使用 Maven，且與公司既有 CI/CD 工具鏈整合。
- **MSSQL + Redis**：沿用現行基礎設施，降低遷移風險。

---

## 三、已完成項目

### 3.1 認證機制

| 功能 | 說明 | 為什麼需要 | 相關類別（Shift+Shift 搜尋） |
|------|------|-----------|---------------------------|
| JWT Token 簽發 | RS256 非對稱簽章，Access 30min + Refresh 7d | 無狀態認證，不需 Session，適合前後分離 | `AuthService`, `JwtEncoder`, `AuthorizationServerConfig` |
| Token 輪轉 | Refresh 時發新 Token 並撤銷舊 Token | 防止 Token 被竊取後無限使用 | `AuthService.refresh()`, `RedisTokenBlacklistService` |
| RSA 金鑰持久化 | 首次啟動自動產生金鑰並存為 JWK JSON 檔案，重啟後重用 | 避免每次重啟導致全體使用者強制登出 | `AuthorizationServerConfig.jwkSource()`, `CareSecurityProperties.Jwt` |
| 登出機制 | Redis Token 黑名單（JTI + TTL） | JWT 無狀態下實現主動撤銷 | `RedisTokenBlacklistService`, `AuthService.logout()` |
| 帳號鎖定 | N 次失敗自動鎖定 M 分鐘，時間到自動解鎖 | 防暴力破解，參數可從 yml 設定 | `LoginAttemptService`, `SaUser.failedAttempts` |
| 稽核記錄 | LoginHistory（成功/失敗/IP）+ AuditLog（操作事件） | 政府系統合規需求 | `AuditService`, `LoginHistory`, `AuditLog` |

### 3.2 授權機制

| 功能 | 說明 | 為什麼需要 | 相關類別（Shift+Shift 搜尋） |
|------|------|-----------|---------------------------|
| RBAC 權限模型 | User → OrgRole → Role → RolePerms → Perm → Menu | 標準 RBAC1 + 組織層級 | `SaUser`, `SaUserOrgRole`, `Role`, `RolePerms`, `Perm`, `Menu` |
| CRUD 五向權限 | Create / Read / Update / Delete / Approve | 細粒度控制，符合表單系統需求 | `CrudPermissionEvaluator`, `CustomUserDetails.CrudPermission` |
| 組織角色切換 | switchOrg API，全域角色 + 組織角色 OR 合併 | 同一使用者在不同組織有不同權限 | `AuthService.switchOrg()`, `CustomUserDetailsService.loadUserByUsernameAndOrg()` |
| `@PreAuthorize` 整合 | `hasPermission('SC940', 'CREATE')` 直接用 | 宣告式權限控制，不需寫 if/else | `CrudPermissionEvaluator.hasPermission()`, `SecurityConfig.methodSecurityExpressionHandler()` |
| JWT Claims 嵌入權限 | 角色、權限矩陣寫入 JWT，每次請求不查 DB | 效能：避免每次 API 呼叫都查資料庫 | `JwtTokenCustomizer.customize()`, `CustomUserDetails` |

### 3.3 密碼機制

| 功能 | 說明 | 為什麼需要 | 相關類別（Shift+Shift 搜尋） |
|------|------|-----------|---------------------------|
| BCrypt 編碼（新） | Password4j BCrypt，rounds=12 | 現代安全標準 | `PasswordEncoderConfig`, `Password4jBcryptEncoder` |
| SHA-512 相容（舊） | `{SHA-512}{base64salt}hexhash` 格式 | 無縫對接 Grails 5 現有密碼，不需要求使用者全部重設 | `LegacyGrailsPasswordEncoder` |
| SmartMatchingEncoder | 自動偵測密碼格式，分派對應編碼器 | DelegatingPasswordEncoder 搭配自動識別 | `SmartMatchingEncoder`, `PasswordEncoderConfig.passwordEncoder()` |
| 密碼歷史記錄 | PwdHistory 表儲存變更紀錄 | 政府系統合規：禁止重用近 N 組密碼 | `PwdHistory`, `PwdHistoryRepository`, `AuthService.changePassword()` |

### 3.4 API 端點

| 端點 | 方法 | 功能 | 相關類別（Shift+Shift 搜尋） |
|------|------|------|---------------------------|
| `/api/auth/login` | POST | 登入 | `AuthController.login()`, `AuthService.login()` |
| `/api/auth/refresh` | POST | Token 更新 | `AuthController.refresh()`, `AuthService.refresh()` |
| `/api/auth/logout` | POST | 登出 | `AuthController.logout()`, `AuthService.logout()` |
| `/api/auth/change-password` | POST | 變更密碼 | `AuthController.changePassword()`, `AuthService.changePassword()` |
| `/api/auth/switch-org` | POST | 切換組織 | `AuthController.switchOrg()`, `AuthService.switchOrg()` |
| `/api/auth/switch-user` | POST | 管理員模擬登入 | `AuthController.switchUser()`, `AuthService.switchUser()` |
| `/api/auth/exit-switch-user` | POST | 退出模擬 | `AuthController.exitSwitchUser()`, `AuthService.exitSwitchUser()` |
| `/api/auth/my-orgs` | GET | 取得可用組織 | `AuthController.getMyOrgs()`, `AuthService.getMyOrgs()` |
| `/api/users/**` | CRUD | 使用者管理 | `UserController`, `UserService` |
| `/api/roles/**` | CRUD | 角色管理 | `RoleController`, `RoleService` |
| `/api/perms/**` | CRUD | 權限管理 | `PermController`, `PermService` |
| `/api/menus/**` | CRUD | 選單管理 | `MenuController`, `MenuService` |
| `/api/orgs/**` | GET | 組織查詢 | `OrganizeController`, `OrganizeService` |

### 3.5 基礎設施

| 功能 | 說明 | 為什麼需要 | 相關類別（Shift+Shift 搜尋） |
|------|------|-----------|---------------------------|
| Starter 封裝 | 消費端只需加依賴 + 寫 yml | 統一安全機制，避免各系統自行實作 | `CareSecurityAutoConfiguration`, `CareSecurityProperties` |
| `@ConditionalOnMissingBean` | 所有 Bean 可被消費端覆蓋 | 保留彈性，消費端可客製化 | `CareSecurityAutoConfiguration` |
| Security Filter Chains | 三層過濾鏈：OAuth2 / Resource / Default | URL 分級保護，各層職責分離 | `SecurityConfig`, `CorsConfig` |
| Docker Compose 開發環境 | MSSQL 2022 + Redis 7 + 種子資料 | 開發不依賴公司內網，一鍵啟動 | `docker-compose.yml` |
| 雙環境測試 | `local`（Docker）/ `test`（公司內網） | 切換一行 Profile 即可跑全部測試 | `@CareSecurityTest` |
| Swagger UI | OpenAPI 3 + Bearer Token 自動帶入 | 開發階段 API 文件與測試 | `OpenApiConfig` |

### 3.6 SwitchUser 管理員模擬登入

| 功能 | 說明 | 為什麼需要 | 相關類別（Shift+Shift 搜尋） |
|------|------|-----------|---------------------------|
| 模擬登入 | ROLE_ADMIN 可以模擬其他使用者的 Token | 管理員需驗證權限設定是否正確 | `AuthService.switchUser()`, `SwitchUserRequest` |
| 退出模擬 | 透過 JWT `impersonatedBy` claim 回復原帳號 | 模擬結束後回到管理員身份 | `AuthService.exitSwitchUser()` |
| Refresh 保留狀態 | Token 輪轉時 `impersonatedBy` 不丟失 | 模擬期間 token 過期需能續用 | `AuthService.refresh()` |

### 3.7 組織角色管理

| 功能 | 說明 | 為什麼需要 | 相關類別（Shift+Shift 搜尋） |
|------|------|-----------|---------------------------|
| 組織角色指派 | 指定使用者在某組織下的角色 | RBAC + 組織層級需要管理介面 | `UserController`, `UserService.assignOrgRole()` |
| 組織角色移除 | 移除使用者的組織角色 | 人員異動時需調整權限 | `UserController`, `UserService.removeOrgRole()` |
| 權限 CRUD | 完整的權限建立/查詢/修改/刪除 | 管理員需管理系統權限 | `PermController`, `PermService` |

---

## 五、架構總覽

### 5.1 模組架構圖

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          care-security-core                                     │
│                     Spring Boot 4 + Spring Security 7                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─── CONTROLLER (REST API) ──────────────────────────────────────────────────┐ │
│  │                                                                            │ │
│  │  AuthController          UserController        RoleController              │ │
│  │  /api/auth/*             /api/users/*           /api/roles/*               │ │
│  │  ├ POST /login           ├ GET    /             ├ GET /                    │ │
│  │  ├ POST /refresh         ├ GET    /{id}         ├ GET /{id}               │ │
│  │  ├ POST /logout          ├ POST   /             ├ GET /{id}/permissions   │ │
│  │  ├ POST /change-password ├ PUT    /{id}         └ PUT /{id}/permissions   │ │
│  │  ├ POST /switch-org      ├ POST   /{id}/lock                              │ │
│  │  └ GET  /my-orgs         ├ POST   /{id}/unlock   PermController           │ │
│  │                          ├ POST   /{id}/reset-pw  /api/perms/*            │ │
│  │  MenuController          ├ GET    /{id}/org-roles                         │ │
│  │  /api/menus/*            ├ POST   /{id}/org-roles OrganizeController      │ │
│  │  ├ GET /tree             └ DELETE /{id}/org-roles /api/orgs/*             │ │
│  │  ├ GET /                   /{orgRoleId}          ├ GET /                  │ │
│  │  ├ POST /                                        └ GET /tree             │ │
│  │  ├ PUT /{id}             @PreAuthorize                                    │ │
│  │  └ DELETE /{id}          hasPermission('XXX','CRUD')                      │ │
│  └────────────────────────────────┬───────────────────────────────────────────┘ │
│                                   │                                             │
│  ┌─── SERVICE (Business Logic) ───▼───────────────────────────────────────────┐ │
│  │                                                                            │ │
│  │  AuthService              UserService           RoleService               │ │
│  │  ├ login()                ├ findAll/ById()       ├ findAll/ById()         │ │
│  │  ├ refresh() (rotation)   ├ create()             ├ getPermissionMatrix()  │ │
│  │  ├ logout()               ├ update()             └ updatePermMatrix()     │ │
│  │  ├ changePassword()       ├ lock/unlock()                                 │ │
│  │  ├ switchOrg()            ├ resetPassword()       PermService             │ │
│  │  ├ getMyOrgs()            ├ assignOrgRole()       ├ create/update/delete  │ │
│  │  └ generateTokenPair()    └ removeOrgRole()       └ findAll()             │ │
│  │                                                                            │ │
│  │  MenuService              OrganizeService        AuditService             │ │
│  │  ├ getMenuTree()          ├ findAll()             ├ logEvent()            │ │
│  │  ├ create/update/delete   └ getOrgTree()          └ logLogin()            │ │
│  │  └ findAll()                                                              │ │
│  └────────────────────────────────┬───────────────────────────────────────────┘ │
│                                   │                                             │
│  ┌─── SECURITY (Auth & AuthZ) ────▼───────────────────────────────────────────┐ │
│  │                                                                            │ │
│  │  CustomUserDetailsService          CrudPermissionEvaluator                │ │
│  │  ├ loadUserByUsername()            ├ hasPermission(target, action)         │ │
│  │  ├ loadUserByUsernameAndOrg()      ├ 支援 JWT / UserDetails               │ │
│  │  └ buildPermissionMapForOrg()      └ action: C|R|U|D|A                    │ │
│  │    (OR 合併多角色權限)                                                      │ │
│  │                                                                            │ │
│  │  LoginAttemptService               JwtTokenCustomizer                     │ │
│  │  ├ loginSucceeded()                └ customize() → JWT Claims:            │ │
│  │  ├ loginFailed()                     ├ roles, userId, cname               │ │
│  │  └ isLocked() (自動解鎖)              ├ orgRoles [{orgId, role}]           │ │
│  │                                      └ permissions {code: {c,r,u,d,a}}   │ │
│  │  RedisTokenBlacklistService                                               │ │
│  │  ├ blacklist(jti, expiry)          CustomUserDetails                      │ │
│  │  └ isBlacklisted(jti)              ├ implements UserDetails               │ │
│  │    key: token:blacklist:{jti}      ├ OrgRole(orgId, orgName, role)        │ │
│  │                                    └ CrudPermission(c, r, u, d, a)       │ │
│  └────────────────────────────────┬───────────────────────────────────────────┘ │
│                                   │                                             │
│  ┌─── CONFIG ─────────────────────▼───────────────────────────────────────────┐ │
│  │                                                                            │ │
│  │  SecurityConfig                    PasswordEncoderConfig                   │ │
│  │  ├ authorizationServerFilterChain  ├ DelegatingPasswordEncoder            │ │
│  │  ├ resourceServerFilterChain       │  ├ {bcrypt} Password4jBcryptEncoder  │ │
│  │  ├ defaultFilterChain              │  ├ {SHA-512} LegacyGrailsEncoder     │ │
│  │  └ methodSecurityExprHandler       │  └ SmartMatchingEncoder (自動偵測)    │ │
│  │                                    │                                      │ │
│  │  AuthorizationServerConfig         RedisConfig    CorsConfig              │ │
│  │  ├ RegisteredClientRepository      └ RedisTemplate └ CORS 設定            │ │
│  │  ├ JWKSource (RSA 2048 持久化)                                             │ │
│  │  ├ JwtDecoder                      OpenApiConfig                          │ │
│  │  └ OAuth2TokenCustomizer           └ Swagger UI + Bearer Auth             │ │
│  └────────────────────────────────┬───────────────────────────────────────────┘ │
│                                   │                                             │
│  ┌─── ENTITY (Domain Model) ─────▼───────────────────────────────────────────┐ │
│  │                                                                            │ │
│  │                    ┌──────────────┐                                        │ │
│  │                    │AuditableEntity│ (abstract)                            │ │
│  │                    │createdBy/Date │                                       │ │
│  │                    │updatedBy/Date │                                       │ │
│  │                    └──────┬───────┘                                        │ │
│  │          ┌────────┬───────┼────────┬──────────┐                            │ │
│  │          ▼        ▼       ▼        ▼          ▼                            │ │
│  │      ┌──────┐ ┌──────┐ ┌────┐ ┌──────┐ ┌──────────┐                      │ │
│  │      │SaUser│ │ Role │ │Perm│ │ Menu │ │Organize  │                      │ │
│  │      └──┬───┘ └──┬───┘ └─┬──┘ └──┬───┘ └────┬─────┘                      │ │
│  │         │        │       │       │           │                             │ │
│  │         │   RolePerms (junction)  parent/   parent/                        │ │
│  │         │   ├ role ──► Role      child     child                           │ │
│  │         │   └ perm ──► Perm ──► Menu      (self-ref)                      │ │
│  │         │                                                                  │ │
│  │         ▼                                                                  │ │
│  │   ┌─────────────────────────┐                                             │ │
│  │   │    SaUserOrgRole        │  ◄── 核心關聯表                              │ │
│  │   │    ├ saUser  ──► SaUser │                                             │ │
│  │   │    ├ role    ──► Role   │                                             │ │
│  │   │    └ organize──► Organize (nullable = 全域角色)                        │ │
│  │   └─────────────────────────┘                                             │ │
│  │                                                                            │ │
│  │   LoginHistory    PwdHistory ──► SaUser    AuditLog                       │ │
│  │   (登入記錄)       (密碼歷史)                (稽核日誌)                      │ │
│  └────────────────────────────────┬───────────────────────────────────────────┘ │
│                                   │                                             │
│  ┌─── REPOSITORY (JPA) ──────────▼───────────────────────────────────────────┐ │
│  │  SaUserRepository    RoleRepository     PermRepository                    │ │
│  │  MenuRepository      OrganizeRepository SaUserOrgRoleRepository           │ │
│  │  RolePermsRepository LoginHistoryRepo   PwdHistoryRepo  AuditLogRepo     │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│  ┌─── EXCEPTION ──────────────────────────────────────────────────────────────┐ │
│  │  GlobalExceptionHandler: 401/403/423/400/500 → ApiResponse<Void>          │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│  ┌─── DTO ────────────────────────────────────────────────────────────────────┐ │
│  │  Request:  Login, CreateUser, UpdateUser, ChangePassword, Refresh, etc.   │ │
│  │  Response: Token, User, Role, Perm, MenuTree, OrgTree, PermMatrix, etc.  │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 登入流程

```
Client                Controller          AuthService           Security Layer         DB/Redis
  │                      │                    │                      │                    │
  │  POST /api/auth/login│                    │                      │                    │
  │  {username, password}│                    │                      │                    │
  │─────────────────────►│                    │                      │                    │
  │                      │  login(req, ip)    │                      │                    │
  │                      │───────────────────►│                      │                    │
  │                      │                    │  findByUsername()     │                    │
  │                      │                    │─────────────────────────────────────────►│
  │                      │                    │◄─────────────────────────────────────────│
  │                      │                    │                      │                    │
  │                      │                    │  isLocked(user)?     │                    │
  │                      │                    │─────────────────────►│                    │
  │                      │                    │  (自動解鎖檢查)       │                    │
  │                      │                    │◄─────────────────────│                    │
  │                      │                    │                      │                    │
  │                      │                    │  verifyPassword()    │                    │
  │                      │                    │─────────────────────►│                    │
  │                      │                    │  SmartMatchingEncoder│                    │
  │                      │                    │  ├ BCrypt ($2b$)     │                    │
  │                      │                    │  └ SHA-512 (legacy)  │                    │
  │                      │                    │◄─────────────────────│                    │
  │                      │                    │                      │                    │
  │                      │                    │  loadUserByUsernameAndOrg()               │
  │                      │                    │─────────────────────►│                    │
  │                      │                    │  buildPermissionMap()│  findPerms()       │
  │                      │                    │                      │───────────────────►│
  │                      │                    │                      │  (OR 合併多角色)    │
  │                      │                    │◄─────────────────────│◄───────────────────│
  │                      │                    │                      │                    │
  │                      │                    │  generateTokenPair() │                    │
  │                      │                    │─────────────────────►│                    │
  │                      │                    │  JwtTokenCustomizer  │                    │
  │                      │                    │  ├ roles, userId     │                    │
  │                      │                    │  ├ orgRoles          │                    │
  │                      │                    │  └ permissions{CRUD} │                    │
  │                      │                    │◄─────────────────────│                    │
  │                      │                    │                      │                    │
  │                      │                    │  logLogin(success)   │                    │
  │                      │                    │─────────────────────────────────────────►│
  │                      │◄───────────────────│                      │                    │
  │  TokenResponse       │                    │                      │                    │
  │  {accessToken,       │                    │                      │                    │
  │   refreshToken,      │                    │                      │                    │
  │   expiresIn: 1800}   │                    │                      │                    │
  │◄─────────────────────│                    │                      │                    │
```

### 5.3 權限模型 (RBAC + Organization)

```
                        ┌─────────────┐
                        │   SaUser    │
                        │  (使用者)    │
                        └──────┬──────┘
                               │ 1:N
                    ┌──────────▼──────────┐
                    │   SaUserOrgRole     │
                    │  (使用者-組織-角色)   │
                    │                     │
                    │  organize = NULL    │──► 全域角色 (永遠生效)
                    │  organize = 衛福部  │──► 僅在「衛福部」下生效
                    │  organize = 北區中心│──► 僅在「北區中心」下生效
                    └───┬────────────┬────┘
                        │            │
                   N:1  ▼       N:1  ▼
              ┌──────────┐    ┌──────────┐
              │Organize  │    │   Role   │
              │ (組織)    │    │  (角色)   │
              │ 衛福部    │    │ROLE_ADMIN│
              │  ├ 北區   │    │ROLE_USER │
              │  ├ 中區   │    │ ...      │
              │  └ 南區   │    └────┬─────┘
              └──────────┘         │ 1:N
                                   ▼
                            ┌──────────┐
                            │RolePerms │ (junction)
                            └───┬──────┘
                                │ N:1
                                ▼
                            ┌──────────┐
                            │   Perm   │──► Menu
                            │ permCode │    (選單)
                            │ C R U D A│
                            │ ✓ ✓ ✓ ✗ ✗│
                            └──────────┘

  ═══════════════════════════════════════════════════
  權限合併邏輯 (switchOrg 到某組織時):
  ═══════════════════════════════════════════════════
  全域角色權限 OR 該組織角色權限 = 最終權限
```

### 5.4 密碼編碼策略

```
  SmartMatchingEncoder (自動偵測)
     │
     ├─ $2b$/$2a$/$2y$ 開頭 → Password4jBcryptEncoder (BCrypt, rounds=12)
     └─ hex + salt 格式     → LegacyGrailsPasswordEncoder (SHA-512)

  新密碼一律 {bcrypt} 編碼，舊 Grails 密碼可相容登入
```

### 5.5 Spring Security 架構詳解

Spring Security 7 採用 **多層 SecurityFilterChain** 架構，每條 Chain 負責不同的 URL 範圍：

```
HTTP 請求進來
     │
     ▼
┌────────────────────────────────────────────────────────────┐
│  @Order(1)  authorizationServerFilterChain                 │
│  匹配：OAuth2 端點 (/oauth2/authorize, /oauth2/token...)   │
│  作用：處理 OAuth2 授權碼、Token 簽發                        │
│  特性：CSRF 關閉、CORS 開啟                                 │
│  備註：目前未使用，前端登入走 /api/auth/login（@Order 2）     │
│        未來若有其他系統需 OAuth2 Client Credentials 串接時    │
│        才會走此鏈（如 /oauth2/token）                        │
│                                                            │
│  如果 URL 不匹配 → 往下                                     │
└────────────────────────┬───────────────────────────────────┘
                         ▼
┌────────────────────────────────────────────────────────────┐
│  @Order(2)  resourceServerFilterChain                      │
│  匹配：/api/** (所有業務 API)                                │
│  作用：驗證 JWT Token → 取出角色 → 權限控制                   │
│  特性：                                                     │
│    ├ STATELESS（無 Session）                                 │
│    ├ /api/auth/login、/api/auth/refresh → permitAll         │
│    ├ /api/users/** → 需要 ROLE_ADMIN 或 ROLE_USER_ADMIN     │
│    ├ /api/roles/** → 需要 ROLE_ADMIN                        │
│    └ 其餘 → 需要 authenticated（有合法 JWT 即可）             │
│                                                            │
│  JWT 驗證流程：                                              │
│    Request Header: Authorization: Bearer <jwt>              │
│         │                                                   │
│         ▼                                                   │
│    BearerTokenAuthenticationFilter                          │
│         │                                                   │
│         ▼                                                   │
│    JwtDecoder（用 RSA 公鑰驗簽）                              │
│         │                                                   │
│         ▼                                                   │
│    JwtAuthenticationConverter                               │
│    ├ 從 JWT claims.roles 取出角色列表                         │
│    └ 轉為 GrantedAuthority（給 @PreAuthorize 使用）           │
│                                                            │
│  如果 URL 不匹配 → 往下                                     │
└────────────────────────┬───────────────────────────────────┘
                         ▼
┌────────────────────────────────────────────────────────────┐
│  @Order(3)  defaultFilterChain                             │
│  匹配：其餘所有 URL                                         │
│  作用：Swagger UI、Actuator、靜態資源                        │
│  特性：                                                     │
│    ├ /swagger-ui/**, /v3/api-docs/** → permitAll            │
│    ├ /actuator/health → permitAll                           │
│    └ 其餘 → authenticated                                   │
└────────────────────────────────────────────────────────────┘
```

#### RSA 金鑰與 JWT 的關係

```
                    ┌──────────────────────┐
                    │  RSA Key Pair        │
                    │  ├ Private Key (簽名) │
                    │  └ Public Key  (驗證) │
                    └──────┬───────────────┘
                           │
            ┌──────────────┼──────────────┐
            ▼                             ▼
   ┌─────────────────┐          ┌─────────────────┐
   │   JwtEncoder    │          │   JwtDecoder    │
   │  (簽發 Token)    │          │  (驗證 Token)    │
   │  用 Private Key  │          │  用 Public Key   │
   └────────┬────────┘          └────────┬────────┘
            │                            │
            ▼                            ▼
   登入成功 → 產生 JWT             API 請求 → 驗證 JWT
   AuthService.login()            ResourceServer FilterChain
```

#### 金鑰持久化機制（本次實作）

```
應用程式啟動
     │
     ▼
  keystorePath（預設 ./keys/jwt-keys.json）
     │
     ▼
  檔案存在？ ──── 是 ──→ 讀取 JWK JSON → 重用同一把金鑰 ✅
     │                   （重啟後 JWT 仍然有效）
     否
     ▼
  產生 RSA 2048 Key Pair
     │
     ▼
  序列化為 JWK JSON 格式
     │
     ▼
  寫入檔案（./keys/jwt-keys.json）
     │
     ▼
  下次重啟 → 檔案存在 → 讀取 → 同一把金鑰 ✅
```

**零設定即可使用**，預設自動存檔至 `./keys/jwt-keys.json`。正式環境可覆蓋路徑：

```yaml
care:
  security:
    jwt:
      keystore-path: file:/opt/keys/jwt-keys.json   # 覆蓋預設路徑
```

#### @PreAuthorize 與 CrudPermissionEvaluator 的串接

```
Controller 方法標記：
  @PreAuthorize("hasPermission('SC940', 'CREATE')")

         │
         ▼
  Spring Security MethodSecurityExpressionHandler
         │
         ▼
  CrudPermissionEvaluator.hasPermission(auth, "SC940", "CREATE")
         │
         ▼
  從 Authentication 取出 permissions Map
  （JWT Token 解碼後的 claims，或 CustomUserDetails）
         │
         ▼
  permissions.get("SC940").canCreate == true？
         │
    ├── true  → 放行
    └── false → 403 Forbidden
```

---

### 5.6 Docker 開發環境

#### 設計目標

讓開發者不需連接公司內網，`docker compose up` 一鍵即可啟動完整開發環境。

#### 架構

```
docker compose up
     │
     ├── mssql (MSSQL 2022 Developer)
     │     port: 1433
     │     sa / CareSecDev@2026
     │     │
     │     └── mssql-init (初始化容器)
     │           depends_on: mssql (healthy)
     │           依序執行 4 個 SQL 腳本：
     │           │
     │           ├── 01-create-db.sql
     │           │     建立 care_security DB
     │           │     建立 care_dev 帳號
     │           │
     │           ├── 02-dev-schema-and-data.sql (4.3MB)
     │           │     90 張表 DDL
     │           │     Dev 環境種子資料
     │           │
     │           ├── 03-change-passwords.sql
     │           │     所有帳號密碼統一為 bcrypt(Admin@123)
     │           │     新增 TEST01 測試帳號
     │           │
     │           └── 04-migrate-role-to-org-role.sql
     │                 ORGANIZE_ID 改為 nullable
     │                 SAUSER_ROLE → SAUSER_ORG_ROLE 遷移
     │                 TEST01 角色指派
     │
     └── redis (Redis 7 Alpine)
           port: 6379
           password: CareRedis@2026
```

#### 初始化資料量

| 表 | 筆數 | 說明 |
|----|------|------|
| SAUSER | 117 | 116 dev + 1 TEST01 |
| ORGANIZE | 171 | 組織架構樹 |
| MENU | 45 | 選單 |
| ROLE | 5 | 角色 |
| PERM | 55 | 權限 |
| ROLE_PERMS | 55 | 角色-權限對應 |
| SAUSER_ORG_ROLE | 19 | 8 org + 9 migrated + 2 TEST01 |
| REQUESTMAP | 607 | Grails 遺留（不使用） |

#### 測試帳號

| 帳號 | 密碼 | 角色 |
|------|------|------|
| ADMIN | Admin@123 | ROLE_ADMIN（全部權限） |
| TEST01 | Admin@123 | ROLE_USER（一般使用者） |

#### 使用方式

```bash
# 啟動
cd starter-demo/docker
docker compose up -d

# 等待初始化完成（約 30 秒）
docker logs care-security-init --follow

# 啟動應用程式
cd ..
mvn spring-boot:run

# 停止
docker compose down

# 完全重建（清除資料）
docker compose down -v && docker compose up -d
```

#### Profile 對照

| Profile | DB | Redis | 用途 |
|---------|-----|-------|------|
| `local` | localhost:1433 / care_security | localhost:6379 / db 0 | 本機 Docker |
| `dev` | 10.1.1.197:1433 / wezGrails5 | 10.1.1.16:6379 / db 8 | 公司內網 |

---

## 六、測試策略與結果

### 6.1 Phase-based TDD

採用**分階段測試驅動開發**，由底層向上層逐步驗證：

```
Phase 1   資料層連線與 Entity 映射          13 tests
   ↓
Phase 2   UserDetailsService 載入帳號        11 tests
   ↓
Phase 3   密碼編碼器（三層機制）              10 tests
   ↓
Phase 4   登入流程（認證 + 帳號鎖定）         10 tests
   ↓
Phase 5   JWT Token 產生與驗證               14 tests
   ↓
Phase 6   RBAC 權限評估                      13 tests
   ↓
Phase 7   Redis Token 黑名單                  7 tests
   ↓
Phase 8   Controller 整合測試 (MockMvc)       10 tests
   ↓
Phase 9   AutoConfiguration 驗證               7 tests
   ↓
Phase 10  組織權限切換                         25 tests
                                     ─────────────
                                     合計 120 tests
```

### 6.2 設計原則

| 原則 | 做法 |
|------|------|
| **環境無關** | 不硬編碼帳號數量或密碼，用 `@Value` 從 yml 注入 |
| **單一關注** | 每個 Phase 只驗證一個功能面向 |
| **可獨立跑** | 任一 Phase 都能單獨執行 |
| **雙環境** | `local`（Docker）和 `test`（公司內網）只需改一行 `@ActiveProfiles` |

### 6.3 環境切換方式

```java
// CareSecurityTest.java — 改這一行即切換全部 10 個 Phase
@ActiveProfiles("local")   // ← "local" = Docker / "test" = 公司內網
public @interface CareSecurityTest { }
```

### 6.4 通用斷言策略

```java
// ✅ 正確 — 通用邏輯，不綁定特定環境
assertThat(count).isGreaterThanOrEqualTo(1);
assertThat(roles).contains("ROLE_ADMIN");
assertThat(storedHash).satisfiesAnyOf(
    hash -> assertThat(hash).startsWith("{bcrypt}"),
    hash -> assertThat(hash).startsWith("{SHA-512}")
);

// ❌ 錯誤 — 綁定特定環境資料
assertThat(count).isEqualTo(116);
```

### 6.5 測試結果

```
Tests run: 120, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

| 環境 | DB | Redis | 狀態 |
|------|-----|-------|------|
| `local`（Docker） | localhost:1433 / care_security | localhost:6379 | ✅ 120/120 |
| `test`（公司內網） | 10.1.1.197:1433 / wezGrails5 | 10.1.1.16:6379 | ✅ 120/120 |

---

## 七、PoC 審查結果摘要

針對 PoC 程式碼進行安全與架構審查，共發現 **42 項問題**（已修復 1 項）：

| 嚴重度 | 數量 |
|--------|------|
| 🔴 CRITICAL | 6 |
| 🟠 HIGH | 8 |
| 🟡 MEDIUM | 12 |
| 🟢 LOW | 8 |
| ⬜ 缺失功能 | 8 |

### CRITICAL（7 項）

| # | 問題 | 說明 |
|---|------|------|
| C2 | SHA-512 比對有 Timing Attack | `equalsIgnoreCase()` 非恆定時間 |
| C3 | SHA-512 無 Key Stretching | GPU 可快速暴力破解 |
| C4 | Resource Server 未檢查黑名單 | 登出後 Token 仍可用 30 分鐘 |
| C5 | 登入有 User Enumeration | 三種失敗回應時間不同 |
| C6 | 無密碼複雜度驗證 | `aaaaaaaa` 即可通過 |
| C7 | 變更密碼未檢查歷史 | 可立即重用舊密碼 |

### HIGH（8 項）

| # | 問題 | 說明 |
|---|------|------|
| H1 | MSSQL 連線未加密 | `encrypt=false` |
| H2 | Redis 無 TLS | 黑名單可被竄改 |
| H3 | Client Secret 寫死 | 佔位符 `$2b$12$placeholder` |
| H4 | X-Forwarded-For 無條件信任 | IP 可偽造 |
| H5 | 密碼驗證三條路徑 | 維護風險 |
| H6 | JWT 嵌入權限，撤銷延遲 30min | 權限修改後不即時生效 |
| H7 | isLocked() 有 Race Condition | 讀取方法含寫入副作用 |
| H8 | CRUD 旗標放在 PERM 表 | 修改一個角色影響所有角色（見 RBAC 重構方案） |

---

## 八、RBAC 重構方案

現行 Schema 有 **3 項結構性問題**，需在進入正式開發前修正：

### 8.1 三項重構摘要

| # | 重構項目 | 等級 | 現行問題 | 修正方式 |
|---|---------|------|---------|---------|
| R1 | SAUSER_ROLE 合併 | HIGH | 兩張角色表語意重複，查詢需 UNION，且權限有漏查 Bug | 合併到 SAUSER_ORG_ROLE，`ORG_ID=NULL` 表示全域 |
| R2 | CRUD 旗標搬移 | **CRITICAL** | CRUD 在 PERM 表，修改一個角色會污染所有角色 | 搬到 ROLE_PERMS，每角色獨立控制 |
| R3 | REQUESTMAP 廢棄 | HIGH | Grails 遺留 607 筆規則，Spring Boot 完全不讀取 | Java Config 已取代，Phase 2 移除 |

### 8.2 R2 問題圖解（最嚴重）

```
現行設計（CRUD 在 PERM 上）：

  PERM 表：
  ┌────────┬───────────┬───┬───┬───┬───┬───┐
  │ OBJID  │ PERM_CODE │ C │ R │ U │ D │ A │
  ├────────┼───────────┼───┼───┼───┼───┼───┤
  │   1    │ CASE_MGMT │ 1 │ 1 │ 1 │ 0 │ 0 │  ← 被多個角色共用！
  └────────┴───────────┴───┴───┴───┴───┴───┘

  管理員修改 ROLE_A 的 CASE_MGMT 權限 D=1
  → UPDATE PERM SET D = 1 WHERE OBJID = 1
  → ROLE_B 也變成 D=1 → 💥 權限污染！


重構後（CRUD 在 ROLE_PERMS 上）：

  ROLE_PERMS（每個角色獨立控制 CRUD）：
  ┌─────────┬─────────┬────┬────┬────┬────┬────┐
  │ ROLE_ID │ PERM_ID │ C  │ R  │ U  │ D  │ A  │
  ├─────────┼─────────┼────┼────┼────┼────┼────┤
  │ 1 (管理)│    1    │ 1  │ 1  │ 1  │ 1  │ 1  │
  │ 2 (一般)│    1    │ 0  │ 1  │ 0  │ 0  │ 0  │  ← 互不影響
  └─────────┴─────────┴────┴────┴────┴────┴────┘
```

### 8.3 新舊架構對比

```
舊架構：

  SAUSER ─┬── SAUSER_ROLE ─────→ ROLE ─→ ROLE_PERMS ─→ PERM ─→ MENU
          │   ⚠️ 與下表重複         │     (只有關聯)     C/R/U/D/A
          │                         │                    ⚠️ 放錯位置
          └── SAUSER_ORG_ROLE ──→ ORGANIZE
               ⚠️ 與上表重複

  REQUESTMAP ⚠️ 607 筆無用規則


新架構：

  SAUSER ──── SAUSER_ORG_ROLE ──→ ROLE ──→ ROLE_PERMS ──→ PERM ──→ MENU
               ✅ 統一               │      CAN_CREATE
               NULL = 全域           │      CAN_READ
               有值 = 單位           │      CAN_UPDATE
               ↓                     │      CAN_DELETE
               ORGANIZE              │      CAN_APPROVE
                                     │      ✅ 每角色獨立

  ╳ SAUSER_ROLE   → 已合併到 SAUSER_ORG_ROLE
  ╳ REQUESTMAP    → Java Config 取代
  ╳ PERM.C/R/U/D/A → 搬到 ROLE_PERMS
```

### 8.4 影響評估

| 面向 | 數據 |
|------|------|
| R1 資料搬移量 | 9 筆（SAUSER_ROLE → SAUSER_ORG_ROLE） |
| R2 資料搬移量 | 53 筆（PERM CRUD → ROLE_PERMS CRUD） |
| 回滾方案 | 有完整備份 + 回滾 SQL |
| 對舊系統影響 | Phase 1 保留所有舊結構，不刪表不刪欄位 |

---

## 九、待辦事項

### Phase 1A：安全關鍵修復（上線阻斷項）

| 序 | 編號 | 預估 | 內容 | 狀態 |
|----|------|------|------|------|
| 1 | C4 | 2h | TokenBlacklistFilter — 登出真正生效 | 待辦 |
| 3 | H8/R2 | 4h | CRUD 旗標搬至 ROLE_PERMS | 待辦 |
| 4 | R1 | 2h | SAUSER_ROLE 合併到 SAUSER_ORG_ROLE | 待辦 |
| 5 | C5 | 1h | 統一登入失敗回應 + dummy hash | 待辦 |
| 6 | C2 | 0.5h | MessageDigest.isEqual() 恆定時間比對 | 待辦 |
| 7 | C3 | 2h | 登入成功自動遷移 Legacy 密碼至 BCrypt | 待辦 |
| 8 | H5 | 3h | 統一密碼驗證路徑 | 待辦 |
| 9 | C7 | 2h | 變更密碼時檢查歷史 | 待辦 |
| 10 | C6 | 3h | 密碼複雜度驗證器 | 待辦 |
| 11 | H4 | 1h | X-Forwarded-For 信任清單 | 待辦 |

### Phase 1B：合規與架構強化

| 序 | 編號 | 預估 | 內容 | 狀態 |
|----|------|------|------|------|
| 12 | H1 | 1h | MSSQL 啟用 TLS | 待辦 |
| 13 | H2 | 0.5h | Redis 加入 TLS | 待辦 |
| 14 | H3 | 2h | Client Secret 外部化 | 待辦 |
| 15 | H6 | 4h | 權限版本機制或縮短 Token TTL | 待辦 |
| 16 | H7 | 2h | isLocked() 分離讀寫 + 樂觀鎖 | 待辦 |
| 17 | F2 | 1h | 安全 Response Headers（HSTS、CSP） | 待辦 |
| 18 | F4 | 2h | 登入流程檢查 passwordExpired | 待辦 |
| 19 | M1 | 0.5h | CORS 限制 Headers | 待辦 |
| 20 | M2 | 3h | IP 速率限制 | 待辦 |

### Phase 2：效能與品質

| 序 | 編號 | 預估 | 內容 | 狀態 |
|----|------|------|------|------|
| 21 | M3 | 2h | findAll() N+1 查詢修復 | 待辦 |
| 22 | M4 | 2h | Tree N+1 修復（一次載入） | 待辦 |
| 23 | M7 | 2h | 分頁 API | 待辦 |
| 24 | R3 | 1h | 移除 RequestMap Entity | 待辦 |
| 25 | M6 | 1h | 啟用 @EnableJpaAuditing | 待辦 |
| 26 | L6 | 1h | 核心實體加 @Version 樂觀鎖 | 待辦 |

### Phase 3：功能擴充與前端整合

| 序 | 編號 | 預估 | 內容 | 狀態 |
|----|------|------|------|------|
| 27 | FE1 | 4h | 前端組織切換 UI（右上角下拉選單，呼叫 `/api/auth/switch-org`） | 待辦 |
| 28 | F5 | 3h | SwitchUserFilter — 管理員模擬登入（僅 ROLE_ADMIN 可用，方便權限測試） | ✅ 已完成 |

---

*本報告基於 care-security v0.0.1-SNAPSHOT（87 個 Java 檔案、6,224 行程式碼、120 個測試全數通過）撰寫。*
