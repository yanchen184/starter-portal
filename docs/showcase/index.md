# Starter Showcase

體驗公司共用 Starter 的完整能力，包含：

| Starter | 說明 |
|---------|------|
| `common-security` | JWT 認證、自然人憑證（MOICA）登入、驗證碼 |
| `common-log` | 統一日誌格式、慢請求標記、敏感欄位遮罩 |
| `common-response` | 統一回應格式（ApiResponse）、BusinessException、GlobalExceptionHandler |
| `common-attachment` | 附件上傳/下載/刪除、圖片壓縮 |
| `common-report` | 報表產製（EasyExcel + xDocReport）、同步/非同步匯出 |

---

## 技術棧

- **Java 21** / **Spring Boot 4.0.3** / **Maven**
- **MSSQL** + **Flyway** 管理 schema migration
- **Redis**（JWT refresh token、挑戰碼、驗證碼）

---

## 啟動

### 前置需求

- MSSQL（`localhost:1433`，資料庫 `starter_showcase`）
- Redis（`localhost:6379`）

### 啟動後端

```bash
mvn spring-boot:run
```

- Swagger UI：http://localhost:8080/swagger-ui.html
- Log 檔案：`logs/app.log`

---

## API 列表

### Security — 自然人憑證登入

| API | 方法 | 說明 |
|-----|------|------|
| `/api/auth/cert/login-token` | GET | 取得挑戰碼（一次性，存 Redis 限時 5 分鐘） |
| `/api/auth/cert/login` | POST | 送出 PKCS#7 簽章封包，驗證後取得 JWT |

### Log Demo

| API | 方法 | 說明 |
|-----|------|------|
| `/api/log-demo/ok` | GET | 基本 log 格式 |
| `/api/log-demo/slow?delay=5` | GET | `[SLOW]` 慢請求標記（閾值 3 秒） |
| `/api/log-demo/error` | GET | 錯誤 log + 統一錯誤回應 |
| `/api/log-demo/submit` | POST | request body log |
| `/api/log-demo/login-mock` | POST | 密碼遮罩（password → `***`） |
| `/api/log-demo/trace-chain` | GET | traceId 串聯（多筆 log 共用同一個 traceId） |

### Response Demo

展示 `common-response-starter` 的統一回應格式與例外處理。

| API | 方法 | 說明 |
|-----|------|------|
| `/api/response-demo/auto-wrap` | GET | 自動包裝 — 任意物件自動包成 `ApiResponse` |
| `/api/response-demo/manual-wrap` | GET | 手動包裝 — 用 `ApiResponse.ok()` 自行控制 |
| `/api/response-demo/products/{id}` | GET | 自訂 ErrorCode — `id > 100` 拋 `PRODUCT_NOT_FOUND` (404) |
| `/api/response-demo/products` | POST | 自訂 ErrorCode + 覆蓋訊息 — name=iPhone 拋 409 |
| `/api/response-demo/orders/{id}` | GET | 靜態工廠 — `BusinessException.notFound()` (404) |
| `/api/response-demo/orders/{id}` | DELETE | 靜態工廠 — `BusinessException.forbidden()` (403) |
| `/api/response-demo/orders/{id}/cancel` | POST | 靜態工廠 — `ORDER_ALREADY_CANCELLED` (400) |
| `/api/response-demo/rate-limit` | GET | 通用 ErrorCode — `CommonErrorCode.TOO_MANY_REQUESTS` (429) |
| `/api/response-demo/external-call` | GET | 異常鏈 — 包裝原始 cause，log 有堆疊但 API 不暴露 |
| `/api/response-demo/error-codes` | GET | 列出所有 `ShowcaseErrorCode` — 給前端的錯誤碼字典 |

#### 自訂錯誤碼範例（`ShowcaseErrorCode`）

```
SC_Axxx → 參數錯誤（400）
SC_Bxxx → 業務錯誤（404/409）
SC_Cxxx → 系統錯誤（502/503）
```

### Attachment Demo

| API | 方法 | 說明 |
|-----|------|------|
| `/api/attachment-demo/upload` | POST | 上傳附件（multipart，參數：file, ownerType, ownerId） |
| `/api/attachment-demo/{id}` | GET | 查詢單一附件 metadata |
| `/api/attachment-demo/download/{id}` | GET | 下載附件（streaming） |
| `/api/attachment-demo/list` | GET | 依 owner 查詢附件列表（參數：ownerType, ownerId） |
| `/api/attachment-demo/{id}` | DELETE | 軟刪除附件 |

### Report Demo

| API | 方法 | 說明 |
|-----|------|------|
| `/api/report-demo/export-employees` | GET | 同步匯出員工 Excel（EasyExcel，單 Sheet） |
| `/api/report-demo/export-multi-sheet` | GET | 多 Sheet Excel（Sheet1: 員工清單, Sheet2: 部門統計） |
| `/api/report-demo/export-pivot` | GET | 樞紐分析表（Sheet1: 原始資料, Sheet2: 部門薪資 Pivot Table） |
| `/api/report-demo/export-pivot-large` | GET | 10 萬筆樞紐分析（效能測試，SUM/AVG/MAX/MIN/COUNT） |
| `/api/report-demo/export-merged` | GET | 多 Context 合併匯出（每個 Context 各一個 Sheet） |
| `/api/report-demo/export-employees-async` | GET | 非同步匯出（回傳 UUID，背景產製後下載） |
| `/api/report-demo/export-employees-docx` | GET | xDocReport 匯出員工 Word（Velocity 範本套表） |
| `/api/report-demo/export-with-logo?attachmentId=1` | GET | Word + Logo 圖片（從 Attachment 讀取插入標題下方） |
| `/api/report-demo/export-employees-pdf` | GET | JasperReports 匯出員工 PDF |
| `/api/report-demo/export-employees-jasper-xlsx` | GET | JasperReports 匯出員工 XLSX |
| `/api/report-demo/engines` | GET | 列出可用報表引擎（含 JASPER） |
| `/api/reports/status/{uuid}` | GET | 查詢非同步報表產製狀態 |
| `/api/reports/download/{uuid}` | GET | 下載已完成的報表 |

### System

| API | 方法 | 說明 |
|-----|------|------|
| `/api/system/env` | GET | 查詢環境資訊（datasource URL、active profile） |

---

## 資料庫管理（Flyway）

使用 **Flyway** 管理所有資料表的建立與資料初始化，migration 檔案位於 `src/main/resources/db/migration/`：

| 版本 | 檔案 | 用途 |
|------|------|------|
| V1 | `V1__create_security_tables.sql` | Security Starter 所需表 |
| V2 | `V2__create_attachment_tables.sql` | Attachment Starter 所需表 |
| V3 | `V3__create_report_tables.sql` | Report Starter 所需表 |
| V4 | `V4__create_showcase_tables.sql` | Showcase 專案業務表（如 employee） |
| V5 | `V5__insert_initial_data.sql` | 初始資料（角色、admin 帳號、測試員工） |

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: none           # Flyway 管理 DDL，不讓 Hibernate 動
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true  # 既有資料庫第一次跑時自動 baseline
```

> **正式環境注意**：`baseline-on-migrate: true` 僅供初次導入 Flyway 使用，穩定後建議關閉。

---

## 自然人憑證（MOICA）登入流程

### 角色

- **瀏覽器（前端）**：代替真實 IC 讀卡機
- **後端伺服器**：驗證憑證與簽章
- **MOICA（內政部）**：簽發 IC 卡憑證的 CA

### 流程

```
瀏覽器                                     後端伺服器
  │                                            │
  │  ① GET /api/auth/cert/login-token          │
  │ ────────────────────────────────────────▶  │
  │                                            │  產生隨機挑戰碼
  │                                            │  存 Redis（限時 5 分鐘）
  │  ② 回傳挑戰碼 "abc123xyz"                  │
  │ ◀──────────────────────────────────────── │
  │                                            │
  │  ③ 用 IC 卡私鑰對挑戰碼簽章                │
  │     產出 PKCS#7 封包（含公鑰憑證+簽章）     │
  │                                            │
  │  ④ POST /api/auth/cert/login               │
  │     送出挑戰碼 + PKCS#7                     │
  │ ────────────────────────────────────────▶  │
  │                                            │  ⑤ 驗挑戰碼（Redis 查＋作廢，防重放）
  │                                            │  ⑥ 驗 PKCS#7 簽章（公鑰解密比對雜湊）
  │                                            │  ⑦ 驗 CA 鏈（Issuer DN = MOICA）
  │                                            │  ⑧ 取出使用者資訊（CN、身分證後4碼）
  │                                            │  ⑨ 查/建帳號 → 核發 JWT
  │  ⑩ 回傳 Access Token + Refresh Token      │
  │ ◀──────────────────────────────────────── │
  │                                            │
  │  之後每次請求帶 Authorization: Bearer JWT   │
  │ ────────────────────────────────────────▶  │
```

### 核心防護機制

| 機制 | 目的 | 缺少時的風險 |
|------|------|-------------|
| **挑戰碼（一次性）** | 防重放攻擊 | 攔截封包即可冒充登入 |
| **私鑰簽章** | 證明持有 IC 卡 | 拿到憑證就能偽裝 |
| **CA 鏈驗證** | 確認憑證由政府簽發 | 自製憑證即可登入 |

### 簽章驗證原理

```
【簽章 — IC 卡端】                     【驗章 — 後端】

挑戰碼 "abc123xyz"                     收到：挑戰碼 + 簽章
       │                                     │          │
       │ SHA-256                     SHA-256  │          │ 公鑰解密
       ▼                                     ▼          ▼
  雜湊值 "e3b0c4..."                    "e3b0c4..."  "e3b0c4..."
       │                                        │      │
       │ 私鑰加密                                └─比對─┘
       ▼                                     相同 ✅ 驗章成功
  簽章 "A7F2C9..."                       不同 ❌ 拒絕登入
```

> 私鑰**從不離開 IC 卡**，能簽出正確簽章 = 實際持有該卡。

### 測試環境 vs 正式環境

| | 正式環境 | 測試環境（本專案） |
|--|---------|------------------|
| 簽章工具 | 真實 IC 讀卡機 + 自然人 IC 卡 | Web Crypto API 模擬 |
| CA 來源 | 內政部 MOICA 簽發 | 假 MOICA CA（`keys/fake-moica-ca.cer`） |
| 驗證邏輯 | 完全一致 | 完全一致 |

```yaml
care:
  security:
    citizen-cert:
      intermediate-cert-paths:
        - classpath:moica/MOICA2.cer      # 正式 MOICA CA
        - classpath:moica/MOICA3.cer      # 正式 MOICA CA
        - file:./keys/fake-moica-ca.cer   # 測試用假 CA
```

---

## 程式碼品質

整合 **Checkstyle** + **SpotBugs**，`mvn verify` 時自動檢查：

```bash
mvn verify  # 編譯 + Checkstyle + SpotBugs
```
