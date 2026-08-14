#!/usr/bin/env bash
set -Eeuo pipefail

readonly GOST_VERSION="3.2.6"
readonly TOOL_VERSION_CURRENT="1.12.2"
readonly CONFIG_DIR="/etc/gost-socks"
readonly CONFIG_FILE="$CONFIG_DIR/gost.yaml"
readonly ENV_FILE="$CONFIG_DIR/node.env"
readonly SERVICE_FILE="/etc/systemd/system/gost-socks.service"
readonly BINARY_DIR="/usr/local/lib/gost-socks"
readonly BINARY_PATH="$BINARY_DIR/gost"
readonly CONTROL_PATH="/usr/local/sbin/socksctl"
readonly UNINSTALL_PATH="/usr/local/sbin/socks-uninstall"
readonly DOCTOR_PATH="/usr/local/sbin/socks-doctor"
readonly SAFETY_PATH="/usr/local/sbin/socks-safety"
readonly REFRESH_IP_PATH="/usr/local/sbin/socks-refresh-ip"
readonly UPGRADE_PATH="/usr/local/sbin/socks-upgrade"
readonly BBR_PATH="/usr/local/sbin/bbrctl"
readonly LOCK_FILE="/run/lock/gost-socks-main.lock"

usage() {
  cat <<'EOF'
用法：
  sudo bash install.sh [--port 31080] [--no-bbr] [--allow-downgrade]

节点名称默认使用 VPS 公网 IP。用户名和密码会在首次安装时自动生成。
重复安装会保留已有名称和凭据；特殊情况下可以使用 --name 自定义。
首次安装和旧版升级默认开启 BBR + FQ；--no-bbr 明确关闭，--enable-bbr 可重新开启。
--allow-downgrade 是高级人工回退的一次性明确授权，不再追加第二次口令确认。
EOF
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

install_ubuntu_dependencies() {
  command -v apt-get >/dev/null 2>&1 || die "系统缺少运行依赖，且无法使用 apt-get 补齐"
  export DEBIAN_FRONTEND=noninteractive
  printf '正在补齐 Ubuntu 运行依赖（仅缺失时执行一次 apt 更新）...\n'
  apt-get update
  apt-get install -y ca-certificates coreutils curl findutils iproute2 kmod passwd procps qrencode tar util-linux
}

[[ ${1:-} != "--help" && ${1:-} != "-h" ]] || { usage; exit 0; }
[[ ${1:-} != "--version" ]] || { printf '%s\n' "$TOOL_VERSION_CURRENT"; exit 0; }

node_name=""
port=""
username=${MIGRATE_SOCKS_USERNAME:-}
password=${MIGRATE_SOCKS_PASSWORD:-}
existing_node_name=""
existing_port=""
existing_username=""
existing_password=""
existing_public_ip=""
allow_downgrade=false
preserve_node=false
bbr_option=default
existing_bbr_policy=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) [[ $# -ge 2 ]] || die "--name 缺少值"; node_name=$2; shift 2 ;;
    --port) [[ $# -ge 2 ]] || die "--port 缺少值"; port=$2; shift 2 ;;
    --allow-downgrade) allow_downgrade=true; shift ;;
    --preserve-node) preserve_node=true; shift ;;
    --no-bbr) [[ $bbr_option == default ]] || die "BBR 开关参数不能重复"; bbr_option=disabled; shift ;;
    --enable-bbr) [[ $bbr_option == default ]] || die "BBR 开关参数不能重复"; bbr_option=enabled; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

[[ $(id -u) -eq 0 ]] || die "请使用 root 或 sudo 运行"
[[ -d /run/systemd/system ]] || die "此系统未使用 systemd"
[[ -r /etc/os-release ]] || die "无法读取 /etc/os-release"
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == ubuntu ]] || die "v1.12.2 当前只支持 Ubuntu 镜像"
case "${VERSION_ID:-}" in
  20.04|22.04|24.04) ;;
  *) die "当前只支持 Ubuntu 20.04、22.04、24.04" ;;
esac

dependencies_bootstrapped=false
if ! command -v flock >/dev/null 2>&1; then
  install_ubuntu_dependencies
  dependencies_bootstrapped=true
fi
if [[ ${SOCKS_LOCK_HELD:-0} != 1 ]]; then
  exec 8>"$LOCK_FILE"
  flock -n 8 || die "另一个安装、覆写或维修任务正在运行，请等待完成后重试"
fi

missing_dependency=false
for dependency_command in base64 curl find modinfo qrencode sha256sum ss sysctl tar useradd; do
  command -v "$dependency_command" >/dev/null 2>&1 || missing_dependency=true
done
if [[ $missing_dependency == true && $dependencies_bootstrapped != true ]]; then
  install_ubuntu_dependencies
fi

read_env_value() {
  local key=$1
  awk -F= -v wanted="$key" '$1 == wanted {sub(/^[^=]*=/, ""); print; exit}' "$ENV_FILE" 2>/dev/null || true
}

if [[ -f $ENV_FILE ]]; then
  NODE_NAME=$(read_env_value NODE_NAME)
  PUBLIC_IP=$(read_env_value PUBLIC_IP)
  SOCKS_PORT=$(read_env_value SOCKS_PORT)
  SOCKS_USERNAME=$(read_env_value SOCKS_USERNAME)
  SOCKS_PASSWORD=$(read_env_value SOCKS_PASSWORD)
  TOOL_VERSION=$(read_env_value TOOL_VERSION)
  existing_bbr_policy=$(read_env_value BBR_POLICY)
  existing_node_name=$NODE_NAME
  existing_port=$SOCKS_PORT
  existing_username=$SOCKS_USERNAME
  existing_password=$SOCKS_PASSWORD
  existing_public_ip=${PUBLIC_IP:-}
  node_name=${node_name:-$NODE_NAME}
  port=${port:-$SOCKS_PORT}
  username=${username:-$SOCKS_USERNAME}
  password=${password:-$SOCKS_PASSWORD}
  existing_tool_version=${TOOL_VERSION:-legacy}
fi
existing_tool_version=${existing_tool_version:-none}
if [[ $bbr_option == default ]]; then
  if [[ $existing_bbr_policy == enabled || $existing_bbr_policy == disabled ]]; then
    bbr_policy=$existing_bbr_policy
  else
    bbr_policy=enabled
  fi
else
  bbr_policy=$bbr_option
fi

if [[ $preserve_node == true ]]; then
  [[ -f $ENV_FILE ]] || die "--preserve-node 只允许用于已有本项目节点"
  [[ -z $node_name || $node_name == "$existing_node_name" ]] \
    || die "保留模式不允许改变节点名称"
  [[ -z $port || $port == "$existing_port" ]] \
    || die "保留模式不允许改变代理端口"
  [[ -z $username || $username == "$existing_username" ]] \
    || die "保留模式不允许改变代理用户名"
  [[ -z $password || $password == "$existing_password" ]] \
    || die "保留模式不允许改变代理密码"
  node_name=$existing_node_name
  port=$existing_port
  username=$existing_username
  password=$existing_password
fi

version_is_newer() {
  local left=$1 right=$2 left_major left_minor left_patch right_major right_minor right_patch
  [[ $left =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $right =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  IFS=. read -r left_major left_minor left_patch <<<"$left"
  IFS=. read -r right_major right_minor right_patch <<<"$right"
  (( left_major > right_major \
    || (left_major == right_major && left_minor > right_minor) \
    || (left_major == right_major && left_minor == right_minor && left_patch > right_patch) ))
}

if version_is_newer "$existing_tool_version" "$TOOL_VERSION_CURRENT"; then
  [[ $allow_downgrade == true ]] \
    || die "检测到已安装 v${existing_tool_version}，高于当前 v${TOOL_VERSION_CURRENT}。为防止误降级已停止；确认需要时添加 --allow-downgrade"
  printf '已通过 --allow-downgrade 明确授权切换到较旧版本。\n'
fi

available_kb=$(df -Pk / | awk 'NR == 2 {print $4}')
[[ $available_kb =~ ^[0-9]+$ && $available_kb -ge 204800 ]] \
  || die "系统盘可用空间不足 200MB，未开始修改"

port=${port:-31080}

generate_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

username=${username:-"node_$(generate_token | cut -c1-10)"}
password=${password:-"$(generate_token)"}

[[ $port =~ ^[0-9]+$ ]] || die "端口必须是数字"
(( port >= 1024 && port <= 65535 )) || die "端口范围必须为 1024-65535"
[[ $username =~ ^[A-Za-z0-9._-]{4,32}$ ]] || die "用户名必须为 4-32 位安全字符"
[[ $password =~ ^[A-Za-z0-9._-]{16,64}$ ]] || die "密码必须为 16-64 位安全字符"

case "$(uname -m)" in
  x86_64|amd64)
    asset_arch="amd64"
    expected_sha="b39037b0380ea001fb3c0c28441c2e10bfc694f90682739a65b53e55dce5238b"
    ;;
  aarch64|arm64)
    asset_arch="arm64"
    expected_sha="f674c8f4a033dc1dfd4f0d5e9602fbe5b0d0f81307bf3794f44b5b5d6d622eae"
    ;;
  *) die "不支持的 CPU 架构：$(uname -m)" ;;
esac

for required_command in base64 curl find install modinfo qrencode sha256sum ss sysctl systemctl tar useradd; do
  command -v "$required_command" >/dev/null 2>&1 || die "缺少系统命令：$required_command"
done

if [[ $preserve_node == true ]]; then
  public_ip=$existing_public_ip
else
  public_ip=$(curl -4 --fail --silent --show-error --max-time 10 https://api.ipify.org 2>/dev/null || true)
  public_ip=${public_ip:-$existing_public_ip}
fi
if [[ -z $node_name ]]; then
  [[ $public_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] \
    || die "无法自动获取 VPS 公网 IPv4，请检查网络后重试，或使用 --name 手动指定"
  node_name=$public_ip
fi
[[ $node_name =~ ^[A-Za-z0-9._-]{2,32}$ ]] || die "节点名称格式错误"

port_listener=$(ss -H -lntp | awk -v port=":$port" '$4 ~ port "$" {print}')
if [[ -n $port_listener && $port_listener != *'"gost"'* ]]; then
  die "TCP 端口 $port 已被其他程序占用，请先运行 ss -lntp | grep :$port 确认旧服务"
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
version_file="$script_dir/VERSION"
[[ -f $version_file ]] || die "安装包缺少 VERSION；请重新下载完整稳定版，不要使用散落的旧脚本"
package_version=$(tr -d '[:space:]' <"$version_file")
[[ $package_version == "$TOOL_VERSION_CURRENT" ]] \
  || die "安装包发生混版：VERSION=v${package_version}，install.sh=v${TOOL_VERSION_CURRENT}。请重新下载完整稳定版"
control_source="$script_dir/scripts/socksctl"
[[ -f $control_source ]] || die "安装包缺少 scripts/socksctl；请重新下载完整稳定版"
doctor_source="$script_dir/scripts/socks-doctor"
[[ -f $doctor_source ]] || die "安装包缺少 scripts/socks-doctor；请重新下载完整稳定版"
safety_source="$script_dir/scripts/socks-safety"
[[ -f $safety_source ]] || die "安装包缺少 scripts/socks-safety；请重新下载完整稳定版"
refresh_ip_source="$script_dir/scripts/socks-refresh-ip"
[[ -f $refresh_ip_source ]] || die "安装包缺少 scripts/socks-refresh-ip；请重新下载完整稳定版"
upgrade_source="$script_dir/scripts/socks-upgrade"
[[ -f $upgrade_source ]] || die "安装包缺少 scripts/socks-upgrade；请重新下载完整稳定版"
bbr_source="$script_dir/scripts/bbrctl"
[[ -f $bbr_source ]] || die "安装包缺少 scripts/bbrctl；请重新下载完整稳定版"
uninstall_source="$script_dir/uninstall.sh"
[[ -f $uninstall_source ]] || die "安装包缺少 uninstall.sh"

if [[ $bbr_policy == enabled ]]; then
  bash "$bbr_source" preflight >/dev/null
fi
bbr_managed_before=false
[[ -f /etc/sysctl.d/99-gost-socks-bbr.conf ]] && bbr_managed_before=true

if [[ -d /var/lib/gost-socks-safety/snapshots/last-good ]]; then
  bash "$safety_source" verify /var/lib/gost-socks-safety/snapshots/last-good >/dev/null \
    || die "最后可用快照校验失败，已停止升级；请先运行 socksctl report 并人工检查"
fi

if [[ $existing_tool_version == "$TOOL_VERSION_CURRENT" \
   && $node_name == "$existing_node_name" \
   && $port == "$existing_port" \
   && $username == "$existing_username" \
   && $password == "$existing_password" \
   && -x $DOCTOR_PATH \
   && -x $REFRESH_IP_PATH \
   && -x $UPGRADE_PATH \
   && -x $BBR_PATH \
   && -d /var/lib/gost-socks-safety/snapshots/last-good \
   && $(systemctl is-active gost-socks.service 2>/dev/null || true) == active ]]; then
  installed_bbr_policy=$(read_env_value BBR_POLICY)
  bbr_state_ok=false
  if [[ $installed_bbr_policy == "$bbr_policy" && $installed_bbr_policy == disabled ]]; then
    bbr_state_ok=true
  elif [[ $installed_bbr_policy == "$bbr_policy" && $installed_bbr_policy == enabled \
       && $(sysctl -n net.core.default_qdisc 2>/dev/null || true) == fq \
       && $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true) == bbr ]]; then
    bbr_state_ok=true
  fi
  if [[ $bbr_state_ok == true ]] && "$DOCTOR_PATH" --local >/dev/null 2>&1; then
    printf '当前已是 v%s，配置与服务均正常；重复安装已安全跳过。\n' "$TOOL_VERSION_CURRENT"
    exit 0
  fi
fi

tmp_dir=$(mktemp -d)
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

archive="gost_${GOST_VERSION}_linux_${asset_arch}.tar.gz"
download_url="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/${archive}"
downloaded_binary=""

if [[ $preserve_node == true && -x $BINARY_PATH ]]; then
  existing_gost_identity=$("$BINARY_PATH" -V 2>&1 | awk 'NR == 1 {print $1 " " $2}' || true)
  if [[ $existing_gost_identity == "gost v$GOST_VERSION" ]]; then
    downloaded_binary=$BINARY_PATH
    printf '现有 GOST %s 版本验收通过；本次工具升级复用现有核心，不重复下载。\n' \
      "$GOST_VERSION"
  fi
fi

if [[ -z $downloaded_binary ]]; then
  printf '下载 GOST %s (%s)...\n' "$GOST_VERSION" "$asset_arch"
  curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
    --connect-timeout 10 --max-time 300 \
    "$download_url" --output "$tmp_dir/$archive"

  actual_sha=$(sha256sum "$tmp_dir/$archive" | awk '{print $1}')
  [[ $actual_sha == "$expected_sha" ]] || die "GOST 下载文件 SHA-256 校验失败"

  mkdir -p "$tmp_dir/extracted"
  tar -xzf "$tmp_dir/$archive" -C "$tmp_dir/extracted"
  downloaded_binary=$(find "$tmp_dir/extracted" -type f -name gost -print -quit)
  [[ -n $downloaded_binary ]] || die "归档内未找到 gost 可执行文件"
fi

transaction_snapshot=$(bash "$safety_source" snapshot 2>/dev/null || true)
if [[ $preserve_node == true && -z $transaction_snapshot ]]; then
  die "无法创建升级前事务快照；没有修改节点，请运行 socksctl report"
fi
install_rollback() {
  local line=$1 status=$2 code=${3:-INSTALL_UNKNOWN}
  local detail=${4:-unexpected-install-failure-line-$line-status-$status}
  trap - ERR
  set +e
  if [[ $bbr_managed_before == false && -f /etc/sysctl.d/99-gost-socks-bbr.conf \
     && -f /var/lib/gost-socks-bbr/original.conf ]]; then
    bash "$bbr_source" restore --yes >/dev/null 2>&1 || true
  elif [[ $bbr_managed_before == true && ! -f /etc/sysctl.d/99-gost-socks-bbr.conf ]]; then
    bash "$bbr_source" enable >/dev/null 2>&1 || true
  fi
  incident_id=$(bash "$safety_source" incident "$code" rollback pending "$detail")
  if [[ -n $transaction_snapshot ]]; then
    bash "$safety_source" restore "$transaction_snapshot" >/dev/null 2>&1
    rollback_result=$?
    if [[ $rollback_result -eq 0 ]]; then
      bash "$safety_source" incident INSTALL_ROLLBACK rollback success "parent-$incident_id" >/dev/null
      printf '安装遇到未记录问题，事件 %s 已保存，并已恢复修改前状态。\n' "$incident_id" >&2
    else
      bash "$safety_source" incident INSTALL_ROLLBACK rollback failed "parent-$incident_id" >/dev/null
      printf '安装遇到未记录问题，事件 %s 已保存，但自动恢复失败。\n' "$incident_id" >&2
    fi
  else
    printf '首次安装遇到问题，事件 %s 已保存；没有上一状态可以恢复。\n' "$incident_id" >&2
  fi
  exit "$status"
}
trap 'install_rollback $LINENO $?' ERR

if ! id gost-socks >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin gost-socks
fi

install -d -m 0755 "$BINARY_DIR"
install -m 0755 "$downloaded_binary" "$BINARY_PATH.new"
mv -f "$BINARY_PATH.new" "$BINARY_PATH"
install -d -m 0750 -o root -g gost-socks "$CONFIG_DIR"

env_temp=$(mktemp "$CONFIG_DIR/.node.env.XXXXXX")
cat >"$env_temp" <<EOF
NODE_NAME=$node_name
PUBLIC_IP=$public_ip
SOCKS_PORT=$port
SOCKS_USERNAME=$username
SOCKS_PASSWORD=$password
TOOL_VERSION=$TOOL_VERSION_CURRENT
BBR_POLICY=$bbr_policy
EOF
chmod 0600 "$env_temp"
mv -f "$env_temp" "$ENV_FILE"

config_temp=$(mktemp "$CONFIG_DIR/.gost.yaml.XXXXXX")
cat >"$config_temp" <<EOF
services:
  - name: "$node_name"
    addr: ":$port"
    handler:
      type: socks5
      auth:
        username: "$username"
        password: "$password"
      metadata:
        notls: true
    listener:
      type: tcp
EOF
chown root:gost-socks "$config_temp"
chmod 0640 "$config_temp"
mv -f "$config_temp" "$CONFIG_FILE"

install -m 0755 "$control_source" "$CONTROL_PATH"
install -m 0755 "$uninstall_source" "$UNINSTALL_PATH"
install -m 0755 "$doctor_source" "$DOCTOR_PATH"
install -m 0755 "$safety_source" "$SAFETY_PATH"
install -m 0755 "$refresh_ip_source" "$REFRESH_IP_PATH"
install -m 0755 "$upgrade_source" "$UPGRADE_PATH"
install -m 0755 "$bbr_source" "$BBR_PATH"

service_temp=$(mktemp /etc/systemd/system/.gost-socks.service.XXXXXX)
cat >"$service_temp" <<EOF
[Unit]
Description=GOST SOCKS5 Proxy ($node_name)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=gost-socks
Group=gost-socks
ExecStart=$BINARY_PATH -C $CONFIG_FILE
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "$service_temp"
mv -f "$service_temp" "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable gost-socks.service
if ! systemctl restart gost-socks.service; then
  install_rollback "$LINENO" 1 INSTALL_SERVICE_FAILED systemd-restart-failed
fi
service_ready=false
for ((startup_attempt=1; startup_attempt<=15; startup_attempt++)); do
  if systemctl is-active --quiet gost-socks.service \
     && ss -H -lnt | awk -v port=":$port" '$4 ~ port "$" {found=1} END {exit !found}'; then
    service_ready=true
    break
  fi
  (( startup_attempt == 15 )) || sleep 1
done
if [[ $service_ready != true ]]; then
  systemctl --no-pager --full status gost-socks.service || true
  install_rollback "$LINENO" 1 INSTALL_SERVICE_NOT_READY "port-$port-not-ready-after-15-attempts"
fi

if [[ $bbr_policy == enabled ]]; then
  printf '正在启用核心 BBR + FQ 网络加速...\n'
  "$BBR_PATH" enable
elif [[ -f /var/lib/gost-socks-bbr/original.conf ]]; then
  printf '已选择关闭核心 BBR，正在恢复首次启用前的网络设置...\n'
  "$BBR_PATH" restore --yes
else
  printf '核心 BBR 开关：已关闭；系统网络设置保持不变。\n'
fi

doctor_status=0
"$DOCTOR_PATH" || doctor_status=$?
if [[ $doctor_status -ne 0 ]]; then
  install_rollback "$LINENO" "$doctor_status" INSTALL_VERIFICATION_FAILED "doctor-exit-$doctor_status"
fi
if [[ $preserve_node == true ]]; then
  installed_node_name=$(read_env_value NODE_NAME)
  installed_public_ip=$(read_env_value PUBLIC_IP)
  installed_port=$(read_env_value SOCKS_PORT)
  installed_username=$(read_env_value SOCKS_USERNAME)
  installed_password=$(read_env_value SOCKS_PASSWORD)
  if [[ $installed_node_name != "$existing_node_name" \
     || $installed_public_ip != "$existing_public_ip" \
     || $installed_port != "$existing_port" \
     || $installed_username != "$existing_username" \
     || $installed_password != "$existing_password" ]]; then
    install_rollback "$LINENO" 1 INSTALL_PRESERVATION_FAILED node-identity-changed
  fi
fi
"$SAFETY_PATH" promote "$transaction_snapshot" >/dev/null
trap - ERR

public_ip=${public_ip:-<VPS公网IP>}

cat <<EOF

============================================================
GOST SOCKS5 节点安装成功
============================================================
工具版本：v$TOOL_VERSION_CURRENT
节点名称：$node_name
服务器：  $public_ip
端口：    $port
类型：    SOCKS5
用户名：  $username
密码：    $password
服务：    gost-socks.service
BBR：     $([[ $bbr_policy == enabled ]] && printf '已开启（BBR + FQ）' || printf '已关闭')
============================================================

下一步：
1. 在萤光云安全组放行 TCP $port，并限制为固定工作出口 IP/32。
2. 在比特浏览器中填写 VPS 公网 IP、端口、用户名和密码。
3. 运行 sudo socksctl check 进行基础连通性测试。
4. 以后在任意 Mac/Windows 上登录本服务器，运行 sudo socksctl info 查询节点。
5. 运行 sudo socksctl export 导出 v2rayN 和 Shadowrocket 连接信息。
EOF
