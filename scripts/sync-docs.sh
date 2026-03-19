#!/bin/bash
# 從各 repo 同步 README 到 docs/
# 用法: ./scripts/sync-docs.sh (本地) 或 GitHub Actions 自動呼叫

set -e
DOCS_DIR="docs"
TEMP_DIR="/tmp/starter-portal-sync"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "=== Syncing docs from GitHub repos ==="

# ===== 設定：要同步的 repo 和檔案 =====
GITHUB_USER="yanchen184"

sync_file() {
  local repo=$1
  local src=$2
  local dest=$3
  local branch=${4:-main}

  echo "  $repo/$src → $dest"
  local url="https://raw.githubusercontent./$GITHUB_USER/$repo/$branch/$src"
  local status=$(curl -s -o "$DOCS_DIR/$dest" -w "%{http_code}" "$url")

  if [ "$status" != "200" ]; then
    # 試 master branch
    url="https://raw.githubusercontent.com/$GITHUB_USER/$repo/master/$src"
    status=$(curl -s -o "$DOCS_DIR/$dest" -w "%{http_code}" "$url")
  fi

  if [ "$status" != "200" ]; then
    echo "    WARN: HTTP $status, skipped"
    rm -f "$DOCS_DIR/$dest"
  fi
}

# ===== Starters =====
sync_file "company-common-starters" "README.md" "starters/index.md"
sync_file "company-common-starters" "common-log-spring-boot-starter/README.md" "starters/common-log-spring-boot-starter.md"
sync_file "company-common-starters" "common-jpa-spring-boot-starter/README.md" "starters/common-jpa-spring-boot-starter.md"
sync_file "company-common-starters" "common-response-spring-boot-starter/README.md" "starters/common-response-spring-boot-starter.md"
sync_file "company-common-starters" "common-attachment-spring-boot-starter/README.md" "starters/common-attachment-spring-boot-starter.md"
sync_file "company-common-starters" "common-report/README.md" "starters/common-report.md"
sync_file "company-common-starters" "care-security/README.md" "starters/care-security.md"
sync_file "company-common-starters" "common-notification-spring-boot-starter/README.md" "starters/common-notification.md"

# ===== Showcase =====
sync_file "starter-showcase" "README.md" "showcase/index.md" "feature/response-starter"

# ===== Frontend =====
sync_file "security-starter-demo-frontend" "README.md" "showcase/frontend.md"

# ===== 開發日誌 =====
for i in 01 02 03 04 05 06 07 08 09; do
  # 用 GitHub API 列出檔案名稱太麻煩，直接用已知的檔名
  case $i in
    01) name="01-架構設計與PoC驗證" ;;
    02) name="02-安全強化與LDAP整合" ;;
    03) name="03-驗證碼與Common-Starter整合" ;;
    04) name="04-自然人憑證與前端整合" ;;
    05) name="05-TDD可行性評估" ;;
    06) name="06-CodeReview規範" ;;
    07) name="07-品質工程與模組重構" ;;
    08) name="08-附件管理與報表模組" ;;
    09) name="09-報表模組增強" ;;
  esac
  sync_file "care-security-docs" "docs/$name.md" "guide/$name.md"
done

echo "=== Sync complete ==="
