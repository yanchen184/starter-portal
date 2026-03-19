# Code Review 規範 — 資深工程師視角

> 建立日期：2026-03-16

---

## 一、著重看哪些東西

### 1. 設計與架構
- **職責是否單一** — 一個 class/method 只做一件事，不做兩件
- **模組邊界是否清晰** — 跨模組的依賴方向對不對（core 不應該依賴 auth-moica）
- **有沒有循環依賴** — A 依賴 B，B 依賴 A
- **抽象層次是否一致** — Controller 不應該直接操作 Redis，那是 Service 的事
- **有沒有把實作細節洩漏到介面** — DTO 不該帶 JPA entity，entity 不該出現在 Controller

### 2. 安全性
- **敏感資料有沒有 log 出來** — password、token、idno 不能明文印
- **challenge/token 是否 one-time use** — 防 replay attack
- **輸入驗證** — `@Valid`、boundary check，特別是從外部來的資料
- **錯誤訊息有沒有洩漏內部細節** — `Certificate chain validation failed` vs `NullPointerException at line 42`
- **hardcode 的 secret** — 金鑰、密碼不能寫死在程式碼

### 3. 異常處理
- **catch 的範圍是否太廣** — `catch (Exception e)` 後面只 log 然後繼續，這很危險
- **有沒有吞掉 exception** — catch 之後什麼都不做
- **錯誤有沒有向上正確傳遞** — 轉換成對應的 business exception，而不是讓 500 直接爆給前端

### 4. 可讀性與命名
- **命名是否表達意圖** — `data` vs `pkcs7EnvelopeBytes`
- **magic number/string** — `300` 應該是 `CHALLENGE_EXPIRE_SECONDS`
- **method 長度** — 超過 30 行就要問「這在做幾件事」
- **boolean 參數** — `doSomething(true, false, true)` 完全看不懂

### 5. 測試
- **有沒有測試** — 新功能沒有對應測試，直接退
- **測試在測行為還是在測實作** — `verify(mock, times(1)).call()` 這種測試沒有業務價值
- **邊界條件有沒有涵蓋** — null、空字串、過期、重複送出
- **測試之間有沒有互相依賴** — 跑順序不同結果不同就是爛測試

### 6. 效能陷阱
- **N+1 query** — loop 裡面呼叫 DB
- **沒有分頁的查詢** — `findAll()` 在大資料量會炸
- **Redis key 有沒有 TTL** — 忘了設 expire 就是 memory leak
- **不必要的序列化/反序列化** — 轉來轉去浪費 CPU

### 7. 死代碼
- **沒被呼叫的 method/class** — 沒有引用就刪，不要留
- **@Deprecated 但還在 production 路徑上的東西**
- **被 comment 掉的程式碼** — 留著只會製造困惑，用 git 追就好

---

## 二、工具規範

### 靜態分析（CI 強制擋）

| 工具 | 用途 |
|------|------|
| **Checkstyle** | 命名規範、import 順序、行長度 |
| **SpotBugs** | null dereference、resource leak、security bug |
| **PMD** | dead code、過複雜的 method、copy-paste detection |
| **ArchUnit** | 架構規則測試，例如「auth-moica 不能依賴 auth-otp」|

### 測試品質

| 工具 | 用途 |
|------|------|
| **JaCoCo** | 覆蓋率報告，設定 minimum threshold（80%）|
| **Mutation Testing (PIT)** | 確認測試真的有在測邏輯，而不是只跑過去 |

### PR 流程規範

```
PR 必須包含：
- [ ] 對應的測試
- [ ] 沒有新增 @SuppressWarnings 或 //noinspection
- [ ] 沒有無說明的 TODO
- [ ] commit message 說明 why，不只說 what
```

### ArchUnit 範例

```java
@Test
void authModulesShouldNotDependOnEachOther() {
    classes()
        .that().resideInPackage("..cert..")
        .should().onlyDependOnClassesThat()
        .resideInAnyPackage("..cert..", "..core..", "java..", "org.springframework..")
        .check(importedClasses);
}

@Test
void controllerShouldNotAccessRepository() {
    noClasses()
        .that().haveNameMatching(".*Controller")
        .should().dependOnClassesThat()
        .haveNameMatching(".*Repository")
        .check(importedClasses);
}
```

---

## 核心心態

> **PR 是給「未來的人」讀的，不是給機器跑的。**
>
> 問自己：「六個月後的我，看這段 code 能不能在 5 分鐘內理解它在做什麼、為什麼這樣做？」
