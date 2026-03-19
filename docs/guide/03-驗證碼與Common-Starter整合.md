# Care Security — 圖形驗證碼 & Common Starter 整合

**報告日期：** 2026-03-10
**版本：** v0.0.3-SNAPSHOT
**接續：** 安全強化與 LDAP 整合報告（v0.0.2）

---

## 一、本階段項目總覽

| # | 項目 | 類型 |
|---|------|------|
| 1 | 圖形驗證碼 (Image CAPTCHA) | 功能 |
| 2 | Phase 12 CAPTCHA 測試（TDD，41 個） | 測試 |
| 3 | Common Starter 整合（response / jpa / log） | 重構 |
| 4 | Docker LDAP 帳號調整 | 環境 |

---

## 二、圖形驗證碼系統

### 設計原則

- **可選功能**：`care.security.captcha.enabled` 開關，預設關閉
- **一次性消耗**：驗證後立即從 Redis 刪除
- **自動過期**：預設 5 分鐘 TTL
- **前端自適應**：API 不存在時自動隱藏驗證碼欄位

### 架構流程

```
GET /api/auth/captcha → 產生驗證碼 → 存 Redis → 回傳 { captchaId, image(base64) }
POST /api/auth/login  → 驗證 CAPTCHA → LDAP/本地認證 → 產生 JWT
```

### 設定

```yaml
care:
  security:
    captcha:
      enabled: true
      length: 4
      expire-seconds: 300
```

### 新增/修改的類別

| 類別 | 說明 |
|------|------|
| `CaptchaService` | 驗證碼產生、圖片繪製、Redis 存取、驗證 |
| `CaptchaController` | `GET /api/auth/captcha`（public） |
| `CaptchaResponse` | `record(captchaId, image)` |
| `LoginRequest` | 新增 `captchaId`、`captchaAnswer`（Optional） |
| `AuthService` | 登入流程最前方加入 CAPTCHA 驗證 |
| `CareSecurityAutoConfiguration` | 條件式註冊 CaptchaService、CaptchaController |

### Conditional Bean 機制

- `enabled=true` → Bean 存在，端點註冊，AuthService 執行驗證
- `enabled=false` → Bean 不存在，AuthService 用 `ObjectProvider` 跳過驗證

---

## 三、Phase 12 測試（41 個）

| 分組 | 數量 | 驗證重點 |
|------|------|---------|
| 12.1 驗證碼產生 | 3 | ID 唯一、Base64 圖片、PNG 格式 |
| 12.2 驗證邏輯 | 4 | 正確/錯誤答案、不存在 ID、一次性使用 |
| 12.3 登入整合 | 5 | 缺驗證碼 400、錯誤驗證碼 400、正確流程 200 |
| 12.4 HTTP API 契約 | 3 | 不需認證、每次不同驗證碼 |

---

## 四、Common Starter 整合

### 整合的 Starter

| Starter | 提供功能 |
|---------|---------|
| `common-response` | ApiResponse、GlobalExceptionHandler、ErrorCode |
| `common-jpa` | AuditableEntity、BaseEntity（審計+軟刪除+樂觀鎖）、AuditorAware |
| `common-log` | ApiLogAspect（自動 API 日誌）、敏感遮罩、Micrometer Tracing 整合 |

### common-response 整合

- 刪除 care-security 自有的 `ApiResponse`，改用 common-response 的
- `GlobalExceptionHandler` → `SecurityExceptionHandler`（`@Order(0)`），只處理安全異常
- 通用異常交給 common-response 的 `GlobalExceptionHandler`（`@Order(LOWEST_PRECEDENCE)`）

### common-jpa 整合

#### 繼承鏈

```
common-jpa AuditableEntity（4 審計欄位）
  ↑ common-jpa BaseEntity（+ deleted + @Version）
    ↑ care-security AuditableEntity（@AttributeOverride 映射舊欄位名）
      ↑ SaUser, Menu, Role, Perm, Organize ...
```

#### 欄位映射

| Java 屬性 | DB 欄位 | 映射方式 |
|-----------|---------|---------|
| `createdDate` | `DATE_CREATED` | `@AttributeOverride` |
| `lastModifiedDate` | `LAST_UPDATED` | `@AttributeOverride` |
| `createdBy` | `CREATED_BY` | `@AttributeOverride` |
| `lastModifiedBy` | `LAST_UPDATED_BY` | `@AttributeOverride` |
| `deleted` | `deleted` | 直接繼承（新增欄位） |
| `version` | `version` | 直接繼承（新增欄位） |

#### 審計升級

手動 `@PrePersist`/`@PreUpdate` → Spring Data JPA `@CreatedDate`/`@LastModifiedDate`/`@CreatedBy`/`@LastModifiedBy` 自動管理。

### common-log 整合

加入依賴即自動生效，無需修改程式碼。

#### 提供的功能

| 功能 | 說明 |
|------|------|
| ApiLogAspect | 自動記錄所有 `@RestController` 的 request/response/duration + traceId |
| 敏感資料遮罩 | `password`、`token`、`secret` 等自動替換為 `******` |
| @Loggable | 自訂控制：可關閉 request/response 記錄、指定遮罩欄位 |
| Optional Tracer | 有 Micrometer 時自動取 traceId，沒有時顯示 N/A |

日誌格式範例：
```
API_REQUEST method=OrderController.create POST /api/orders traceId=abc123 args={...}
API_SUCCESS method=OrderController.create POST /api/orders cost=150ms traceId=abc123 response={...}
API_ERROR   method=OrderController.create POST /api/orders cost=50ms traceId=abc123 error=NPE
```

#### Micrometer Tracing（取代自製 TraceIdFilter）

**架構變更：** 刪除自製 `TraceIdFilter`，改用 Spring 官方 Micrometer Tracing + OpenTelemetry。

| Micrometer Tracing 功能 | 說明 |
|------------------------|------|
| 自動產生 traceId/spanId | 每個請求唯一 traceId |
| MDC 自動注入 | logback 用 `%X{traceId}` 即可 |
| 跨服務傳播 | RestTemplate/WebClient 自動帶 `traceparent` header |
| W3C Trace Context | 標準協定，跨語言/跨框架相容 |

**common-log 只負責「讀取」traceId 並印在日誌裡**，traceId 的產生和傳播由 Micrometer 處理。

#### 跨系統 traceId 傳播（例如 Grails）

Spring Boot 呼叫其他服務時，Micrometer 自動在 header 帶上：
```
traceparent: 00-{traceId}-{spanId}-{flags}
```

對方系統取得 traceId 的方式：

| 方式 | 難度 | 說明 |
|------|------|------|
| 解析 `traceparent` header | 低（推薦） | 寫一個 Interceptor 從 header 取出 traceId 放進 MDC |
| 裝 OpenTelemetry SDK | 中 | 完整支援，自動解析 + 繼續傳播 |
| 自訂 Header | 低 | 非標準，只有自己系統認得 |

##### 方案一：手動解析 traceparent（推薦）

Grails 寫一個 Interceptor，從 `traceparent` header 取出 traceId：

```groovy
class TraceIdInterceptor {
    boolean before() {
        String traceparent = request.getHeader("traceparent")
        String traceId = "N/A"
        if (traceparent) {
            // 格式: 00-{traceId}-{spanId}-{flags}
            def parts = traceparent.split("-")
            if (parts.length >= 2) traceId = parts[1]
        }
        org.slf4j.MDC.put("traceId", traceId)
        return true
    }
    void afterView() { org.slf4j.MDC.remove("traceId") }
}
```

##### 方案二：裝 OpenTelemetry（完整方案）

```groovy
// build.gradle
dependencies {
    implementation 'io.opentelemetry:opentelemetry-api:1.31.0'
    implementation 'io.opentelemetry:opentelemetry-sdk:1.31.0'
    implementation 'io.opentelemetry.instrumentation:opentelemetry-spring-webmvc-6.0:1.31.0-alpha'
}
```

裝了之後 Grails（底層是 Spring Boot）會自動解析 `traceparent`、沿用 traceId、並在 outgoing 請求繼續傳播。

##### 方案三：自訂 Header

Spring Boot 端手動加 header：

```java
restTemplate.getInterceptors().add((request, body, execution) -> {
    String traceId = tracer.currentSpan().context().traceId();
    request.getHeaders().set("X-Trace-Id", traceId);
    return execution.execute(request, body);
});
```

Grails 端直接讀：

```groovy
String traceId = request.getHeader("X-Trace-Id")
```

> 不推薦：非標準協定，只有自己系統認得。

### DB Migration

7 張表新增 `deleted BIT NOT NULL DEFAULT 0` 和 `version INT DEFAULT 0`：
- Migration script：`003-add-deleted-and-version-columns.sql`
- Docker init：`02-dev-schema-and-data.sql` 同步更新

---

## 五、Docker 環境變更

LDAP 測試帳號改為 `root1`~`root4`（密碼均為 `1234`），OpenLDAP 新增 `--copy-service` 啟動參數。

---

## 六、測試結果

整合後 **169 個測試全部通過**，零失敗、零錯誤。
