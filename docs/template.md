# README 撰寫規範

統一的 README 模板，確保所有模組文件格式一致、資訊完整。

<div class="download-bar">
  <a href="/starter-portal/README-TEMPLATE.md" download="README-TEMPLATE.md" class="download-btn">
    下載模板檔案（README-TEMPLATE.md）
  </a>
</div>

---

## 章節順序

所有 README 必須遵守以下順序，讀者越懶的章節放越前面：

| 順序 | 章節 | 回答的問題 | 必要性 |
|------|------|-----------|--------|
| 1 | `# 標題` + 一句話描述 | 這是什麼？ | 必要 |
| 2 | `## 加入後你的專案自動獲得` | 為什麼要用？ | 完整 Starter 必要 |
| 3 | `## 快速開始` | 怎麼最快跑起來？ | 必要 |
| 4 | `## 功能總覽` | 還有什麼功能？ | 必要 |
| 5 | `## 核心 API` | 進階怎麼用？ | 必要 |
| 6 | `## 配置` | 怎麼調整？ | 有配置才需要 |
| 7 | `## 設計決策` | 為什麼這樣做？ | 建議 |
| 8 | `## 依賴關係` | 跟其他模組的關係？ | 建議 |
| 9 | `## 專案結構與技術規格` | 程式碼在哪 + 技術查表 | 建議 |
| 10 | `## 版本` | 變更紀錄 | 必要 |

---

## 適用規則

不是每個章節都必須有，視模組類型決定：

| 模組類型 | 範例 | 需要的章節 |
|---------|------|-----------|
| 完整 Starter | log、response、security | 全部 10 節 |
| 子模組 | report-core、引擎 | 省略「加入後自動獲得」 |
| 空殼 Starter | report-starter | 只需 1-3 節 |
| 工具模組 | build-tools | 省略「快速開始」 |
| 測試模組 | report-test | 著重測試覆蓋 + 執行方式 |

### 其他規則

- 長 README（超過 200 行）在標題後加 `## 目錄`
- 配置章節必須是**完整可 copy 的 YAML**，含每個屬性的預設值
- 程式碼範例必須可直接 **copy-paste 執行**
- 章節之間用 `---` 分隔
- 使用繁體中文

---

## 模板結構預覽

以下是各章節的骨架，完整模板請點擊上方下載按鈕取得。

### 1. 標題

    # {模組名稱}

    {一句話描述} — {關鍵功能 A}、{關鍵功能 B}、{關鍵功能 C}

### 2. 加入後你的專案自動獲得

    | 功能 | 說明 |
    |------|------|
    | ... | ... |

> 用「加入前 vs 加入後」對照表最有說服力，參考 [Log Starter](/starters/common-log-spring-boot-starter)。

### 3. 快速開始

    ### 1. 引入依賴
    ### 2. 最小使用範例
    ### 3. 完成 — 不需要任何配置。

> 程式碼範例必須可直接 copy-paste 跑起來。

### 4. 功能總覽

    - **功能 A** — 說明
    - **功能 B** — 說明

### 5. 核心 API

    ### {主要 Class}

    | 方法 | 說明 |
    |------|------|
    | `method()` | ... |

> 搭配程式碼範例，讓使用者知道怎麼呼叫。

### 6. 配置

    common:
      {module}:
        enabled: true     # 是否啟用（預設 true）

> 必須是完整可 copy 的 YAML，含每個屬性的預設值和中文註解。

### 7. 設計決策

    | 要什麼 | 不要什麼 |
    |--------|----------|
    | ... | ... |

> 解釋「為什麼這樣做」和「為什麼不做某些事」。

### 8. 依賴關係

    {module}
    ├── common-xxx-starter   ← 說明
    └── common-yyy-starter   ← 說明

### 9. 專案結構與技術規格

    {module}/
    ├── src/main/java/...
    └── pom.xml

    | 項目 | 值 |
    |------|-----|
    | Java | 21 |

### 10. 版本

    - 1.0.0 — {初始版本說明}

---

## 範例參考

想看實際的 README 怎麼寫？以下是品質較好的範例：

| 模組 | 類型 | 特點 |
|------|------|------|
| [Log Starter](/starters/common-log-spring-boot-starter) | 完整 Starter | 「加入前 vs 加入後」對照表 |
| [Security](/starters/care-security) | 大型多模組 | 含目錄導覽、可選模組說明 |
| [EasyExcel 引擎](/starters/common-report-common-report-engine-easyexcel) | 子模組 | 4 種模式的程式碼範例 |
| [Build Tools](/starters/company-build-tools) | 工具模組 | 無 Java 程式碼，著重規則說明 |
| [Report Starter](/starters/common-report-common-report-spring-boot-starter) | 空殼 Starter | 只有 3 節 |
| [Signature](/starters/business-common-signature-spring-boot-starter) | 業務級 Starter | 完整 REST API + Entity 文件 |

<style>
.download-bar {
  display: flex;
  justify-content: center;
  margin: 1.5rem 0;
}

.download-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background: var(--vp-c-brand-1);
  color: #fff !important;
  border-radius: 8px;
  font-size: 0.95rem;
  font-weight: 600;
  text-decoration: none !important;
  transition: background 0.25s, box-shadow 0.25s;
}

.download-btn:hover {
  background: var(--vp-c-brand-2);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.download-btn::before {
  content: '⬇';
  font-size: 1.1rem;
}
</style>
