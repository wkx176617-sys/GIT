#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：sudo bash overwrite.sh [--port 31080] [--yes]

仅在确认目标端口属于可识别的旧 sing-box SOCKS5 时，备份旧配置、迁移账号密码并安装 GOST。
本工具不会自动覆写 x-ui、Xray、v2ray 或未知进程。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }

port=31080
node_name=""
confirmed=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) [[ $# -ge 2 ]] || die "--port 缺少值"; port=$2; shift 2 ;;
    --name) [[ $# -ge 2 ]] || die "--name 缺少值"; node_name=$2; shift 2 ;;
    --yes) confirmed=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done
[[ $(id -u) -eq 0 ]] || die "请使用 root 或 sudo 运行"
[[ $port =~ ^[0-9]+$ ]] || die "端口必须是数字"
(( port >= 1024 && port <= 65535 )) || die "端口范围必须为 1024-65535"
[[ -z $node_name || $node_name =~ ^[A-Za-z0-9._-]{2,32}$ ]] || die "节点名称格式错误"

if ! command -v flock >/dev/null 2>&1; then
  command -v apt-get >/dev/null 2>&1 || die "缺少 flock（util-linux）"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y util-linux
fi
exec 8>/run/lock/gost-socks-main.lock
flock -n 8 || die "另一个安装、覆写或维修任务正在运行，请等待完成后重试"

name_args=()
[[ -n $node_name ]] && name_args=(--name "$node_name")

[[ -r /etc/os-release ]] || die "无法读取 /etc/os-release"
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == ubuntu ]] || die "当前覆写程序只支持 Ubuntu"
case "${VERSION_ID:-}" in
  20.04|22.04|24.04) ;;
  *) die "当前只支持 Ubuntu 20.04、22.04、24.04" ;;
esac

if ! command -v ss >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  command -v apt-get >/dev/null 2>&1 || die "缺少 ss/jq，且无法使用 apt-get 安装"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2 jq
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f $script_dir/install.sh ]] || die "同目录中缺少 install.sh"
[[ -f $script_dir/preflight.sh ]] || die "同目录中缺少 preflight.sh"

listener=$(ss -H -lntp 2>/dev/null | awk -v port=":$port" '$4 ~ port "$" {print}')
if [[ -z $listener || ( $listener == *'"gost"'* && -f /etc/gost-socks/node.env ) ]]; then
  printf '未发现需要覆写的旧服务，转为安全的标准安装/升级。\n'
  exec env SOCKS_LOCK_HELD=1 bash "$script_dir/install.sh" --port "$port" "${name_args[@]}"
fi

[[ $listener == *'"sing-box"'* ]] \
  || die "端口 $port 不属于可自动迁移的 sing-box；为防止误伤，已停止操作"
[[ -f /etc/sing-box/config.json ]] || die "未找到 /etc/sing-box/config.json，无法安全迁移"

match_count=$(jq --argjson port "$port" '[.inbounds[]? | select(.type == "socks" and .listen_port == $port)] | length' /etc/sing-box/config.json) \
  || die "sing-box 配置不是有效 JSON"
[[ $match_count == 1 ]] || die "必须恰好找到一个使用端口 $port 的 SOCKS 入站，实际找到 $match_count 个"

username=$(jq -r --argjson port "$port" '.inbounds[]? | select(.type == "socks" and .listen_port == $port) | .users[0].username // empty' /etc/sing-box/config.json)
password=$(jq -r --argjson port "$port" '.inbounds[]? | select(.type == "socks" and .listen_port == $port) | .users[0].password // empty' /etc/sing-box/config.json)
[[ $username =~ ^[A-Za-z0-9._-]{4,32}$ ]] || die "旧 SOCKS5 用户名不存在或格式不兼容，不能自动迁移"
[[ $password =~ ^[A-Za-z0-9._-]{16,64}$ ]] || die "旧 SOCKS5 密码不存在或格式不兼容，不能自动迁移"

if [[ $confirmed != true ]]; then
  printf '将备份并停用 sing-box，迁移端口 %s 的 SOCKS5 账号密码。输入 OVERWRITE 确认：' "$port"
  read -r answer
  [[ $answer == OVERWRITE ]] || { printf '已取消，服务器没有变化。\n'; exit 0; }
fi

backup_root=/root/gost-socks-backups
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
backup_dir="$backup_root/$timestamp"
install -d -m 0700 "$backup_dir"
cp -a /etc/sing-box "$backup_dir/"
[[ -f /etc/systemd/system/sing-box.service ]] && cp -a /etc/systemd/system/sing-box.service "$backup_dir/"
systemctl cat sing-box >"$backup_dir/sing-box.service.effective.txt" 2>/dev/null || true
was_enabled=$(systemctl is-enabled sing-box 2>/dev/null || true)
was_active=$(systemctl is-active sing-box 2>/dev/null || true)
printf '%s\n' "$was_enabled" >"$backup_dir/sing-box.enabled-state.txt"
printf '%s\n' "$was_active" >"$backup_dir/sing-box.active-state.txt"

rollback() {
  printf '\n安装失败，正在恢复旧 sing-box 服务...\n' >&2
  systemctl disable --now gost-socks >/dev/null 2>&1 || true
  [[ $was_enabled == enabled ]] && systemctl enable sing-box >/dev/null 2>&1 || true
  [[ $was_active == active ]] && systemctl restart sing-box >/dev/null 2>&1 || true
  printf '旧配置备份：%s\n' "$backup_dir" >&2
}
trap rollback ERR

systemctl disable --now sing-box
MIGRATE_SOCKS_USERNAME=$username MIGRATE_SOCKS_PASSWORD=$password \
  SOCKS_LOCK_HELD=1 bash "$script_dir/install.sh" --port "$port" "${name_args[@]}"
/usr/local/sbin/socksctl check
trap - ERR

printf '\n覆写完成：旧 sing-box 已停用，原 SOCKS5 账号密码已迁移。\n'
printf '旧配置备份：%s\n' "$backup_dir"
printf '验证命令：socksctl check && socksctl export\n'
