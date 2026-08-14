#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：sudo bash overwrite.sh [--port 31080] [--yes] [--no-bbr]

仅在确认目标端口属于可识别的旧 sing-box SOCKS5 时，备份并停用旧协议，再用新账号密码安装 GOST。
本工具不会自动覆写 x-ui、Xray、v2ray 或未知进程。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }

port=31080
node_name=""
confirmed=false
install_options=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) [[ $# -ge 2 ]] || die "--port 缺少值"; port=$2; shift 2 ;;
    --name) [[ $# -ge 2 ]] || die "--name 缺少值"; node_name=$2; shift 2 ;;
    --yes) confirmed=true; shift ;;
    --no-bbr) install_options+=(--no-bbr); shift ;;
    --enable-bbr) install_options+=(--enable-bbr); shift ;;
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

preflight_status=0
bash "$script_dir/preflight.sh" --port "$port" || preflight_status=$?
if [[ $preflight_status == 0 ]]; then
  printf '未发现需要覆写的旧服务，转为安全的标准安装/升级。\n'
  exec env SOCKS_LOCK_HELD=1 bash "$script_dir/install.sh" --port "$port" "${name_args[@]}" "${install_options[@]}"
fi
[[ $preflight_status == 10 ]] \
  || die "当前服务器不是可安全自动迁移的单一 sing-box 状态，已停止操作"

listener=$(ss -H -lntp 2>/dev/null | awk -v port=":$port" '$4 ~ port "$" {print}')
[[ $listener == *'"sing-box"'* ]] \
  || die "端口 $port 不属于可自动迁移的 sing-box；为防止误伤，已停止操作"
[[ -f /etc/sing-box/config.json ]] || die "未找到 /etc/sing-box/config.json，无法安全迁移"
[[ ! -f /etc/gost-socks/node.env ]] || die "同时发现本项目节点记录，属于混合状态，不能自动覆写"

match_count=$(jq --argjson port "$port" '[.inbounds[]? | select(.type == "socks" and .listen_port == $port)] | length' /etc/sing-box/config.json) \
  || die "sing-box 配置不是有效 JSON"
[[ $match_count == 1 ]] || die "必须恰好找到一个使用端口 $port 的 SOCKS 入站，实际找到 $match_count 个"

username=$(jq -r --argjson port "$port" '.inbounds[]? | select(.type == "socks" and .listen_port == $port) | .users[0].username // empty' /etc/sing-box/config.json)
password=$(jq -r --argjson port "$port" '.inbounds[]? | select(.type == "socks" and .listen_port == $port) | .users[0].password // empty' /etc/sing-box/config.json)
[[ $username =~ ^[A-Za-z0-9._-]{4,32}$ ]] || die "旧 SOCKS5 用户名不存在或格式不兼容，不能自动迁移"
[[ $password =~ ^[A-Za-z0-9._-]{16,64}$ ]] || die "旧 SOCKS5 密码不存在或格式不兼容，不能自动迁移"

if [[ $confirmed != true ]]; then
  printf '将备份并停用 sing-box，用同一端口安装 GOST，并生成新的代理账号和密码。输入 OVERWRITE 确认：' "$port"
  read -r answer
  [[ $answer == OVERWRITE ]] || { printf '已取消，服务器没有变化。\n'; exit 0; }
fi

backup_root=/root/gost-socks-backups
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
backup_dir="$backup_root/$timestamp"
install -d -m 0700 "$backup_dir"
[[ -f /etc/systemd/system/sing-box.service ]] && cp -a /etc/systemd/system/sing-box.service "$backup_dir/"
systemctl cat sing-box >"$backup_dir/sing-box.service.effective.txt" 2>/dev/null || true
was_enabled=$(systemctl is-enabled sing-box 2>/dev/null || true)
was_active=$(systemctl is-active sing-box 2>/dev/null || true)
printf '%s\n' "$was_enabled" >"$backup_dir/sing-box.enabled-state.txt"
printf '%s\n' "$was_active" >"$backup_dir/sing-box.active-state.txt"
config_moved=false

rollback() {
  trap - ERR
  set +e
  printf '\n安装失败，正在恢复旧 sing-box 服务...\n' >&2
  systemctl disable --now gost-socks >/dev/null 2>&1 || true
  if [[ $config_moved == true && ! -e /etc/sing-box && -d $backup_dir/sing-box ]]; then
    mv "$backup_dir/sing-box" /etc/sing-box || true
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  [[ $was_enabled == enabled ]] && systemctl enable sing-box >/dev/null 2>&1 || true
  [[ $was_active == active ]] && systemctl restart sing-box >/dev/null 2>&1 || true
  rollback_ok=true
  [[ -d /etc/sing-box ]] || rollback_ok=false
  if [[ $was_enabled == enabled && $(systemctl is-enabled sing-box 2>/dev/null || true) != enabled ]]; then
    rollback_ok=false
  fi
  if [[ $was_active == active && $(systemctl is-active sing-box 2>/dev/null || true) != active ]]; then
    rollback_ok=false
  fi
  if [[ $rollback_ok == true ]]; then
    printf '旧 sing-box 配置和迁移前服务状态已恢复。\n' >&2
  else
    printf '自动回退未完全通过，请保持现场并人工检查下方备份。\n' >&2
  fi
  printf '旧配置备份：%s\n' "$backup_dir" >&2
}
trap rollback ERR

systemctl disable --now sing-box
mv /etc/sing-box "$backup_dir/sing-box"
config_moved=true
SOCKS_LOCK_HELD=1 bash "$script_dir/install.sh" --port "$port" "${name_args[@]}" "${install_options[@]}"
/usr/local/sbin/socksctl check

read_new_value() {
  local key=$1
  awk -F= -v wanted="$key" '$1 == wanted {sub(/^[^=]*=/, ""); print; exit}' /etc/gost-socks/node.env 2>/dev/null || true
}
new_username=$(read_new_value SOCKS_USERNAME)
new_password=$(read_new_value SOCKS_PASSWORD)

verify_migration() {
  [[ $new_username =~ ^[A-Za-z0-9._-]{4,32}$ && $new_password =~ ^[A-Za-z0-9._-]{16,64}$ ]] \
    || { printf '迁移验收失败：新代理凭据格式无效。\n' >&2; return 1; }
  [[ $new_username != "$username" && $new_password != "$password" ]] \
    || { printf '迁移验收失败：新旧代理凭据没有同时完成轮换。\n' >&2; return 1; }
  ! systemctl is-active --quiet sing-box \
    || { printf '迁移验收失败：旧 sing-box 仍在运行。\n' >&2; return 1; }
  ! systemctl is-enabled --quiet sing-box \
    || { printf '迁移验收失败：旧 sing-box 仍会开机启动。\n' >&2; return 1; }
  [[ $(systemctl is-active gost-socks 2>/dev/null || true) == active ]] \
    || { printf '迁移验收失败：GOST 服务没有正常运行。\n' >&2; return 1; }
  new_listener=$(ss -H -lntp 2>/dev/null | awk -v port=":$port" '$4 ~ port "$" {print}')
  [[ -n $new_listener && $new_listener == *'"gost"'* && $new_listener != *'"sing-box"'* ]] \
    || { printf '迁移验收失败：目标端口没有由 GOST 独占。\n' >&2; return 1; }
  [[ ! -e /etc/sing-box ]] \
    || { printf '迁移验收失败：旧 sing-box 标准配置路径仍然存在。\n' >&2; return 1; }
}
verify_migration
trap - ERR

printf '\n迁移完成：旧 sing-box 已停用且配置已移入备份，目标端口仅由 GOST 监听。\n'
printf '旧代理账号密码已作废；请使用上方新凭据更新所有客户端。\n'
printf '旧配置备份：%s\n' "$backup_dir"
printf '验证命令：socksctl check && socksctl export\n'
