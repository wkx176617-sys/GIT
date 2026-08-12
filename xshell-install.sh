#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：
  sudo bash xshell-install.sh [--port 31080] [--overwrite]

此入口适用于 Windows Xshell 登录后的 Ubuntu 服务器。
默认先质检再安装；使用 --overwrite 时只覆写可安全识别的旧 sing-box SOCKS5。
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
[[ -f $script_dir/preflight.sh ]] || die "同目录中缺少 preflight.sh，请完整下载或上传本项目"
[[ -f $script_dir/overwrite.sh ]] || die "同目录中缺少 overwrite.sh，请完整下载或上传本项目"

overwrite=false
install_args=()
for arg in "$@"; do
  if [[ $arg == --overwrite ]]; then
    overwrite=true
  else
    install_args+=("$arg")
  fi
done

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  printf '正在检查 Ubuntu 基础依赖...\n'
  apt-get update
  apt-get install -y ca-certificates coreutils curl findutils iproute2 jq passwd qrencode tar
else
  die "当前只支持使用 apt-get 的 Ubuntu 服务器"
fi

port=31080
for ((index=0; index<${#install_args[@]}; index++)); do
  [[ ${install_args[index]} == --port && $((index + 1)) -lt ${#install_args[@]} ]] \
    && port=${install_args[index + 1]}
done

if [[ $overwrite == true ]]; then
  exec bash "$script_dir/overwrite.sh" "${install_args[@]}"
fi

if ! bash "$script_dir/preflight.sh" --port "$port"; then
  printf '\n质检未通过。若报告明确显示“可迁移：旧 sing-box”，请确认备份说明后运行：\n'
  printf 'bash xshell-install.sh --port %s --overwrite\n' "$port"
  exit 2
fi
exec bash "$script_dir/install.sh" "${install_args[@]}"
