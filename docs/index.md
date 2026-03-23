---
layout: home
hero:
  name: Company Starters
  text: 企業級 Spring Boot 共用元件庫
  tagline: 標準化、模組化、零配置 — 加入依賴即生效，專注業務邏輯開發
  actions:
    - theme: brand
      text: 快速開始
      link: /starters/
    - theme: alt
      text: 查看原始碼
      link: https://github.com/yanchen184/wez-spring-boot-starters

features:
  - icon: 🔐
    title: 安全認證
    details: JWT + OAuth2 Authorization Server、RBAC 權限矩陣、LDAP / OTP / CAPTCHA / 自然人憑證可插拔
    link: /starters/care-security
    linkText: 查看文件
  - icon: 📝
    title: 統一日誌
    details: API 自動記錄 → / ← 日誌、Micrometer Tracing 跨服務追蹤、敏感欄位遮罩、慢 API 告警
    link: /starters/common-log-spring-boot-starter
    linkText: 查看文件
  - icon: 📦
    title: 統一回應
    details: ApiResponse 自動包裝、全局異常處理（12 種異常）、錯誤碼體系（A/B/C/D 分類）
    link: /starters/common-response-spring-boot-starter
    linkText: 查看文件
  - icon: 📊
    title: 報表產製
    details: EasyExcel / xDocReport / JasperReports 多引擎、非同步產製、樞紐分析表、Redis 限流
    link: /starters/common-report
    linkText: 查看文件
  - icon: 📎
    title: 附件管理
    details: 檔案上傳/下載/軟刪除、Apache Tika 類型偵測、DB / 檔案系統雙模式、圖片壓縮
    link: /starters/common-attachment-spring-boot-starter
    linkText: 查看文件
  - icon: 🔔
    title: 通知系統
    details: 多通道（Email / WebSocket）、排程發送、失敗自動重試、Thymeleaf 模板渲染
    link: /starters/common-notification-spring-boot-starter
    linkText: 查看文件
---

<div class="quick-start-section">

<h2>三步驟開始使用</h2>

<div class="steps-grid">

<div class="step-card">
  <div class="step-number">1</div>
  <h3>引入 BOM</h3>
  <p>在專案 <code>pom.xml</code> 加入 BOM，統一管理所有 Starter 版本。</p>
  <pre><code class="language-xml">&lt;dependencyManagement&gt;
  &lt;dependencies&gt;
    &lt;dependency&gt;
      &lt;groupId&gt;com.company.common&lt;/groupId&gt;
      &lt;artifactId&gt;wez-spring-boot-starters&lt;/artifactId&gt;
      &lt;version&gt;1.0.0&lt;/version&gt;
      &lt;type&gt;pom&lt;/type&gt;
      &lt;scope&gt;import&lt;/scope&gt;
    &lt;/dependency&gt;
  &lt;/dependencies&gt;
&lt;/dependencyManagement&gt;</code></pre>
</div>

<div class="step-card">
  <div class="step-number">2</div>
  <h3>選擇 Starter</h3>
  <p>依需求挑選模組，不需要指定版本號。</p>
  <pre><code class="language-xml">&lt;dependencies&gt;
  &lt;dependency&gt;
    &lt;groupId&gt;com.company.common&lt;/groupId&gt;
    &lt;artifactId&gt;common-log-spring-boot-starter&lt;/artifactId&gt;
  &lt;/dependency&gt;
  &lt;dependency&gt;
    &lt;groupId&gt;com.company.common&lt;/groupId&gt;
    &lt;artifactId&gt;common-response-spring-boot-starter&lt;/artifactId&gt;
  &lt;/dependency&gt;
&lt;/dependencies&gt;</code></pre>
</div>

<div class="step-card">
  <div class="step-number">3</div>
  <h3>完成，零配置</h3>
  <p>啟動應用程式，所有功能自動生效。</p>
  <pre><code class="language-bash">mvn spring-boot:run</code></pre>
  <pre><code>INFO --&gt; POST /api/users user=admin
INFO &lt;-- 200 POST /api/users 45ms</code></pre>
  <p>需要客製化？每個模組都支援 <code>application.yml</code> 調整。</p>
</div>

</div>
</div>

<div class="tech-stack-section">
<h2>技術棧</h2>

| 項目 | 版本 | 說明 |
|------|------|------|
| Java | 21 | LTS 版本 |
| Spring Boot | 4.0.3 | 最新穩定版 |
| Spring Security | 7.x | OAuth2 Authorization Server |
| 資料庫 | MSSQL | SQL Server |
| 快取 | Redis | 分散式快取 + 限流 |
| 建置工具 | Maven 3.9+ | 多模組 BOM 管理 |
| 靜態分析 | Checkstyle + SpotBugs | 自動化程式碼品質檢查 |

</div>

<!--@include: ./version-info.md-->

<style>
.quick-start-section {
  max-width: 1152px;
  margin: 3rem auto 2rem;
  padding: 0 1.5rem;
}

.quick-start-section h2 {
  text-align: center;
  font-size: 1.8rem;
  font-weight: 700;
  margin-bottom: 2rem;
  color: var(--vp-c-text-1);
}

.steps-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
}

@media (max-width: 768px) {
  .steps-grid {
    grid-template-columns: 1fr;
  }
}

.step-card {
  background: var(--vp-c-bg-soft);
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  padding: 1.5rem;
  transition: border-color 0.25s, box-shadow 0.25s;
}

.step-card:hover {
  border-color: var(--vp-c-brand-1);
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
}

.step-card h3 {
  margin: 0.8rem 0 0.5rem;
  font-size: 1.15rem;
}

.step-card p {
  color: var(--vp-c-text-2);
  font-size: 0.9rem;
  line-height: 1.6;
}

.step-card pre {
  margin: 0.8rem 0;
  border-radius: 8px;
  font-size: 0.8rem;
}

.step-number {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--vp-c-brand-1);
  color: #fff;
  font-size: 0.9rem;
  font-weight: 700;
}

.tech-stack-section {
  max-width: 1152px;
  margin: 2rem auto;
  padding: 0 1.5rem;
}

.tech-stack-section h2 {
  text-align: center;
  font-size: 1.8rem;
  font-weight: 700;
  margin-bottom: 1.5rem;
  color: var(--vp-c-text-1);
}
</style>
