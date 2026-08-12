#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"

version=$(tr -d '[:space:]' < VERSION)
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf 'VERSION 格式错误：%s\n' "$version" >&2
  exit 1
}

tag="v$version"
release_file="docs/releases/$tag.md"

[[ -f $release_file ]] || { printf '缺少版本说明：%s\n' "$release_file" >&2; exit 1; }
[[ -f docs/project-principles.md && -f docs/architecture.md && -f docs/modules.md ]] \
  || { printf '缺少项目宗旨、轻量架构或模块索引\n' >&2; exit 1; }
[[ -f .github/ISSUE_TEMPLATE/bug_report.yml \
   && -f .github/ISSUE_TEMPLATE/feature_request.yml \
   && -f .github/PULL_REQUEST_TEMPLATE.md ]] \
  || { printf '缺少GitHub故障、建议或贡献模板\n' >&2; exit 1; }
grep -Fq "## $tag " CHANGELOG.md || { printf 'CHANGELOG 缺少 %s\n' "$tag" >&2; exit 1; }
grep -Fq "当前推荐稳定版本：\`$tag\`" README.md || { printf 'README 未推荐 %s\n' "$tag" >&2; exit 1; }
grep -Fq "工具：\`$tag\`" docs/tutorial.md || { printf '完整教程未推荐 %s\n' "$tag" >&2; exit 1; }
grep -Fq -- "--branch $tag" docs/tutorial.md || { printf '完整教程下载命令未固定 %s\n' "$tag" >&2; exit 1; }
grep -Fq -- "--branch $tag" docs/windows-xshell.md || { printf 'Xshell 教程下载命令未固定 %s\n' "$tag" >&2; exit 1; }
grep -Fq '## 复杂度与性能影响' "$release_file" \
  || { printf '版本说明缺少“复杂度与性能影响”\n' >&2; exit 1; }
grep -Fq 'GOST 是唯一必要的常驻业务进程' docs/project-principles.md \
  || { printf '项目宗旨缺少常驻进程边界\n' >&2; exit 1; }
grep -Fq '新功能默认先评估能否作为插件' docs/project-principles.md \
  || { printf '项目宗旨缺少插件优先规则\n' >&2; exit 1; }
grep -Fq '功能变多不等于 2.0' docs/project-principles.md \
  || { printf '项目宗旨缺少主版本准入规则\n' >&2; exit 1; }
grep -Fq '正常工作时只有 GOST 常驻' docs/architecture.md \
  || { printf '架构说明缺少按需运行边界\n' >&2; exit 1; }
grep -Fq '## 修改路由' docs/modules.md \
  || { printf '模块索引缺少修改路由\n' >&2; exit 1; }
[[ -f addons/bbr/plugin.conf && -f addons/bbr/README.md ]] \
  || { printf '缺少 BBR 插件兼容声明或说明\n' >&2; exit 1; }
# shellcheck disable=SC1091
source addons/bbr/plugin.conf
[[ ${PLUGIN_VERSION:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || { printf 'BBR 插件版本格式错误\n' >&2; exit 1; }
[[ ${MAIN_MIN_VERSION:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && ${MAIN_MAX_MAJOR:-} =~ ^[0-9]+$ ]] \
  || { printf 'BBR 插件主程序兼容声明格式错误\n' >&2; exit 1; }
IFS=. read -r current_major current_minor current_patch <<<"$version"
IFS=. read -r minimum_major minimum_minor minimum_patch <<<"$MAIN_MIN_VERSION"
(( current_major <= MAIN_MAX_MAJOR )) || { printf 'BBR 插件尚未声明兼容主程序 %s\n' "$tag" >&2; exit 1; }
if (( current_major < minimum_major \
   || (current_major == minimum_major && current_minor < minimum_minor) \
   || (current_major == minimum_major && current_minor == minimum_minor && current_patch < minimum_patch) )); then
  printf 'BBR 插件要求主程序至少为 v%s\n' "$MAIN_MIN_VERSION" >&2
  exit 1
fi
grep -Fq "插件版本：\`$PLUGIN_VERSION\`" addons/bbr/README.md \
  || { printf 'BBR 插件说明中的版本不一致\n' >&2; exit 1; }
grep -Fq "BBR 插件 $PLUGIN_VERSION" "docs/releases/$tag.md" \
  || { printf '当前版本说明未记录 BBR 插件版本\n' >&2; exit 1; }

while IFS= read -r existing_tag; do
  [[ -f "docs/releases/$existing_tag.md" ]] || {
    printf '历史标签缺少版本说明：%s\n' "$existing_tag" >&2
    exit 1
  }
done < <(git tag --list 'v*' --sort=version:refname)

bash tests/syntax.sh

format_failed=false
while IFS= read -r text_file; do
  case "$text_file" in
    *.md|*.sh|*.yml|*.yaml|VERSION|.gitignore) ;;
    *) continue ;;
  esac
  [[ -f $text_file ]] || continue
  if grep -nE '[[:blank:]]+$' "$text_file"; then
    printf '文件存在行尾空白：%s\n' "$text_file" >&2
    format_failed=true
  fi
  if [[ -s $text_file && -z $(tail -n 1 "$text_file") ]]; then
    printf '文件末尾存在多余空行：%s\n' "$text_file" >&2
    format_failed=true
  fi
done < <(git ls-files --cached --others --exclude-standard | sort -u)
[[ $format_failed == false ]] || exit 1

git diff --check
git diff --cached --check

printf '版本 %s 的教程、说明和脚本检查通过。\n' "$tag"
