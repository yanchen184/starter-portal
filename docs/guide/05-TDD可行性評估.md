# TDD 可行性評估報告

**文件編號：** 05
**撰寫日期：** 2026-03-11
**適用階段：** 階段 2 -- 開發體系規範化與效能評估
**版本：** v1.0

---

## 1. 摘要

本報告依據階段 2 任務目標，針對「測試驅動開發（TDD）」導入之可行性進行量化評估。以 care-security 專案實際產出之 12 組 Phase Test（共 175 個測試案例）作為實證基礎，分析 TDD 在不同職級人員、不同模組類型下的適用性與產能影響。

**核心結論：** TDD 適合導入於核心安全邏輯、共用 Starter 及業務規則密集之模組；建議採「分級導入」策略，針對資深轉型同仁與初階開發人員設計差異化之學習路徑，以降低初期產能衝擊並最大化長期品質效益。

---

## 2. TDD 導入背景與目的

### 2.1 專案背景

團隊正從 Grails 5 遷移至 Spring Boot 4，涉及以下技術轉型要素：

| 項目 | 舊系統 | 新系統 |
|------|--------|--------|
| 框架 | Grails 5 (Groovy) | Spring Boot 4.0.3 (Java 21) |
| 測試框架 | Spock / JUnit 4/5 | JUnit 6 + AssertJ |
| ORM | GORM | Spring Data JPA + Hibernate 7 |
| 安全模組 | 自建 / Spring Security Plugin | 自研 care-security-starter |
| 建置工具 | Gradle (Grails convention) | Gradle (Spring Boot convention) |

### 2.2 導入目的

1. **以測試作為需求規格書**：在框架轉型期間，以測試案例精確定義「舊系統行為應如何在新系統中被保留」，降低遷移遺漏風險。
2. **建立共用元件的品質防護網**：care-security-starter、common-log-starter、common-jpa-starter 等共用元件將被多個系統依賴，必須確保行為正確性。
3. **作為知識傳遞工具**：資深人員撰寫的測試案例，可直接作為初階人員學習新架構的教材。
4. **量化評估產能影響**：為管理層提供決策依據，明確 TDD 的短期投入成本與長期回收預期。

---

## 3. 實踐成果分析

### 3.1 Phase Test 總覽

care-security 專案採用「Phase 分層」策略，將安全模組的功能拆分為 12 個漸進式測試階段。以下為各 Phase 的測試規模與覆蓋範圍：

| Phase | 名稱 | 測試數量 | 測試類型 | 覆蓋範圍 |
|-------|------|----------|----------|----------|
| 1 | Data Layer | 13 | 整合測試 | DB 連線、Entity 映射、Redis 連線 |
| 2 | UserDetailsService | 11 | 整合測試 | 使用者載入、角色授權、權限合併 |
| 3 | Password Encoder | 10 | 單元+整合 | BCrypt、Legacy SHA-512、DelegatingPasswordEncoder |
| 4 | Login Flow | 10 | 整合測試 | 登入成功/失敗、鎖定機制、稽核記錄 |
| 5 | JWT Token | 14 | 整合測試 | Token 生成、Claims 驗證、Refresh 輪替 |
| 6 | RBAC Permission | 13 | 整合測試 | CRUD 權限評估、JWT 整合、簡寫對映 |
| 7 | Redis Blacklist | 6 | 整合測試 | 黑名單機制、TTL 過期、登出黑名單 |
| 8 | Auth Controller | 10 | MockMvc 整合 | REST API 端點、HTTP 狀態碼、角色存取控制 |
| 9 | AutoConfiguration | 7 | 整合測試 | Bean 載入、Properties 綁定、條件化配置 |
| 10 | Org Permission | 25 | 整合+MockMvc | 組織權限切換、DAO 層查詢、向下相容 |
| 11 | OTP/TOTP | 41 | 全層級 | RFC 6238 演算法、設定/登入/停用流程、HTTP API |
| 12 | CAPTCHA | 15 | 整合+MockMvc | 圖形驗證碼生成、驗證、Login 整合、HTTP API |
| **合計** | | **175** | | |

### 3.2 測試命名規範分析

本專案的測試命名採用「業務場景描述式」，而非傳統的「方法名稱式」。以下列舉具體案例以說明此規範的優勢：

**傳統命名 vs. 業務場景命名對比：**

| 傳統命名 (不推薦) | 業務場景命名 (專案實際採用) |
|-------------------|---------------------------|
| `testLogin()` | `"4.1 Login success returns TokenResponse"` |
| `testLoginFail()` | `"4.3 Login fail with wrong password throws BadCredentialsException"` |
| `testLock()` | `"4.6 Account lock after max attempts (simulated)"` |
| `testVerify()` | `"11.3 Correct OTP code passes verification"` |

**業務場景命名的效益：**

1. **測試結果即可讀報告**：當 CI/CD 產出測試報告時，管理者與 QA 可直接讀懂每個案例在驗證什麼業務場景，無需閱讀程式碼。
2. **需求追溯性**：每個 `@DisplayName` 的編號（如 `4.1`、`11.3`）直接對應 Phase 中的驗收條件，實現從測試到需求的雙向追溯。
3. **知識傳遞效率**：初階人員閱讀測試名稱即可理解系統應有行為，降低學習曲線。

### 3.3 Phase 分層策略的效果

Phase 分層策略的核心理念是「**由底層向上、逐層驗證**」，其設計遵循以下原則：

```
Phase 1-3:  基礎設施層 (DB、Entity、Password)     ← 不依賴業務邏輯
Phase 4-7:  核心業務層 (Login、JWT、RBAC、Redis)   ← 依賴基礎設施
Phase 8:    整合層 (MockMvc Controller)            ← 依賴核心業務
Phase 9:    配置層 (AutoConfiguration)             ← 驗證組裝正確性
Phase 10-12: 進階功能 (Org、OTP、CAPTCHA)          ← 獨立特性模組
```

**此策略帶來的具體效益：**

1. **問題定位效率提升**：當 Phase 4 的登入測試失敗時，若 Phase 1-3 全部通過，可立即排除 DB 連線、Entity 映射、密碼編碼等底層問題，將除錯範圍縮限至 AuthService 本身。根據實際開發經驗，此策略將平均除錯時間從約 45 分鐘縮短至約 15 分鐘（估計減少 60-70%）。

2. **漸進式開發支持**：開發人員可從 Phase 1 開始，確認底層穩定後再進入 Phase 4，避免「上層邏輯與底層問題交織」的困境。

3. **平行開發可行性**：Phase 10 (Org)、Phase 11 (OTP)、Phase 12 (CAPTCHA) 彼此獨立，可由不同人員同步開發。

4. **回歸測試信心**：任何程式碼變更後，175 個測試全部通過即可確認未引入回歸問題。

### 3.4 Phase 11 (OTP/TOTP) -- TDD 最佳實踐範例

Phase 11 是本專案中最完整體現 TDD 精神的測試檔案，值得作為團隊推廣的參考範本。其特點包括：

**1. 測試檔案即規格書**

檔案頂端的區塊註解完整描述了每個 Nested Class 對應的 User Story 與驗收條件：

```
11.1 TOTP Algorithm Specification
    → What: RFC 6238 TOTP code generation and verification rules
    → Why: Foundation for all OTP features

11.2 OTP Setup Flow
    → What: User enables OTP on their account
    → Why: User story -- "As a user, I want to set up 2FA to secure my account"
```

**2. 實作檢查清單直接從測試推導**

```
[ ] TotpService -- RFC 6238 TOTP with Base32, 6 digits, 30s step, HmacSHA1
[ ] OtpService  -- setup, verify-setup, verify, disable
[ ] AuthService -- login() checks otpEnabled, completeOtpLogin() issues tokens
[ ] TokenResponse -- add requiresOtp field
[ ] OtpController -- REST endpoints
[ ] SecurityConfig -- permitAll rules
[ ] SaUser entity -- OTP_SECRET, OTP_ENABLED columns
```

此清單直接從測試案例反向推導而出，確保「每一行實作程式碼都有對應的測試驗證」。

**3. 41 個測試覆蓋完整的 User Story 生命週期**

從演算法層（Base32 編碼、TOTP 碼產生）、服務層（設定/驗證/停用流程）、到 HTTP 層（REST API 契約），形成完整的垂直切片測試。

---

## 4. 不同職級人員的產能影響量化評估

### 4.1 評估模型說明

以下評估基於以下假設：
- 「產能」定義為「單位時間內完成可交付功能的數量」
- 基準線為「不採用 TDD、僅在功能完成後補寫測試」的開發模式
- 時間軸分為三個階段：導入期（第 1-2 月）、適應期（第 3-4 月）、成熟期（第 5 月起）

### 4.2 資深轉型同仁（熟 Grails，學 Spring Boot + TDD）

**人員特徵：**
- 已具備業務領域知識（照管系統邏輯）
- 熟悉 Groovy/Spock 測試風格，但需轉換至 Java/JUnit 6/AssertJ
- 需同時學習 Spring Boot 4 生態系

| 階段 | 預估產能變化 | 說明 |
|------|-------------|------|
| 導入期 (1-2 月) | **-30% ~ -40%** | 雙重學習曲線：Spring Boot 4 新特性 + TDD 流程紀律。Grails 的 convention-over-configuration 慣性需要打破。 |
| 適應期 (3-4 月) | **-10% ~ -15%** | Spring Boot 已熟悉，TDD 流程開始內化。撰寫測試的時間投入仍高於傳統模式。 |
| 成熟期 (5 月起) | **+5% ~ +15%** | TDD 帶來的除錯時間減少開始顯現效益。測試作為規格書減少溝通成本。回歸測試信心提升，重構意願增加。 |

**關鍵風險：** Grails 經驗豐富的資深同仁可能對 TDD 流程產生抵觸心理（「我寫程式 10 年了，為什麼要先寫測試？」），需搭配管理層明確支持與實際案例展示（例如 Phase 11 的 OTP 開發經驗）來化解。

**緩解措施：**
- 提供 Spock → JUnit 6 + AssertJ 的語法對照表
- 以 care-security Phase Test 作為範本，讓資深同仁理解「測試即規格書」的價值
- 初期由架構師（本報告撰寫者）Pair Programming 引導

### 4.3 初階開發人員（新人 + TDD）

**人員特徵：**
- Java 基礎能力具備，但缺乏大型系統開發經驗
- 無 Spring Boot 或測試框架使用經驗
- 需要從零建立「測試思維」

| 階段 | 預估產能變化 | 說明 |
|------|-------------|------|
| 導入期 (1-2 月) | **-50% ~ -60%** | 同時學習 Spring Boot + JUnit 6 + AssertJ + TDD 方法論，認知負荷極高。 |
| 適應期 (3-4 月) | **-25% ~ -30%** | 開始能獨立撰寫簡單的 Phase 1-3 層級測試，但複雜業務邏輯的測試設計仍需指導。 |
| 成熟期 (5 月起) | **-5% ~ +5%** | TDD 流程已內化，產能趨近基準線。由於從一開始就養成測試習慣，後期的程式碼品質與除錯效率優於「先寫功能後補測試」的同級人員。 |

**關鍵優勢：** 初階人員反而更適合從一開始就接受 TDD 訓練，因為沒有「先寫功能再補測試」的舊習慣需要打破。Phase Test 分層策略特別適合新人學習路徑：

```
新人第 1 週：學習 Phase 1-3（基礎設施層測試，理解斷言語法）
新人第 2 週：學習 Phase 4（業務邏輯測試，理解 @Transactional 與狀態管理）
新人第 3 週：學習 Phase 8（MockMvc 整合測試，理解 HTTP 層）
新人第 4 週：嘗試為簡單功能撰寫 Phase Test
```

**緩解措施：**
- 提供 Phase 1 到 Phase 3 的「跟著做」教學，讓新人先模仿再理解
- 前 2 個月安排 Code Review 時，優先審查測試程式碼的品質
- 設定階段性目標：第 1 個月能獨立寫 Phase 1-3 層級測試，第 3 個月能獨立寫 Phase 4-7 層級測試

### 4.4 產能影響總覽圖

```
產能
 ^
 |                                          ___________  資深 (+15%)
 |                                     ____/
 |                                ____/                  初階 (+5%)
100% ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ 基準線
 |        \              ____/
 |         \         ___/
 |          \    ___/
 |           \__/         資深 (低點: -40%)
 |            \
 |             \___       初階 (低點: -60%)
 |                 \___
 |
 +──────────────────────────────────────────────────────> 時間
      第1月    第2月    第3月    第4月    第5月    第6月
      |← 導入期 →|← 適應期 →|←    成熟期     →|
```

### 4.5 投資回收估算

假設一個 5 人開發團隊（2 資深 + 3 初階），以月薪均值計算：

| 項目 | 數值 |
|------|------|
| 導入期（2 個月）累計產能損失 | 約 4.2 人月 |
| 適應期（2 個月）累計產能損失 | 約 1.8 人月 |
| 前 4 個月總投入成本 | 約 6.0 人月 |
| 成熟期每月節省（減少除錯 + 回歸問題） | 約 0.5-1.0 人月 |
| **預估投資回收期** | **10-16 個月** |

此估算尚未包含以下難以量化但確實存在的效益：
- 生產環境 Bug 減少帶來的維運成本降低
- 程式碼可維護性提升帶來的長期效率增益
- 新人 onboarding 時間縮短（測試即文件）

---

## 5. TDD 在本專案的適用場景分析

### 5.1 高度適合 TDD 的模組

| 模組 | 適用理由 | 參考案例 |
|------|----------|----------|
| **care-security-starter** | 核心安全邏輯，錯誤代價極高，行為必須精確可驗證 | Phase 1-12 全部 175 個測試 |
| **common-jpa-spring-boot-starter** | 審計欄位、軟刪除等通用行為需確保在各種 Entity 下一致 | 可參考 Phase 1 Data Layer 模式 |
| **common-log-spring-boot-starter** | Log 格式、TraceId 傳播等行為高度規格化 | 可參考 Phase 9 AutoConfiguration 模式 |
| **common-response-spring-boot-starter** | ApiResponse 格式、全域異常處理之 HTTP 狀態碼對映 | 可參考 Phase 8 MockMvc 模式 |
| **密碼策略 / 加密邏輯** | 密碼規則複雜，涉及 Legacy 格式相容，一旦出錯影響全體使用者 | Phase 3 Password Encoder（10 個測試涵蓋 BCrypt + SHA-512 + 委派） |
| **權限控制邏輯 (RBAC)** | 權限判斷必須精確，CRUD + Approve 五種操作的排列組合 | Phase 6（13 個測試涵蓋所有 CRUD 操作 + 簡寫 + JWT 整合） |
| **Token 生命週期管理** | Refresh Token 輪替、黑名單機制涉及安全性 | Phase 5 + Phase 7（20 個測試） |
| **多因素驗證 (OTP/CAPTCHA)** | 流程複雜且涉及安全性，需要完整的狀態機測試 | Phase 11（41 個測試）+ Phase 12（15 個測試） |

### 5.2 適度適合 TDD 的模組

| 模組 | 適用方式 | 說明 |
|------|----------|------|
| **業務 Service 層** | 先寫核心邏輯測試，CRUD 部分可後補 | 業務規則部分用 TDD，簡單的 CRUD 操作用傳統方式即可 |
| **DTO / Request Validation** | 可用 TDD 定義驗證規則 | Bean Validation 的邊界條件適合先定義測試 |
| **排程任務 (Scheduler)** | 核心邏輯用 TDD，排程觸發機制用整合測試 | 將業務邏輯抽離至可測試的 Service |

### 5.3 不適合 TDD 的模組

| 模組 | 原因 | 建議替代方案 |
|------|------|-------------|
| **前端 UI 介面** | 視覺呈現與互動體驗難以用 TDD 精確定義 | E2E 測試 (Playwright)、手動 QA |
| **技術原型 (PoC)** | PoC 的目的是快速驗證可行性，TDD 會拖慢探索速度 | PoC 確認方向後，正式開發時再補 TDD |
| **資料庫 Migration Script** | DDL/DML 腳本本身不適合 TDD | 用 Flyway/Liquibase 管理，搭配 Phase 1 式的「資料存取驗證測試」 |
| **組態檔 (yml/properties)** | 組態值的正確性已由 Phase 9 AutoConfiguration 測試覆蓋 | 參考 Phase 9 的 Properties 綁定測試 |
| **第三方系統整合（初期）** | 外部 API 行為不可控，Mock 成本高 | 先用 Contract Testing 定義介面，穩定後再補整合測試 |

---

## 6. 風險與挑戰

### 6.1 高風險項目

| 風險 | 影響等級 | 發生機率 | 緩解措施 |
|------|----------|----------|----------|
| **資深人員抵觸 TDD 流程** | 高 | 中 | 以 care-security 實際成果展示效益；管理層明確表態支持；不強制所有模組都用 TDD，允許「適度適用」 |
| **初期產能下降導致專案延遲** | 高 | 高 | 在排程中預留 20-30% 緩衝時間；優先在新功能而非遷移模組導入 TDD |
| **測試品質不佳（為寫而寫）** | 中 | 中-高 | 建立 Code Review 清單，審查測試的業務場景描述品質；定期檢視測試命名是否符合規範 |

### 6.2 中風險項目

| 風險 | 影響等級 | 發生機率 | 緩解措施 |
|------|----------|----------|----------|
| **測試環境維護成本** | 中 | 中 | 使用 Docker Compose 統一管理 MSSQL + Redis + OpenLDAP；`@CareSecurityTest` 統一 Profile 切換 |
| **測試執行時間過長** | 中 | 中 | 分層策略已天然支持「只跑受影響的 Phase」；考慮 Testcontainers 減少環境依賴 |
| **TDD 與 Agile Sprint 節奏衝突** | 中 | 中 | Sprint Planning 時將「撰寫測試」與「實作功能」合併估算為同一 Story Point |

### 6.3 低風險項目

| 風險 | 影響等級 | 發生機率 | 緩解措施 |
|------|----------|----------|----------|
| **JUnit 6 + AssertJ 學習曲線** | 低 | 低 | AssertJ 的 fluent API 對新手友善；Phase 1-3 已提供充分語法範例 |
| **Mockito 過度使用導致假陽性** | 低 | 中 | care-security 的測試策略已偏向整合測試（真實 DB + Redis），減少 Mock 層級 |

---

## 7. TDD Demo — 實戰教學範本

為降低 TDD 學習門檻，我們在 **starter-showcase** 專案的 `feature/tdd-demo` 分支中，建立了一個完整的 TDD 實戰範例。與 care-security Phase 11 這類「已完成的成果」不同，TDD Demo 保留了完整的 **Red-Green-Refactor 過程**，讓學習者可以透過 `git log` 逐步回溯每一步決策。

### 7.1 Demo 概要

| 項目 | 說明 |
|------|------|
| **倉庫** | [starter-showcase](https://github.com/yanchen184/starter-showcase) `feature/tdd-demo` 分支 |
| **需求** | 電商訂單系統：建立訂單 + 取消訂單 API |
| **測試數量** | 16 個（Service 7 + Controller 6 + Validation 3） |
| **Commit 數** | 11 個（SETUP × 1, RED × 4, GREEN × 4, REFACTOR × 2） |

### 7.2 三階段 TDD 節奏

```
Phase 1 — Service 層（Mockito 純單元測試）
  [RED]      寫測試：建立訂單金額計算 → 編譯失敗（OrderService 不存在）
  [GREEN]    實作最小版本讓測試通過
  [RED]      寫測試：商品不存在 / 庫存不足 / 扣庫存 → 3 個失敗
  [GREEN]    加入 BusinessException + 庫存邏輯 → 全部通過
  [RED]      寫測試：取消訂單 → 編譯失敗（cancelOrder 不存在）
  [GREEN]    實作 cancelOrder → 全部通過
  [REFACTOR] 抽方法 + OrderStatus 常數 → 行為不變

Phase 2 — Controller 層（MockMvcTester + @MockitoBean）
  [RED]      寫 API 測試 → 編譯失敗（OrderController 不存在）
  [GREEN]    實作 Controller + 修正 Spring Boot 4 配置 → 全部通過

Phase 3 — 參數驗證（@Valid）
  [GREEN]    quantity=0 / 空白名稱 / null productId → 全部通過
```

### 7.3 Spring Boot 4 新技術展示

Demo 中刻意展示了以下 Spring Boot 4 / JUnit 6 新寫法，作為團隊學習參考：

| 新技術 | 舊寫法 | 新寫法 | Demo 中的使用位置 |
|--------|--------|--------|-------------------|
| **MockMvcTester** | `mockMvc.perform(post(...)).andExpect(status().isOk())` | `assertThat(mockMvcTester.post().uri(...)).hasStatus(OK).bodyJson().extractingPath("$.data")` | `OrderControllerTest` |
| **@MockitoBean** | `@MockBean` (已廢棄) | `@MockitoBean` | `OrderControllerTest` |
| **@WebMvcTest 新 package** | `o.s.b.test.autoconfigure.web.servlet` | `o.s.b.webmvc.test.autoconfigure` | `OrderControllerTest` |
| **spring-boot-webmvc-test** | 包含在 spring-boot-starter-test | 獨立模組，需額外加依賴 | `pom.xml` |
| **assertAll** | 逐行 assert（一個失敗就停） | `assertAll("分組名", () -> ..., () -> ...)` 全部跑完再報告 | `OrderServiceTest` |
| **satisfies** | `.extracting("code").isEqualTo(...)` | `.satisfies(ex -> { ... })` 驗證異常多屬性 | `OrderServiceTest` |

### 7.4 教學使用方式

**方式一：逐 Commit 閱讀（推薦）**

```bash
git clone https://github.com/yanchen184/starter-showcase.git
git checkout feature/tdd-demo
git log --oneline --reverse

# 從 [SETUP] 開始，逐個 checkout 每個 commit
# 觀察每一步：測試先寫了什麼？實作做了什麼最小改動？
```

**方式二：自己動手做**

```bash
git checkout feature/tdd-demo~11   # 回到 SETUP
# 看 TDD-DEMO.md 的需求，自己嘗試 Red-Green-Refactor
# 卡住時 checkout 下一個 commit 看答案
```

---

## 8. 建議與結論

### 8.1 分級導入策略（建議方案）

建議採用「**三級導入**」策略，而非全面強制推行：

| 等級 | 適用範圍 | TDD 要求 | 測試覆蓋率目標 |
|------|----------|----------|---------------|
| **Level A（強制 TDD）** | 共用 Starter（security、log、jpa、response）、核心安全邏輯 | 必須先寫測試再寫實作，PR 需附測試 | >= 90% |
| **Level B（鼓勵 TDD）** | 業務 Service 層核心邏輯、複雜查詢 | 鼓勵 TDD，至少需有測試覆蓋 | >= 70% |
| **Level C（測試優先但不強制 TDD）** | CRUD Controller、DTO、簡單查詢 | 需有測試，但可在功能完成後撰寫 | >= 50% |

### 8.2 Phase Test 規範建議

基於 care-security 的成功經驗，建議制定以下團隊規範：

1. **測試檔案命名**：`Phase{N}_{功能名稱}Test.java`，例如 `Phase1_DataLayerTest.java`
2. **測試方法命名**：使用 `@DisplayName("{Phase}.{序號} {業務場景描述}")`，例如 `"4.1 Login success returns TokenResponse"`
3. **Nested Class 分組**：按 User Story 分組，而非按 Class 分組
4. **TDD 引導註解**：參考 Phase 11 的格式，在測試檔案頂端撰寫「User Story → 驗收條件 → 實作清單」
5. **統一測試註解**：使用 `@CareSecurityTest` 類似的組合註解，統一管理 Profile 與 SpringBootTest 配置

### 8.3 導入時程建議

| 時間 | 里程碑 | 產出物 |
|------|--------|--------|
| 第 1 月 | TDD 教育訓練 + Phase 1-3 範例練習 | 每人完成至少一組 Phase 1 級別的測試 |
| 第 2 月 | 在 common-jpa-starter 實踐 TDD | 至少 20 個測試覆蓋審計欄位、軟刪除 |
| 第 3 月 | 在 common-response-starter 實踐 TDD | 至少 15 個測試覆蓋 ApiResponse、異常處理 |
| 第 4 月 | 回顧與調整，產出《團隊 TDD 規範 v1.0》 | 正式文件 + 範本庫 |

### 8.4 結論

1. **TDD 導入是可行的**，且已有 care-security 的 175 個測試作為實證。Phase 分層策略與業務場景命名規範的成功經驗，證明 TDD 不僅是「多寫測試」，更是一種有效的需求管理與知識傳遞工具。

2. **初期產能下降是必然的代價**，但在合理的導入策略下（分級導入、漸進式推廣），預計 5-6 個月後可達到產能平衡，10-16 個月後完成投資回收。

3. **不建議全面強制 TDD**，而是根據模組的業務關鍵性與複雜度，採用三級導入策略。核心安全邏輯與共用 Starter 強制 TDD，業務邏輯鼓勵 TDD，簡單 CRUD 不強制。

4. **Phase 11 (OTP/TOTP) 應作為團隊培訓的標準範本**，其「測試即規格書 + 實作清單」的模式，是 TDD 在企業環境中最具說服力的實踐案例。

5. **starter-showcase TDD Demo 應作為入門教材**（見 Section 7），讓團隊成員在 30 分鐘內體驗完整的 Red-Green-Refactor 流程，並熟悉 Spring Boot 4 的 MockMvcTester、@MockitoBean 等新寫法。

---

**撰寫者：** 技術架構負責人
**審核者：** （待簽核）
**核准者：** （待簽核）
