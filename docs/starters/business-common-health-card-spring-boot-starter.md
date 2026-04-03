# Common Health Card Spring Boot Starter

通用健保卡模組 — 健保卡資料 CRUD、狀態機管理、就醫紀錄、操作日誌（Event-driven）

---

## 加入後你的專案自動獲得

| 功能 | 加入前 | 加入後 |
|------|--------|--------|
| 健保卡 CRUD | 自己寫 Entity/Repo/Service | `healthCardService.create()` 一行搞定 |
| 卡片狀態管理 | if-else 散落各處 | `CardStatus` enum 內建狀態機，非法轉換自動攔截 |
| 就醫紀錄 | 自己建表、自己管關聯 | `addVisit()` / `getVisits()` |
| 操作日誌 | 每個方法手動寫 log | Event-driven 自動記錄，業務邏輯零侵入 |
| 讀卡操作 | 自己接讀卡機、自己記 log | `readCard(cardNumber)` 自動查詢 + 記錄 |
| 審計欄位 | 手動記錄 | 自動 createdBy / createdDate / lastModifiedBy / lastModifiedDate |

---

## 快速開始

### 1. 引入依賴

```xml
<dependency>
    <groupId>com.company.common</groupId>
    <artifactId>common-health-card-spring-boot-starter</artifactId>
</dependency>
```

> 需同時引入 `common-jpa-spring-boot-starter`。

### 2. 使用

```java
// 新增健保卡
HealthCardResponse card = healthCardService.create(
    new HealthCardCreateRequest("A123456789AB", "A123456789", "王小明",
        LocalDate.of(1990, 1, 1), LocalDate.of(2020, 6, 15), null)
);

// 讀卡（自動記錄操作日誌）
HealthCardResponse result = healthCardService.readCard("A123456789AB");

// 變更狀態（內建狀態機驗證）
healthCardService.changeStatus(cardId, new StatusChangeRequest(CardStatus.SUSPENDED, "卡片遺失處理中"));

// 新增就醫紀錄（僅 ACTIVE 卡片可用）
healthCardService.addVisit(cardId, new MedicalVisitCreateRequest(
    LocalDate.of(2025, 3, 15), "H001", "台大醫院",
    "J06.9", "上呼吸道感染", "陳醫師", null
));

// 查詢就醫紀錄
List<MedicalVisitResponse> visits = healthCardService.getVisits(cardId);
```

---

## 功能總覽

- **健保卡 CRUD** — 新增 / 依 ID 查詢 / 依身分證查詢
- **狀態機** — `CardStatus` enum 定義合法轉換規則，非法轉換拋出 `IllegalStateException`
- **就醫紀錄** — 關聯健保卡，僅 ACTIVE 卡片可新增，按就醫日期倒序查詢
- **操作日誌** — Event-driven，`@TransactionalEventListener` 在 commit 前自動寫入
- **讀卡操作** — 依卡號查詢有效卡片 + 發布 READ 事件
- **輸入驗證** — DTO compact constructor 驗證卡號（12碼英數）、身分證（台灣格式）
- **軟刪除** — HealthCardEntity 繼承 BaseEntity

---

## 狀態轉換規則

```
ACTIVE ──→ SUSPENDED ──→ ACTIVE
   │            │
   ├──→ LOST ───┼──→ ACTIVE
   │            │
   ├──→ EXPIRED │    （終態，不可轉換）
   │            │
   └──→ CANCELLED    （終態，不可轉換）
         ↑
    SUSPENDED / LOST 也可直接 → CANCELLED
```

| 來源 | 可轉換到 |
|------|----------|
| ACTIVE | SUSPENDED, LOST, EXPIRED, CANCELLED |
| SUSPENDED | ACTIVE, CANCELLED |
| LOST | ACTIVE, CANCELLED |
| EXPIRED | （無） |
| CANCELLED | （無） |

---

## 核心 API

### HealthCardService

| 方法 | 回傳 | 說明 |
|------|------|------|
| `create(request)` | `HealthCardResponse` | 新增（卡號不可重複） |
| `findById(id)` | `Optional<HealthCardResponse>` | 依 ID 查詢 |
| `findByNationalId(nationalId)` | `List<HealthCardResponse>` | 依身分證查詢（可能多張卡） |
| `changeStatus(id, request)` | `HealthCardResponse` | 狀態變更（內建狀態機驗證） |
| `addVisit(cardId, request)` | `MedicalVisitResponse` | 新增就醫紀錄（僅 ACTIVE） |
| `getVisits(cardId)` | `List<MedicalVisitResponse>` | 查詢就醫紀錄 |
| `readCard(cardNumber)` | `HealthCardResponse` | 讀卡操作 |

### HealthCardLogService

| 方法 | 回傳 | 說明 |
|------|------|------|
| `getLogsByCardId(cardId)` | `List<HealthCardLogResponse>` | 查詢操作日誌 |

### REST API（opt-in）

需設定 `common.health-card.web.enabled=true`：

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/health-cards` | 新增健保卡 |
| GET | `/health-cards/{id}` | 依 ID 查詢 |
| GET | `/health-cards?nationalId=A123456789` | 依身分證查詢 |
| PUT | `/health-cards/{id}/status` | 變更狀態 |
| POST | `/health-cards/{id}/visits` | 新增就醫紀錄 |
| GET | `/health-cards/{id}/visits` | 查詢就醫紀錄 |
| GET | `/health-cards/{id}/logs` | 查詢操作日誌 |
| POST | `/health-cards/read?cardNumber=xxx` | 讀卡操作 |

---

## DTO

```java
// 新增請求（compact constructor 驗證卡號、身分證格式）
record HealthCardCreateRequest(
    String cardNumber,     // 12 碼英數字
    String nationalId,     // 台灣身分證格式
    String holderName,
    LocalDate birthDate,
    LocalDate issueDate,
    String note
)

// 狀態變更
record StatusChangeRequest(CardStatus newStatus, String reason)

// 就醫紀錄
record MedicalVisitCreateRequest(
    LocalDate visitDate,
    String hospitalCode,
    String hospitalName,
    String diagnosisCode,  // 可選
    String diagnosisName,  // 可選
    String doctorName,     // 可選
    String note            // 可選
)
```

---

## Entity

```
HealthCardEntity extends BaseEntity
├── (繼承) deleted, version, createdDate, lastModifiedDate, createdBy, lastModifiedBy
├── id (Long, IDENTITY)
├── cardNumber (String, unique)
├── nationalId (String)
├── holderName (String)
├── birthDate (LocalDate)
├── issueDate (LocalDate)
├── status (CardStatus enum)
└── note (String)

MedicalVisitEntity extends AuditableEntity
├── id (Long, IDENTITY)
├── card (ManyToOne → HealthCardEntity)
├── visitDate (LocalDate)
├── hospitalCode / hospitalName
├── diagnosisCode / diagnosisName
├── doctorName
└── note

HealthCardLogEntity（無繼承，日誌只增不刪）
├── id (Long, IDENTITY)
├── cardId (Long)
├── action (LogAction enum)
├── detail (String)
├── operator (String)
└── actionTime (LocalDateTime)
```

---

## 配置

```yaml
common:
  health-card:
    enabled: true            # 是否啟用模組（預設 true）
    api-prefix: /api/health-cards  # REST 路徑前綴
    web:
      enabled: false         # 是否註冊 REST controller（預設 false）
```

---

## 設計決策

| 決策 | 原因 |
|------|------|
| `CardStatus` enum 內建狀態機 | 避免 Service 層散落 if-else，狀態轉換規則集中管理 |
| Event-driven 操作日誌 | 業務邏輯不被 log 寫入干擾，`@TransactionalEventListener` 保證同一交易 |
| DTO compact constructor 驗證 | 驗證邏輯離資料最近，Service 層不再重複檢查 |
| `Optional` 回傳而非 `null` | 強制呼叫端處理空值，消滅 NPE |
| `@RequestBody` record | 取代散落的 `@RequestParam`，參數集中、可測試 |
| `MedicalVisitEntity` 用 `AuditableEntity` | 就醫紀錄不需要軟刪除和樂觀鎖 |
| `HealthCardLogEntity` 無繼承 | 日誌是 append-only，不需要審計欄位 |
| Controller 預設關閉 | 避免不需要 REST API 的專案意外暴露端點 |

---

## 依賴關係

```
common-health-card-spring-boot-starter
├── common-jpa-spring-boot-starter   ← BaseEntity + SoftDeleteRepository
├── spring-boot-starter-data-jpa     ← (provided)
└── spring-boot-starter-web          ← (provided)
```

---

## 專案結構

```
business/common-health-card-spring-boot-starter/
├── pom.xml
└── src/
    ├── main/java/com/company/common/healthcard/
    │   ├── config/
    │   │   ├── HealthCardAutoConfiguration.java
    │   │   └── HealthCardProperties.java
    │   ├── dto/
    │   │   ├── HealthCardCreateRequest.java
    │   │   ├── HealthCardResponse.java
    │   │   ├── StatusChangeRequest.java
    │   │   ├── MedicalVisitCreateRequest.java
    │   │   ├── MedicalVisitResponse.java
    │   │   └── HealthCardLogResponse.java
    │   ├── entity/
    │   │   ├── HealthCardEntity.java
    │   │   ├── MedicalVisitEntity.java
    │   │   └── HealthCardLogEntity.java
    │   ├── enums/
    │   │   ├── CardStatus.java          # 含狀態轉換規則
    │   │   └── LogAction.java
    │   ├── event/
    │   │   ├── HealthCardEvent.java     # 操作事件 record
    │   │   └── HealthCardEventListener.java
    │   ├── repository/
    │   │   ├── HealthCardRepository.java
    │   │   ├── MedicalVisitRepository.java
    │   │   └── HealthCardLogRepository.java
    │   ├── service/
    │   │   ├── HealthCardService.java
    │   │   └── HealthCardLogService.java
    │   └── web/
    │       └── HealthCardController.java
    ├── main/resources/META-INF/spring/
    │   └── org.springframework.boot.autoconfigure.AutoConfiguration.imports
    └── test/java/
        ├── dto/HealthCardCreateRequestTest.java
        ├── enums/CardStatusTest.java
        └── service/HealthCardServiceTest.java
```

---

## 技術規格

| 項目 | 值 |
|------|-----|
| Java | 21 |
| Spring Boot | 4.0.3 |
| 資料庫表 | `HEALTH_CARD`, `HEALTH_CARD_VISIT`, `HEALTH_CARD_LOG` |
| 主鍵策略 | `IDENTITY` |
| 索引 | NATIONAL_ID, CARD_NUMBER(unique), CARD_ID+VISIT_DATE, CARD_ID+ACTION_TIME |
| 軟刪除 | `HealthCardEntity` 繼承 `BaseEntity.deleted` |
| 測試 | 41 個（DTO 驗證 + 狀態機 + Service Mockito 單元測試） |

---

## 版本

### 1.0.0

- 初始版本
- 健保卡 CRUD + 狀態機（ACTIVE / SUSPENDED / LOST / EXPIRED / CANCELLED）
- 就醫紀錄管理
- Event-driven 操作日誌
- 讀卡操作
- DTO compact constructor 輸入驗證
- 41 個單元測試
