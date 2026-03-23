#!/bin/bash
# 從各 repo 自動同步所有 README.md 到 docs/
# 自動掃描，不需手動維護清單
# 用法: ./scripts/sync-docs.sh

DOCS_DIR="docs"
GITHUB_USER="yanchen184"
SIDEBAR_FILE="docs/.vitepress/sidebar-generated.json"
TMPDIR_SIDEBAR=$(mktemp -d)

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
  local auth_header=""
  if [ -n "$GITHUB_TOKEN" ]; then
    auth_header="-H \"Authorization: token $GITHUB_TOKEN\""
  fi
  eval curl -s $auth_header "https://api.github.com/repos/$GITHUB_USER/$repo/git/trees/$encoded_branch?recursive=1" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('tree', []):
    path = item.get('path', '')
    if path.endswith('README.md') and 'node_modules' not in path and 'target' not in path and 'src/test' not in path:
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
  local auth_opts=""
  if [ -n "$GITHUB_TOKEN" ]; then
    auth_opts="-H \"Authorization: token $GITHUB_TOKEN\""
  fi
  local status=$(eval curl -s $auth_opts -o "$dest" -w "%{http_code}" "$url")

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
repo_index=0

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

  # 收集所有 items
  all_items=""

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

      # 收集到對應的群組
      all_items="$all_items|$name|$link_path|$dir"
    fi
  done <<< "$readmes"

  # 把這個 repo 的資料寫到暫存檔
  echo "$docs_dir" > "$TMPDIR_SIDEBAR/repo_${repo_index}.txt"
  echo "$display_name" >> "$TMPDIR_SIDEBAR/repo_${repo_index}.txt"
  echo "$all_items" >> "$TMPDIR_SIDEBAR/repo_${repo_index}.txt"
  repo_index=$((repo_index + 1))
done

# ===== 用 python 統一生成 sidebar JSON =====
echo ""
echo "--- Generating unified sidebar ---"

SIDEBAR_TMPDIR="$TMPDIR_SIDEBAR" SIDEBAR_REPO_COUNT="$repo_index" SIDEBAR_OUTPUT="$SIDEBAR_FILE" python3 << 'PYTHON_SCRIPT'
import sys, json, os

def pretty(name):
    """美化名稱：移除 common-/care-/-spring-boot-starter，- 換空白，首字母大寫"""
    n = name
    n = n.replace('-spring-boot-starter', '')
    n = n.replace('common-', '')
    n = n.replace('care-', '')
    n = n.replace('-', ' ')
    return n.strip().title() if n.strip() else name

def parse_items(raw):
    entries = []
    parts = raw.split('|')
    i = 1
    while i + 2 < len(parts):
        entries.append((parts[i], parts[i+1], parts[i+2]))
        i += 3
    return entries

def build_sidebar_group(display_name, entries):
    """把一個 repo 的 entries 轉成 VitePress sidebar group"""
    # 第一輪：收集哪些目錄有子模組
    has_children = set()
    for name, link, dir_path in entries:
        if '/' in dir_path and dir_path != '.':
            has_children.add(dir_path.split('/')[0])

    # 第二輪：分群組
    groups = {}
    standalone = []
    for name, link, dir_path in entries:
        if dir_path == '.':
            standalone.append({'text': name, 'link': link})
        elif '/' in dir_path:
            group = dir_path.split('/')[0]
            if group not in groups:
                groups[group] = []
            groups[group].append({'text': pretty(dir_path.split('/')[-1]), 'link': link})
        elif dir_path in has_children:
            if dir_path not in groups:
                groups[dir_path] = []
            groups[dir_path].insert(0, {'text': '總覽', 'link': link})
        else:
            standalone.append({'text': pretty(name), 'link': link})

    # 組合
    sidebar_items = list(standalone)
    for group_name in sorted(groups.keys()):
        sidebar_items.append({
            'text': pretty(group_name),
            'collapsed': True,
            'items': groups[group_name]
        })

    return {
        'text': display_name,
        'items': sidebar_items
    }

tmpdir = os.environ['SIDEBAR_TMPDIR']
repo_count = int(os.environ['SIDEBAR_REPO_COUNT'])
sidebar_file = os.environ['SIDEBAR_OUTPUT']

unified_sidebar = []

for i in range(repo_count):
    filepath = os.path.join(tmpdir, f'repo_{i}.txt')
    with open(filepath, 'r') as f:
        lines = f.read().split('\n', 2)
        docs_dir = lines[0]
        display_name = lines[1]
        raw_items = lines[2] if len(lines) > 2 else ''

    entries = parse_items(raw_items)
    if entries:
        group = build_sidebar_group(display_name, entries)
        unified_sidebar.append(group)
    else:
        # 即使沒有成功下載任何文件，也保留該 group 的總覽連結
        unified_sidebar.append({
            'text': display_name,
            'items': [{'text': '總覽', 'link': f'/{docs_dir}/'}]
        })

# 輸出統一的 sidebar 陣列
with open(sidebar_file, 'w') as f:
    json.dump(unified_sidebar, f, ensure_ascii=False, indent=2)

print(f'  Written {len(unified_sidebar)} groups to sidebar')
PYTHON_SCRIPT

# 清理暫存
rm -rf "$TMPDIR_SIDEBAR"

echo "  sidebar-generated.json written (unified)"

# ===== 生成首頁版本資訊 =====
echo ""
echo "--- Generating version info ---"

# 取得各 repo 的最後 commit 時間
generate_version_info() {
  local output="docs/version-info.md"
  local auth_header=""
  if [ -n "$GITHUB_TOKEN" ]; then
    auth_header="-H \"Authorization: token $GITHUB_TOKEN\""
  fi

  echo "## 版本資訊" > "$output"
  echo "" >> "$output"
  echo "| 模組 | 版本 | 最後更新 | 最近改動 |" >> "$output"
  echo "|------|------|---------|--------|" >> "$output"

  local items=(
    "company-common-starters:main:Starters BOM"
    "starter-showcase:feature/response-starter:Showcase 後端"
    "security-starter-demo-frontend:master:Showcase 前端"
  )

  for item in "${items[@]}"; do
    IFS=':' read -r repo branch label <<< "$item"
    local encoded=$(echo "$branch" | sed 's|/|%2F|g')
    local json=$(eval curl -s $auth_header "https://api.github.com/repos/$GITHUB_USER/$repo/commits/$encoded")
    local date=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['commit']['committer']['date'][:10])" 2>/dev/null || echo "-")
    local msg=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['commit']['message'].split(chr(10))[0][:50])" 2>/dev/null || echo "-")
    echo "| $label | \`1.0.0\` | $date | $msg |" >> "$output"
  done

  echo "" >> "$output"
  echo "> 文件同步時間：$(date '+%Y-%m-%d %H:%M')" >> "$output"
  echo "  version-info.md generated"
}
generate_version_info

echo ""
echo "=== Sync complete ==="
