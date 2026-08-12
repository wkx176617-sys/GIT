#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：sudo bash install.sh [--enable]

默认只安装 bbrctl 管理命令，不改变网络；--enable 会在质检通过后启用 BBR + FQ。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
[[ ${1:-} != --help && ${1:-} != -h ]] || { usage; exit 0; }
[[ $(id -u) -eq 0 ]] || die "请使用 root 或 sudo 运行"

enable=false
case "${1:-}" in
  "") ;;
  --enable) enable=true ;;
  *) die "未知参数：$1" ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f $script_dir/bbrctl ]] || die "插件目录缺少 bbrctl"
[[ -f $script_dir/plugin.conf ]] || die "插件目录缺少 plugin.conf"

if ! command -v sysctl >/dev/null 2>&1 || ! command -v modprobe >/dev/null 2>&1; then
  command -v apt-get >/dev/null 2>&1 || die "缺少基础命令且无法使用 apt-get"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y kmod procps
fi

install -m 0755 "$script_dir/bbrctl" /usr/local/sbin/bbrctl
install -d -m 0755 /usr/local/share/gost-socks-bbr
install -m 0644 "$script_dir/plugin.conf" /usr/local/share/gost-socks-bbr/plugin.conf

printf 'BBR 插件已安装，但尚未改变网络。\n'
if [[ $enable == true ]]; then
  /usr/local/sbin/bbrctl check
  /usr/local/sbin/bbrctl enable
else
  printf '下一步：运行 sudo bbrctl check；确认后运行 sudo bbrctl enable。\n'
fi
