#!/bin/bash
# 從各 repo 同步 README 到 docs/
# 用法: ./scripts/sync-docs.sh (本地) 或 GitHub Actions 自動呼叫

DOCS_DIR="docs"
GITHUB_USER="yanchen184"

echo "=== Syncing docs from GitHub repos ==="

sync_file() {
  local repo=$1
  local src=$2
  local dest=$3
  local branch=${4:-main}

  echo "  $repo/$src → $dest"

  # 確保目標目錄存在
  mkdir -p "$(dirname "$DOCS_DIR/$dest")"

  local url="https://raw.githubusercontent.com/$GITHUB_USER/$repo/$branch/$src"
  local status=$(curl -s -o "$DOCS_DIR/$dest" -w "%{http_code}" "$url")

  if [ "$status" != "200" ]; then
    # 試 master branch
    url="https://raw.githubusercontent.com/$GITHUB_USER/$repo/master/$src"
    status=$(curl -s -o "$DOCS_DIR/$dest" -w "%{http_code}" "$url")
  fi

  if [ "$status" != "200" ]; then
    echo "    WARN: HTTP $status, skipped"
    rm -f "$DOCS_DIR/$dest"
  else
    echo "    OK"
  fi
}

# ===== Starters (company-common-starters) =====
sync_file "company-common-starters" "README.md" "starters/index.md"
sync_file "company-common-starters" "common-log-spring-boot-starter/README.md" "starters/common-log-spring-boot-starter.md"
sync_file "company-common-starters" "common-jpa-spring-boot-starter/README.md" "starters/common-jpa-spring-boot-starter.md"
sync_file "company-common-starters" "common-response-spring-boot-starter/README.md" "starters/common-response-spring-boot-starter.md"
sync_file "company-common-starters" "common-attachment-spring-boot-starter/README.md" "starters/common-attachment-spring-boot-starter.md"
sync_file "company-common-starters" "common-report/README.md" "starters/common-report.md"
sync_file "company-common-starters" "care-security/README.md" "starters/care-security.md"
sync_file "company-common-starters" "common-notification-spring-boot-starter/README.md" "starters/common-notification.md"

# ===== Showcase 後端 (starter-showcase) =====
sync_file "starter-showcase" "README.md" "showcase/index.md" "feature/response-starter"

# ===== Showcase 前端 (security-starter-demo-frontend) =====
sync_file "security-starter-demo-frontend" "README.md" "frontend/index.md"

echo "=== Sync complete ==="
