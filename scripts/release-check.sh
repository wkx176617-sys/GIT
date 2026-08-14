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
[[ -f AGENTS.md && -f docs/project-principles.md && -f docs/architecture.md \
   && -f docs/modules.md && -f docs/macos.md && -f docs/windows-xshell.md \
   && -f docs/clients.md && -f docs/visual-style.md && -f docs/upgrade.md \
   && -f docs/change-public-ip.md && -f docs/mobile-network-check.md \
   && -f docs/bitbrowser-fail-closed.md ]] \
  || { printf '缺少仓库规则、架构、模块索引、平台教程或客户端教程\n' >&2; exit 1; }
[[ -f .github/ISSUE_TEMPLATE/bug_report.yml \
   && -f .github/ISSUE_TEMPLATE/feature_request.yml \
   && -f .github/PULL_REQUEST_TEMPLATE.md ]] \
  || { printf '缺少GitHub故障、建议或贡献模板\n' >&2; exit 1; }
grep -Fq "## $tag " CHANGELOG.md || { printf 'CHANGELOG 缺少 %s\n' "$tag" >&2; exit 1; }
grep -Fq "当前推荐稳定版本：\`$tag\`" README.md || { printf 'README 未推荐 %s\n' "$tag" >&2; exit 1; }
grep -Fq "工具：\`$tag\`" docs/tutorial.md || { printf '第一次搭建总路线未推荐 %s\n' "$tag" >&2; exit 1; }
grep -Fq -- "--branch $tag" docs/windows-xshell.md || { printf 'Xshell 教程下载命令未固定 %s\n' "$tag" >&2; exit 1; }
grep -Fq -- "--branch $tag" docs/macos.md || { printf 'macOS 教程下载命令未固定 %s\n' "$tag" >&2; exit 1; }
grep -Fq '[macOS 部署指南](docs/macos.md)' README.md || { printf 'README 未提供macOS专用入口\n' >&2; exit 1; }
grep -Fq '[客户端导入与网络验收](docs/clients.md)' README.md \
  || { printf 'README 未提供客户端专用入口\n' >&2; exit 1; }
grep -Fq '[安全切换稳定版本](docs/upgrade.md)' README.md \
  || { printf 'README 未提供独立安全版本切换入口\n' >&2; exit 1; }
grep -Fq 'socksctl upgrade latest' docs/upgrade.md \
  && grep -Fq 'socksctl upgrade v目标版本号' docs/upgrade.md \
  && grep -Fq '不再要求输入第二个确认口令' docs/upgrade.md \
  && grep -Fq 'socksctl upgrade v旧版本号 --allow-downgrade' docs/upgrade.md \
  && grep -Fq 'socksctl upgrade --check v目标版本号' docs/upgrade.md \
  && grep -Fq '`--check` 严格只读' docs/upgrade.md \
  && grep -Fq '智能安装 / 升级路线' docs/upgrade.md \
  || { printf '版本切换专题缺少最新版主路径、单次授权、快照降版、只读检查或现状分流\n' >&2; exit 1; }
[[ $(grep -Fc 'socksctl upgrade latest' docs/upgrade.md) -eq 1 ]] \
  || { printf '版本切换专题必须只有一条已安装节点的最新版推荐命令\n' >&2; exit 1; }
if grep -Fq 'scripts/socks-upgrade --check' docs/upgrade.md; then
  printf '早期节点推荐路径不应要求单独执行只读检查\n' >&2
  exit 1
fi
grep -Fq 'socksctl export' docs/clients.md && grep -Fq 'socksctl qr shadowrocket' docs/clients.md \
  || { printf '客户端教程缺少链接或二维码说明\n' >&2; exit 1; }
grep -Fq 'v1.9.4 及以后会在安装或升级时自动' docs/clients.md \
  && grep -Fq 'apt-get install -y qrencode' docs/clients.md \
  || { printf '客户端教程缺少二维码依赖闭环或人工删除后的恢复说明\n' >&2; exit 1; }
grep -Fq 'socksctl refresh-ip --check' docs/change-public-ip.md \
  && grep -Fq 'socksctl refresh-ip' docs/change-public-ip.md \
  || { printf '换IP教程缺少只读检查或更新命令\n' >&2; exit 1; }
grep -Fq 'stopWhileNetError' docs/bitbrowser-fail-closed.md \
  && grep -Fq '代理直连白名单' docs/bitbrowser-fail-closed.md \
  || { printf '比特浏览器教程缺少网络错误停止或直连白名单\n' >&2; exit 1; }
grep -Fq 'Wi-Fi' docs/mobile-network-check.md && grep -Fq '手机流量' docs/mobile-network-check.md \
  || { printf '手机教程缺少Wi-Fi或流量切换检查\n' >&2; exit 1; }
grep -Fq '## 复杂度与性能影响' "$release_file" \
  || { printf '版本说明缺少“复杂度与性能影响”\n' >&2; exit 1; }
grep -Fq 'GOST 是唯一必要的常驻业务进程' docs/project-principles.md \
  || { printf '项目宗旨缺少常驻进程边界\n' >&2; exit 1; }
grep -Fq '新功能默认先评估能否作为插件' docs/project-principles.md \
  || { printf '项目宗旨缺少插件优先规则\n' >&2; exit 1; }
grep -Fq '功能变多不等于 2.0' docs/project-principles.md \
  || { printf '项目宗旨缺少主版本准入规则\n' >&2; exit 1; }
grep -Fq '单一主路径，按需展开' docs/project-principles.md \
  || { printf '项目宗旨缺少单一主路径规则\n' >&2; exit 1; }
grep -Fq 'docs/project-principles.md` 是项目宗旨、性能预算和功能准入条件的唯一完整来源' AGENTS.md \
  || { printf '仓库规则未指定项目宗旨的唯一完整来源\n' >&2; exit 1; }
grep -Fq '未知即停止' AGENTS.md \
  || { printf '仓库规则缺少未知故障停止边界\n' >&2; exit 1; }
grep -Fq '正常运行只允许 GOST 作为业务常驻进程' AGENTS.md \
  || { printf '仓库规则缺少常驻进程边界\n' >&2; exit 1; }
grep -Fq '单一主路径' AGENTS.md \
  || { printf '仓库规则缺少新手单一主路径边界\n' >&2; exit 1; }
grep -Fq '降版只恢复身份一致、校验通过的本机健康快照' AGENTS.md \
  || { printf '仓库规则缺少稳定版本切换与安全降版边界\n' >&2; exit 1; }
grep -Fq '[开发规则](AGENTS.md)' README.md \
  || { printf 'README 未提供仓库开发规则入口\n' >&2; exit 1; }
[[ -f assets/readme-hero.jpg ]] || { printf 'README 缺少本地视觉横幅\n' >&2; exit 1; }
grep -Fq '![柔和奶油粉色的安全网络连接插画](assets/readme-hero.jpg)' README.md \
  || { printf 'README 横幅缺少预期引用或替代文字\n' >&2; exit 1; }
hero_bytes=$(wc -c <assets/readme-hero.jpg)
(( hero_bytes <= 300000 )) || { printf 'README 横幅超过300KB预算\n' >&2; exit 1; }
grep -Fq 'docs/visual-style.md' AGENTS.md \
  || { printf '仓库规则未引用视觉风格约束\n' >&2; exit 1; }
grep -Fq '正常工作时只有 GOST 常驻' docs/architecture.md \
  || { printf '架构说明缺少按需运行边界\n' >&2; exit 1; }
grep -Fq '## 修改路由' docs/modules.md \
  || { printf '模块索引缺少修改路由\n' >&2; exit 1; }
[[ -f addons/README.md && -f addons/bbr/plugin.conf && -f addons/bbr/README.md ]] \
  || { printf '缺少插件中心、BBR兼容声明或说明\n' >&2; exit 1; }
grep -Fq '[可选插件中心](addons/README.md)' README.md \
  || { printf 'README 未提供独立插件中心入口\n' >&2; exit 1; }
while IFS= read -r plugin_conf; do
  plugin_dir=$(dirname "$plugin_conf")
  plugin_slug=$(basename "$plugin_dir")
  [[ -f "$plugin_dir/README.md" ]] || { printf '插件缺少独立说明：%s\n' "$plugin_slug" >&2; exit 1; }
  grep -Fq "($plugin_slug/README.md)" addons/README.md \
    || { printf '插件没有登记到插件中心：%s\n' "$plugin_slug" >&2; exit 1; }
done < <(find addons -mindepth 2 -maxdepth 2 -name plugin.conf -type f | sort)
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
bash tests/upgrade-flow.sh

grep -Fq 'shellcheck --severity=error' .github/workflows/validate.yml \
  || { printf 'GitHub Actions 缺少强制 ShellCheck\n' >&2; exit 1; }
grep -Fq 'gh release create' .github/workflows/validate.yml \
  && grep -Fq 'needs: validate' .github/workflows/validate.yml \
  || { printf '标签工作流缺少校验后的 GitHub Release 创建步骤\n' >&2; exit 1; }

for route_file in docs/tutorial.md docs/macos.md docs/windows-xshell.md; do
  route_lines=$(wc -l <"$route_file")
  (( route_lines <= 140 )) || {
    printf '新手路线超过140行预算：%s（%s行）\n' "$route_file" "$route_lines" >&2
    exit 1
  }
done
if rg -n 'socksctl[[:space:]]+qr|bbrctl[[:space:]]+(enable|repair|restore)' \
  docs/tutorial.md docs/macos.md docs/windows-xshell.md; then
  printf '新手路线重复了客户端二维码或插件操作，应链接唯一专题\n' >&2
  exit 1
fi
if rg -n 'git[[:space:]]+clone|xshell-install\.sh|\./deploy\.sh' docs/tutorial.md; then
  printf '第一次搭建总路线重复了平台安装命令，应只链接平台专题\n' >&2
  exit 1
fi
if rg -n 'git[[:space:]]+clone|xshell-install\.sh[[:space:]]+--port|\./deploy\.sh[[:space:]]+root@' README.md; then
  printf 'README 重复了平台安装命令，应只链接唯一平台专题\n' >&2
  exit 1
fi
if rg -n 'socks-upgrade[[:space:]]+(--check|latest|v[0-9])' \
  docs/tutorial.md docs/macos.md docs/windows-xshell.md; then
  printf '总路线或平台教程重复了版本切换命令，应只链接唯一专题\n' >&2
  exit 1
fi
grep -Fq '[客户端导入与网络验收](clients.md)' docs/macos.md \
  && grep -Fq '[客户端导入与网络验收](clients.md)' docs/windows-xshell.md \
  || { printf '平台教程没有统一进入客户端专题\n' >&2; exit 1; }
grep -Fq '[安全切换稳定版本](upgrade.md)' docs/macos.md \
  && grep -Fq '[安全切换稳定版本](upgrade.md)' docs/windows-xshell.md \
  || { printf '平台教程没有统一进入安全版本切换专题\n' >&2; exit 1; }

link_failed=false
while IFS= read -r markdown_file; do
  while IFS= read -r link_target; do
    case "$link_target" in
      http://*|https://*|mailto:*|'#'*|"") continue ;;
    esac
    local_target=${link_target%%#*}
    local_target=${local_target%%\?*}
    if [[ ! -e "$(dirname "$markdown_file")/$local_target" ]]; then
      printf '文档本地链接失效：%s -> %s\n' "$markdown_file" "$link_target" >&2
      link_failed=true
    fi
  done < <(grep -oE '\]\([^)]+\)' "$markdown_file" | sed -E 's/^\]\(([^)]+)\)$/\1/')
done < <(git ls-files --cached --others --exclude-standard '*.md' | sort -u)
[[ $link_failed == false ]] || exit 1

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
