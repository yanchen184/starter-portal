#!/bin/bash
# 從各 repo 自動同步所有 README.md 到 docs/
# 自動掃描，不需手動維護清單
# 用法: ./scripts/sync-docs.sh

DOCS_DIR="docs"
GITHUB_USER="yanchen184"
SIDEBAR_FILE="docs/.vitepress/sidebar-generated.json"

echo "=== Syncing docs from GitHub repos ==="

# ===== 要同步的 repo 清單 =====
# 格式: repo_name:branch:docs_dir:display_name
# 只需要加 repo，裡面的 README 全自動掃描
REPOS=(
  "company-common-starters:main:starters:Starters"
  "starter-showcase:feature/response-starter:showcase:Showcase 後端"
  "security-starter-demo-frontend:master:frontend:Showcase 前端"
)

# 用 GitHub Tree API 列出 repo 裡所有 README.md（不需認證）
find_readmes() {
  local repo=$1
  local branch=$2
  local encoded_branch=$(echo "$branch" | sed 's|/|%2F|g')
  curl -s "https://api.github.com/repos/$GITHUB_USER/$repo/git/trees/$encoded_branch?recursive=1" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('tree', []):
    path = item.get('path', '')
    if path.endswith('README.md') and 'node_modules' not in path and 'target' not in path and 'test' not in path:
        print(path)
" 2>/dev/null
}

# 下載單一檔案
download_file() {
  local repo=$1
  local branch=$2
  local src=$3
  local dest=$4

  mkdir -p "$(dirname "$dest")"
  local url="https://raw.githubusercontent.com/$GITHUB_USER/$repo/$branch/$src"
  local status=$(curl -s -o "$dest" -w "%{http_code}" "$url")

  if [ "$status" = "200" ]; then
    return 0
  else
    rm -f "$dest"
    return 1
  fi
}

# 從 README 路徑推導顯示名稱
# README.md → 總覽
# common-log-spring-boot-starter/README.md → common-log-spring-boot-starter
# care-security/common-security-core/README.md → care-security/common-security-core
path_to_name() {
  local path=$1
  local dir=$(dirname "$path")
  if [ "$dir" = "." ]; then
    echo "總覽"
  else
    echo "$dir"
  fi
}

# ===== 開始同步 =====
echo "{" > "$SIDEBAR_FILE"
first_repo=true

for entry in "${REPOS[@]}"; do
  IFS=':' read -r repo branch docs_dir display_name <<< "$entry"
  echo ""
  echo "--- $display_name ($repo @ $branch) ---"

  # 清空目標目錄
  mkdir -p "$DOCS_DIR/$docs_dir"
  rm -f "$DOCS_DIR/$docs_dir"/*.md 2>/dev/null

  # 列出所有 README.md
  readmes=$(find_readmes "$repo" "$branch")

  if [ -z "$readmes" ]; then
    echo "  WARN: API failed, trying root README only"
    readmes="README.md"
  fi

  echo "  Found $(echo "$readmes" | wc -l | tr -d ' ') README(s)"

  # 收集 sidebar items
  sidebar_items=""
  first_item=true

  while IFS= read -r readme; do
    [ -z "$readme" ] && continue

    # 計算目標檔名
    dir=$(dirname "$readme")
    if [ "$dir" = "." ]; then
      dest_file="$DOCS_DIR/$docs_dir/index.md"
      link_path="/$docs_dir/"
    else
      safe_name=$(echo "$dir" | tr '/' '-')
      dest_file="$DOCS_DIR/$docs_dir/$safe_name.md"
      link_path="/$docs_dir/$safe_name"
    fi

    if download_file "$repo" "$branch" "$readme" "$dest_file"; then
      name=$(path_to_name "$readme")
      echo "    ✓ $name"

      if [ "$first_item" = true ]; then
        first_item=false
      else
        sidebar_items="$sidebar_items,"
      fi
      sidebar_items="$sidebar_items{\"text\":\"$name\",\"link\":\"$link_path\"}"
    fi
  done <<< "$readmes"

  # 寫入 sidebar JSON
  if [ "$first_repo" = true ]; then
    first_repo=false
  else
    echo "," >> "$SIDEBAR_FILE"
  fi
  printf '  "/%s/": [{"text":"%s","items":[%s]}]' "$docs_dir" "$display_name" "$sidebar_items" >> "$SIDEBAR_FILE"
done

echo "" >> "$SIDEBAR_FILE"
echo "}" >> "$SIDEBAR_FILE"

# ===== 生成首頁版本資訊 =====
echo ""
echo "--- Generating version info ---"

# 取得各 repo 的最後 commit 時間
python3 << 'PYEOF'
import json, urllib.request, datetime

user = "yanchen184"
repos = [
    ("company-common-starters", "main", "Starters BOM"),
    ("starter-showcase", "feature/response-starter", "Showcase 後端"),
    ("security-starter-demo-frontend", "master", "Showcase 前端"),
]

rows = []
for repo, branch, label in repos:
    try:
        url = f"https://api.github.com/repos/{user}/{repo}/commits/{branch}"
        req = urllib.request.Request(url, headers={"Accept": "application/vnd.github.v3+json"})
        data = json.loads(urllib.request.urlopen(req, timeout=10).read())
        date = data["commit"]["committer"]["date"][:10]
        msg = data["commit"]["message"].split("\n")[0][:60]
        rows.append(f"| {label} | `1.0.0` | {date} | {msg} |")
    except Exception as e:
        rows.append(f"| {label} | `1.0.0` | - | fetch failed |")

# 寫入 version info markdown
with open("docs/version-info.md", "w") as f:
    f.write("## 版本資訊\n\n")
    f.write("| 模組 | 版本 | 最後更新 | 最近改動 |\n")
    f.write("|------|------|---------|--------|\n")
    for row in rows:
        f.write(row + "\n")
    f.write(f"\n> 文件同步時間：{datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}\n")

print("  version-info.md generated")
PYEOF

echo ""
echo "=== Sync complete ==="
