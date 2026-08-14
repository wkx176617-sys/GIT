#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：
  sudo bash xshell-install.sh [--port 31080] [--no-bbr]

此入口适用于 Windows Xshell 登录后的 Ubuntu 服务器。
默认先质检并智能分流；仅识别到单一旧 sing-box 时自动进入一次确认的安全迁移。
BBR + FQ 默认开启；只有明确不需要时才添加 --no-bbr。
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
[[ -f $script_dir/scripts/bbrctl ]] \
  || die "项目缺少 scripts/bbrctl，请完整下载或上传本项目"
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
    --name)
      [[ $# -ge 2 && $2 =~ ^[A-Za-z0-9._-]{2,32}$ ]] \
        || die "--name 后面必须是 2-32 位安全节点名称"
      install_args+=(--name "$2")
      shift 2
      ;;
    --no-bbr) install_args+=(--no-bbr); shift ;;
    --enable-bbr) install_args+=(--enable-bbr); shift ;;
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

if [[ $overwrite == true ]]; then
  exec bash "$script_dir/overwrite.sh" "${install_args[@]}"
fi

preflight_status=0
bash "$script_dir/preflight.sh" --port "$port" || preflight_status=$?
case "$preflight_status" in
  0)
    exec bash "$script_dir/install.sh" "${install_args[@]}"
    ;;
  10)
    printf '\n智能分流：已确认可迁移的单一旧 sing-box，继续后会生成新的代理账号和密码。\n'
    exec bash "$script_dir/overwrite.sh" "${install_args[@]}"
    ;;
  *)
    printf '\n智能安装已停止：当前状态不在安全自动处理白名单内，请按上方中文结论人工检查。\n' >&2
    exit "$preflight_status"
    ;;
esac
