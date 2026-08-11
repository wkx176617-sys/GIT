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
grep -Fq "## $tag " CHANGELOG.md || { printf 'CHANGELOG 缺少 %s\n' "$tag" >&2; exit 1; }
grep -Fq "工具：\`$tag\`" docs/tutorial.md || { printf '完整教程未推荐 %s\n' "$tag" >&2; exit 1; }
grep -Fq -- "--branch $tag" docs/tutorial.md || { printf '完整教程下载命令未固定 %s\n' "$tag" >&2; exit 1; }
grep -Fq -- "--branch $tag" docs/windows-xshell.md || { printf 'Xshell 教程下载命令未固定 %s\n' "$tag" >&2; exit 1; }

while IFS= read -r existing_tag; do
  [[ -f "docs/releases/$existing_tag.md" ]] || {
    printf '历史标签缺少版本说明：%s\n' "$existing_tag" >&2
    exit 1
  }
done < <(git tag --list 'v*' --sort=version:refname)

bash tests/syntax.sh

if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git diff --check HEAD^ HEAD
fi

printf '版本 %s 的教程、说明和脚本检查通过。\n' "$tag"
