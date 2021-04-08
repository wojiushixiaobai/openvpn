# openvpn

## 支持的操作系统

- [x] CentOS 7
- [ ] CentOS 8

## 安装方法

- 安装完成后, 客户端所需的文件在 /etc/openvpn/client/ 目录里面

```bash
git clone --depth=1 https://github.com/wojiushixiaobai/openvpn
cd openvpn
```

### 安装

```bash
./install.sh install
```

### 其他

```vim
# Linux 客户端使用方式
openvpn --daemon --cd /etc/openvpn --config client.ovpn
```

```vim
# Windows 客户端使用方式
client.ovpn

ca [inline]
cert [inline]
key [inline]

<ca>
...
</ca>

<cert>
 ...
</cert>

<key>
...
</key>
```

```vim
# 使用密码认证
vi /etc/openvpn/server.conf

# Password Authentication
script-security 3
auth-user-pass-verify /etc/openvpn/checkpsw.sh via-env
client-cert-not-required
username-as-common-name

```
```vim
# 密码校验脚本
 vi /etc/openvpn/checkpsw.sh

# Checkout Password
#!/bin/sh
PASSFILE="/etc/openvpn/psw-file"
LOG_FILE="/etc/openvpn/openvpn-password.log"
TIME_STAMP=`date "+%Y-%m-%d %T"`
if [ ! -r "${PASSFILE}" ]; then
  echo "${TIME_STAMP}: Could not open password file \"${PASSFILE}\" for reading." >> ${LOG_FILE}
  exit 1
fi
CORRECT_PASSWORD=`awk '!/^;/&&!/^#/&&$1=="'${username}'"{print $2;exit}' ${PASSFILE}`
if [ "${CORRECT_PASSWORD}" = "" ]; then
  echo "${TIME_STAMP}: User does not exist: username=\"${username}\", password=\"${password}\"." >> ${LOG_FILE}
  exit 1
fi
if [ "${password}" = "${CORRECT_PASSWORD}" ]; then
  echo "${TIME_STAMP}: Successful authentication: username=\"${username}\"." >> ${LOG_FILE}
  exit 0
fi
echo "${TIME_STAMP}: Incorrect password: username=\"${username}\", password=\"${password}\"." >> ${LOG_FILE}
exit 1
```

```vim
# 密码文件
vi /etc/openvpn/psw-file

# user password
test 123456
```

```vim
# 客户端使用密码认证
client.ovpn

auth-user-pass
```
