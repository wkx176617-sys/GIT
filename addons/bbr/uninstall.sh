#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${1:-} != --help && ${1:-} != -h ]] || {
  printf '用法：sudo bash uninstall.sh\n恢复原设置并卸载 BBR 插件。\n'
  exit 0
}
[[ $# -eq 0 ]] || { printf '错误：未知参数\n' >&2; exit 1; }
[[ $(id -u) -eq 0 ]] || { printf '错误：请使用 root 或 sudo 运行\n' >&2; exit 1; }

if [[ -x /usr/local/sbin/bbrctl && -f /var/lib/gost-socks-bbr/original.conf ]]; then
  /usr/local/sbin/bbrctl restore
elif [[ -f /etc/sysctl.d/99-gost-socks-bbr.conf ]]; then
  printf '错误：发现插件配置但没有恢复记录，请勿直接删除；需要人工确认当前网络设置。\n' >&2
  exit 1
fi

rm -f -- /usr/local/sbin/bbrctl
rm -rf -- /usr/local/share/gost-socks-bbr /var/lib/gost-socks-bbr
printf 'BBR 插件已卸载，SOCKS5 主程序未被修改。\n'
