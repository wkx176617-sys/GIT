#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：sudo socks-uninstall [--yes]

卸载会停止 GOST SOCKS5 服务，并删除 /etc/gost-socks 中的配置和凭据。
EOF
}

[[ ${1:-} != "--help" && ${1:-} != "-h" ]] || { usage; exit 0; }
[[ $(id -u) -eq 0 ]] || { printf '错误：请使用 sudo 运行\n' >&2; exit 1; }

confirmed=false
if [[ ${1:-} == "--yes" ]]; then
  confirmed=true
elif [[ $# -gt 0 ]]; then
  printf '错误：未知参数 %s\n' "$1" >&2
  exit 1
fi

if [[ $confirmed != true ]]; then
  printf '这会永久删除 SOCKS5 配置和凭据。输入 DELETE 确认：'
  read -r answer
  [[ $answer == "DELETE" ]] || { printf '已取消。\n'; exit 0; }
fi

systemctl disable --now gost-socks.service >/dev/null 2>&1 || true
rm -f -- /etc/systemd/system/gost-socks.service
systemctl daemon-reload
systemctl reset-failed >/dev/null 2>&1 || true

rm -rf -- /etc/gost-socks /usr/local/lib/gost-socks
rm -f -- /usr/local/sbin/socksctl /usr/local/sbin/socks-uninstall

if id gost-socks >/dev/null 2>&1; then
  userdel gost-socks >/dev/null 2>&1 || true
fi

printf 'GOST SOCKS5 服务、配置和凭据已删除。云安全组规则需要你在萤光云控制台手动删除。\n'
