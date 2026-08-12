#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：sudo bash preflight.sh [--port 31080]

只读质检 Ubuntu 服务器、旧代理服务和目标端口，不会停止或修改任何服务。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }

port=31080
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) [[ $# -ge 2 ]] || die "--port 缺少值"; port=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

[[ $(id -u) -eq 0 ]] || die "请使用 root 或 sudo 运行，以便识别端口所属进程"
[[ $port =~ ^[0-9]+$ ]] || die "端口必须是数字"
(( port >= 1024 && port <= 65535 )) || die "端口范围必须为 1024-65535"
[[ -r /etc/os-release ]] || die "无法读取 /etc/os-release"
# shellcheck disable=SC1091
source /etc/os-release

supported=false
if [[ ${ID:-} == ubuntu ]]; then
  case "${VERSION_ID:-}" in
    20.04|22.04|24.04) supported=true ;;
  esac
fi

arch=$(uname -m)
case "$arch" in
  x86_64|amd64|aarch64|arm64) arch_supported=true ;;
  *) arch_supported=false ;;
esac

printf '=== SOCKS5 安装前质检（只读）===\n'
printf '系统镜像：%s\n' "${PRETTY_NAME:-未知}"
printf 'CPU 架构：%s\n' "$arch"
printf '目标端口：%s/TCP\n' "$port"

problems=0
[[ $supported == true ]] || { printf '不兼容：当前仅支持 Ubuntu 20.04/22.04/24.04。\n'; problems=$((problems + 1)); }
[[ $arch_supported == true ]] || { printf '不兼容：当前仅支持 amd64/arm64。\n'; problems=$((problems + 1)); }
[[ -d /run/systemd/system ]] || { printf '不兼容：镜像没有运行 systemd。\n'; problems=$((problems + 1)); }

missing=()
for command_name in awk base64 curl find install sha256sum ss systemctl tar useradd; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done
if (( ${#missing[@]} > 0 )); then
  printf '缺少命令：%s\n' "${missing[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    printf '  可修复：安装程序会通过 apt-get 补齐 Ubuntu 精简镜像依赖。\n'
  else
    problems=$((problems + 1))
  fi
fi

printf '\n代理服务：\n'
found_service=false
for service_name in gost-socks sing-box x-ui xray v2ray; do
  state=$(systemctl is-active "$service_name" 2>/dev/null || true)
  if [[ $state != inactive && $state != unknown && -n $state ]]; then
    printf '  %-12s %s\n' "$service_name" "$state"
    found_service=true
  fi
done
[[ $found_service == true ]] || printf '  未发现正在运行的常见代理服务\n'

listener=""
if command -v ss >/dev/null 2>&1; then
  listener=$(ss -H -lntp 2>/dev/null | awk -v port=":$port" '$4 ~ port "$" {print}')
fi
printf '\n端口质检：\n'
if ! command -v ss >/dev/null 2>&1; then
  printf '  待安装 iproute2 后复检端口；标准安装不会覆盖已占用端口。\n'
elif [[ -z $listener ]]; then
  printf '  通过：%s/TCP 未被占用，可以全新安装。\n' "$port"
elif [[ $listener == *'"gost"'* && -f /etc/gost-socks/node.env ]]; then
  printf '  通过：端口由本工具的 GOST 占用，可以安全升级并保留凭据。\n'
elif [[ $listener == *'"sing-box"'* && -f /etc/sing-box/config.json ]]; then
  printf '  可迁移：端口由旧 sing-box 占用。请先查看备份/覆写说明，再运行 overwrite.sh。\n'
  problems=$((problems + 1))
else
  printf '  阻止安装：端口被未知或不支持自动迁移的程序占用：\n%s\n' "$listener"
  printf '  不会自动停止 x-ui、Xray、v2ray 或未知程序。\n'
  problems=$((problems + 1))
fi

printf '\n配置文件：\n'
for path in /etc/gost-socks/node.env /etc/sing-box/config.json /usr/local/x-ui /etc/x-ui /usr/local/etc/xray; do
  [[ -e $path ]] && printf '  发现 %s\n' "$path"
done

if (( problems == 0 )); then
  printf '\n质检结论：通过，可以运行标准安装。\n'
  exit 0
fi
printf '\n质检结论：发现 %s 项需要处理；质检没有修改服务器。\n' "$problems"
exit 2
