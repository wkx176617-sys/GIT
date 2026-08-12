#!/usr/bin/env bash
set -Eeuo pipefail

readonly GOST_VERSION="3.2.6"
readonly CONFIG_DIR="/etc/gost-socks"
readonly CONFIG_FILE="$CONFIG_DIR/gost.yaml"
readonly ENV_FILE="$CONFIG_DIR/node.env"
readonly SERVICE_FILE="/etc/systemd/system/gost-socks.service"
readonly BINARY_DIR="/usr/local/lib/gost-socks"
readonly BINARY_PATH="$BINARY_DIR/gost"
readonly CONTROL_PATH="/usr/local/sbin/socksctl"
readonly UNINSTALL_PATH="/usr/local/sbin/socks-uninstall"

usage() {
  cat <<'EOF'
用法：
  sudo bash install.sh [--port 31080]

节点名称默认使用 VPS 公网 IP。用户名和密码会在首次安装时自动生成。
重复安装会保留已有名称和凭据；特殊情况下可以使用 --name 自定义。
EOF
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

[[ ${1:-} != "--help" && ${1:-} != "-h" ]] || { usage; exit 0; }
[[ $(id -u) -eq 0 ]] || die "请使用 root 或 sudo 运行"
[[ -d /run/systemd/system ]] || die "此系统未使用 systemd"

node_name=""
port=""
username=""
password=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) [[ $# -ge 2 ]] || die "--name 缺少值"; node_name=$2; shift 2 ;;
    --port) [[ $# -ge 2 ]] || die "--port 缺少值"; port=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
done

if [[ -f $ENV_FILE ]]; then
  # 文件仅允许安全字符，并由本脚本以 root 权限创建。
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  node_name=${node_name:-$NODE_NAME}
  port=${port:-$SOCKS_PORT}
  username=${username:-$SOCKS_USERNAME}
  password=${password:-$SOCKS_PASSWORD}
fi

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

for required_command in curl find install sha256sum ss systemctl tar useradd; do
  command -v "$required_command" >/dev/null 2>&1 || die "缺少系统命令：$required_command"
done

public_ip=$(curl -4 --fail --silent --show-error --max-time 10 https://api.ipify.org 2>/dev/null || true)
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
control_source="$script_dir/socksctl"
[[ -f $control_source ]] || control_source="$script_dir/scripts/socksctl"
[[ -f $control_source ]] || die "安装包缺少 socksctl"
uninstall_source="$script_dir/uninstall.sh"
[[ -f $uninstall_source ]] || die "安装包缺少 uninstall.sh"

tmp_dir=$(mktemp -d)
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

archive="gost_${GOST_VERSION}_linux_${asset_arch}.tar.gz"
download_url="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/${archive}"

printf '下载 GOST %s (%s)...\n' "$GOST_VERSION" "$asset_arch"
curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  "$download_url" --output "$tmp_dir/$archive"

actual_sha=$(sha256sum "$tmp_dir/$archive" | awk '{print $1}')
[[ $actual_sha == "$expected_sha" ]] || die "GOST 下载文件 SHA-256 校验失败"

mkdir -p "$tmp_dir/extracted"
tar -xzf "$tmp_dir/$archive" -C "$tmp_dir/extracted"
downloaded_binary=$(find "$tmp_dir/extracted" -type f -name gost -print -quit)
[[ -n $downloaded_binary ]] || die "归档内未找到 gost 可执行文件"

if ! id gost-socks >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin gost-socks
fi

install -d -m 0755 "$BINARY_DIR"
install -m 0755 "$downloaded_binary" "$BINARY_PATH"
install -d -m 0750 -o root -g gost-socks "$CONFIG_DIR"

cat >"$ENV_FILE" <<EOF
NODE_NAME=$node_name
PUBLIC_IP=$public_ip
SOCKS_PORT=$port
SOCKS_USERNAME=$username
SOCKS_PASSWORD=$password
EOF
chmod 0600 "$ENV_FILE"

cat >"$CONFIG_FILE" <<EOF
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
chown root:gost-socks "$CONFIG_FILE"
chmod 0640 "$CONFIG_FILE"

install -m 0755 "$control_source" "$CONTROL_PATH"
install -m 0755 "$uninstall_source" "$UNINSTALL_PATH"

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=GOST SOCKS5 Proxy ($node_name)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=gost-socks
Group=gost-socks
ExecStart=$BINARY_PATH -C $CONFIG_FILE
Restart=on-failure
RestartSec=3s
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

systemctl daemon-reload
systemctl enable gost-socks.service
systemctl restart gost-socks.service
sleep 1
systemctl is-active --quiet gost-socks.service || {
  systemctl --no-pager --full status gost-socks.service || true
  die "服务启动失败"
}

public_ip=${public_ip:-<VPS公网IP>}

cat <<EOF

============================================================
GOST SOCKS5 节点安装成功
============================================================
节点名称：$node_name
服务器：  $public_ip
端口：    $port
类型：    SOCKS5
用户名：  $username
密码：    $password
服务：    gost-socks.service
============================================================

下一步：
1. 在萤光云安全组放行 TCP $port，并限制为固定工作出口 IP/32。
2. 在比特浏览器中填写 VPS 公网 IP、端口、用户名和密码。
3. 运行 sudo socksctl check 进行基础连通性测试。
4. 以后在任意 Mac/Windows 上登录本服务器，运行 sudo socksctl info 查询节点。
5. 运行 sudo socksctl export 导出 v2rayN 和 Shadowrocket 连接信息。
EOF
