# security-starter-demo-frontend

`care-security-starter` 的管理介面前端，搭配 `security-starter-demo` 後端使用。

## 專案結構

```
security-starter-demo-frontend/
├── package.json                    # 依賴：React 19, Vite, TypeScript, Axios
├── vite.config.ts                  # Vite 設定（proxy /api → localhost:8080）
├── index.html                      # HTML 入口
├── tsconfig.json                   # TypeScript 根設定
├── tsconfig.app.json               # App 端 TS 設定
├── tsconfig.node.json              # Node 端 TS 設定
├── eslint.config.js                # ESLint 設定
├── .node-version                   # Node.js 版本指定
└── src/
    ├── main.tsx                    # React 入口
    ├── App.tsx                     # 路由設定（React Router）
    ├── App.css                     # 全域樣式
    ├── types/index.ts              # TypeScript 型別定義
    ├── api/
    │   └── client.ts               # Axios 封裝（自動帶 JWT、401 自動 redirect）
    ├── context/
    │   └── AuthContext.tsx          # 登入狀態管理（Context + JWT 解析）
    ├── components/
    │   ├── Layout.tsx              # 側邊欄 + 頂部導航列
    │   ├── UserFormModal.tsx        # 新增/編輯使用者的 Modal
    │   └── ResetPasswordModal.tsx   # 重設密碼的 Modal
    └── pages/
        ├── LoginPage.tsx           # 登入頁
        ├── DashboardPage.tsx       # 首頁儀表板
        ├── UsersPage.tsx           # 帳號管理（CRUD）
        ├── RolesPage.tsx           # 角色管理 + 權限矩陣（CRUD checkbox）
        ├── MenuPage.tsx            # 選單樹狀結構
        ├── OrganizePage.tsx        # 組織樹狀結構
        └── ApiTestPage.tsx         # API 測試頁（手動測 endpoint）
```

## 檔案功能說明

| 檔案 | 功能 |
|------|------|
| `client.ts` | Axios instance，自動附加 `Authorization: Bearer` header，401 時清除 token 並跳轉登入 |
| `AuthContext.tsx` | React Context，管理 JWT token 狀態、解析 token claims（角色、權限、orgRoles） |
| `Layout.tsx` | 主框架：側邊欄導航（帳號/角色/選單/組織/API 測試）+ 頂部列（用戶名、登出） |
| `LoginPage.tsx` | 登入表單，呼叫 `POST /api/auth/login` |
| `DashboardPage.tsx` | 首頁，顯示當前用戶資訊 |
| `UsersPage.tsx` | 帳號管理 CRUD 頁面，支援新增、編輯、鎖定/解鎖、重設密碼 |
| `RolesPage.tsx` | 角色列表 + 展開後顯示 CRUD 權限矩陣（checkbox 勾選後可儲存） |
| `MenuPage.tsx` | 選單樹狀結構（唯讀顯示） |
| `OrganizePage.tsx` | 組織樹狀結構（唯讀顯示） |
| `ApiTestPage.tsx` | 手動測試各 API endpoint 的工具頁 |
| `UserFormModal.tsx` | 新增/編輯使用者的 Modal 表單 |
| `ResetPasswordModal.tsx` | 重設密碼的 Modal |

## 啟動方式

```bash
npm install
npm run dev
```

後端需先啟動：`cd ../security-starter-demo && mvn spring-boot:run -Dspring-boot.run.profiles=local`
