#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：
  sudo bash xshell-install.sh [--port 31080]

此入口适用于 Windows Xshell 登录后的 Ubuntu/Debian 服务器。
它会补齐基础依赖，再调用同目录的 install.sh。节点名称自动使用 VPS 公网 IP。
EOF
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

[[ ${1:-} != "--help" && ${1:-} != "-h" ]] || { usage; exit 0; }
[[ $(id -u) -eq 0 ]] || die "请使用 root 登录，或在命令前添加 sudo"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f $script_dir/install.sh ]] || die "同目录中缺少 install.sh，请完整下载或上传本项目"

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  printf '正在检查 Ubuntu/Debian 基础依赖...\n'
  apt-get update
  apt-get install -y ca-certificates coreutils curl findutils iproute2 passwd qrencode tar
else
  die "当前只支持使用 apt-get 的 Ubuntu/Debian 服务器"
fi

exec bash "$script_dir/install.sh" "$@"
