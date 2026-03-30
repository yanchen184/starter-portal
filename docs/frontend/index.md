# security-starter-demo-frontend

`starter-showcase` 後端的管理介面前端，展示所有公司共用 Starter 的能力。

---

## 技術棧

- **React 19** + **TypeScript** + **Vite**
- **React Router 7** — 路由
- **Axios** — API 呼叫（自動帶 JWT、401 自動跳轉登入）
- **STOMP + SockJS** — WebSocket 即時通知

---

## 啟動

```bash
npm install
npm run dev
```

前端：http://localhost:3000（代理 /api → http://localhost:8080）

---

## 頁面總覽

### 登入

| 頁面 | 功能 |
|------|------|
| LoginPage | 密碼登入 + 驗證碼 + 憑證登入（MOICA/GCA/MOEACA/XCA 四種切換） |

### 系統管理

| 頁面 | 路徑 | 功能 |
|------|------|------|
| Dashboard | /dashboard | 首頁儀表板（使用者資訊、JWT 內容） |
| Users | /users | 帳號管理 CRUD |
| Org Roles | /org-roles | 組織角色管理 |
| Roles | /roles | 角色管理 + 權限矩陣 checkbox |
| Permissions | /perms | 權限管理 CRUD |
| Menus Tree | /menus | 選單樹狀結構 |
| Organizations | /orgs | 組織樹狀結構 |
| Permission Test | /perm-test | API 權限測試工具 + 使用者切換 |

### Starter Demo

| 頁面 | 路徑 | 展示的 Starter |
|------|------|--------------|
| Certificate Login | /citizen-cert | care-security（MOICA/GCA/MOEACA/XCA 模擬讀卡機） |
| Log Demo | /log-demo | common-log |
| Report Demo | /report-demo | common-report（Excel/Word/PDF 下載） |
| Attachment Demo | /attachment-demo | common-attachment |
| Notification Demo | /notification-demo | common-notification（Email + WebSocket） |
| Signature Demo | /signature-demo | common-diagram（簽名板） |
| Family Tree Demo | /family-tree-demo | common-diagram（家系圖） |
| API Hub Demo | /api-hub-demo | common-api-hub（帳密換 Token + 管理資料） |

---

## 專案結構

```
src/
├── api/client.ts                  # Axios 封裝（JWT + 401 處理）
├── context/AuthContext.tsx         # 登入狀態管理（JWT + OTP + 憑證）
├── services/
│   ├── crypto-service.ts          # RSA 金鑰對 + mock 憑證產生
│   ├── x509-builder.ts            # X.509 憑證 ASN.1 DER 組裝（4 種憑證類型）
│   ├── pkcs7-builder.ts           # PKCS#7 SignedData 組裝
│   └── cert-api-service.ts        # 憑證 API 呼叫
├── components/
│   ├── Layout.tsx                 # 側邊欄 + 頂部導航
│   ├── UserFormModal.tsx          # 使用者表單 Modal
│   └── ResetPasswordModal.tsx     # 重設密碼 Modal
├── pages/                         # 16 個頁面
└── types/index.ts                 # TypeScript 型別定義
```

---

## 憑證登入（4 種類型）

Login 頁面和 CitizenCertPage 都支援切換憑證類型：

| 類型 | 卡片顏色 | 識別碼 | 說明 |
|------|---------|--------|------|
| MOICA | 金黃 | 身分證後四碼 | 自然人憑證 |
| GCA | 藍色 | 機關代碼 | 政府機關憑證 |
| MOEACA | 綠色 | 統一編號 | 工商憑證 |
| XCA | 紫色 | 組織代碼 | 組織及團體憑證 |

> Demo 環境中所有類型共用同一把假 MOICA CA（因為 openssl UTF-8 DN 編碼與 Java X500Principal 不相容）。正式環境各自獨立 CA。
