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
[[ -f $script_dir/VERSION ]] || die "当前是散落的旧安装脚本。请按教程重新下载完整稳定版"
[[ -f $script_dir/install.sh ]] || die "同目录中缺少 install.sh，请完整下载或上传本项目"
[[ -f $script_dir/preflight.sh ]] || die "同目录中缺少 preflight.sh，请完整下载或上传本项目"
[[ -f $script_dir/overwrite.sh ]] || die "同目录中缺少 overwrite.sh，请完整下载或上传本项目"
[[ -f $script_dir/scripts/socks-refresh-ip ]] \
  || die "项目缺少 scripts/socks-refresh-ip，请完整下载或上传本项目"
[[ -f $script_dir/scripts/socks-upgrade ]] \
  || die "项目缺少 scripts/socks-upgrade，请完整下载或上传本项目"
package_version=$(tr -d '[:space:]' <"$script_dir/VERSION")
installer_version=$(bash "$script_dir/install.sh" --version)
[[ $package_version == "$installer_version" ]] \
  || die "安装包发生混版：VERSION=v$package_version，install.sh=v$installer_version。请重新下载完整稳定版"
printf '已验明完整安装包：v%s（目录：%s）\n' "$package_version" "$script_dir"

overwrite=false
install_args=()
port=31080
while [[ $# -gt 0 ]]; do
  case "$1" in
    --overwrite) overwrite=true; shift ;;
    --port)
      [[ $# -ge 2 && $2 =~ ^[0-9]+$ ]] \
        || die "--port 后面必须是端口数字，例如 --port 31080"
      port=$2
      install_args+=(--port "$2")
      shift 2
      ;;
    *)
      die "发现多余内容：$1。请只复制命令本身，不要复制 root@...#、说明文字或网页提示符"
      ;;
  esac
done

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  printf '正在检查 Ubuntu 基础依赖...\n'
  apt-get update
  apt-get install -y ca-certificates coreutils curl findutils iproute2 jq passwd qrencode tar util-linux
else
  die "当前只支持使用 apt-get 的 Ubuntu 服务器"
fi

if [[ $overwrite == true ]]; then
  exec bash "$script_dir/overwrite.sh" "${install_args[@]}"
fi

if ! bash "$script_dir/preflight.sh" --port "$port"; then
  printf '\n质检未通过。若报告明确显示“可迁移：旧 sing-box”，请确认备份说明后运行：\n'
  printf 'bash xshell-install.sh --port %s --overwrite\n' "$port"
  exit 2
fi
exec bash "$script_dir/install.sh" "${install_args[@]}"
