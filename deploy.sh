#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
用法：
  ./deploy.sh <SSH目标> [--port <端口>]

示例：
  ./deploy.sh root@203.0.113.10
  ./deploy.sh ubuntu@203.0.113.10 --port 31080

节点名称默认自动使用 VPS 公网 IP。特殊情况下仍可通过 --name 自定义。
EOF
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

[[ $# -gt 0 ]] || { usage; exit 1; }
[[ ${1:-} != "--help" && ${1:-} != "-h" ]] || { usage; exit 0; }

target=$1
shift
node_name=""
port=31080

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -ge 2 ]] || die "--name 缺少值"
      node_name=$2
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || die "--port 缺少值"
      port=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "未知参数：$1"
      ;;
  esac
done

[[ $target =~ ^[A-Za-z0-9._@:-]+$ ]] || die "SSH 目标格式不安全"
[[ -z $node_name || $node_name =~ ^[A-Za-z0-9._-]{2,32}$ ]] \
  || die "节点名称只能包含字母、数字、点、下划线和连字符（2-32 位）"
[[ $port =~ ^[0-9]+$ ]] || die "端口必须是数字"
(( port >= 1024 && port <= 65535 )) || die "端口范围必须为 1024-65535"

for command_name in ssh scp; do
  command -v "$command_name" >/dev/null 2>&1 || die "缺少命令：$command_name"
done

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for required_file in install.sh uninstall.sh scripts/socksctl; do
  [[ -f "$project_dir/$required_file" ]] || die "缺少项目文件：$required_file"
done

remote_dir="/tmp/gost-socks-deploy-$$"

cleanup() {
  ssh "$target" "rm -rf '$remote_dir'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '正在连接 %s...\n' "$target"
ssh "$target" "mkdir -p '$remote_dir'"
scp "$project_dir/install.sh" "$project_dir/uninstall.sh" "$project_dir/scripts/socksctl" "$target:$remote_dir/"

install_args="--port '$port'"
if [[ -n $node_name ]]; then
  install_args+=" --name '$node_name'"
fi
printf '正在安装节点（名称自动使用公网 IP，端口 %s）...\n' "$port"
remote_command="if [ \"\$(id -u)\" -eq 0 ]; then bash '$remote_dir/install.sh' $install_args; else sudo bash '$remote_dir/install.sh' $install_args; fi"
ssh -t "$target" "$remote_command"

printf '\n部署完成。请立即把终端输出的节点凭据保存到密码管理器。\n'
