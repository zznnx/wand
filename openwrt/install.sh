#!/bin/bash

#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

#url
Wrturl="https://ghproxy.com/https://raw.githubusercontent.com/zznnx/wand/openwrt/clash"

echo='echo -e' && [ -n "$(echo -e|grep e)" ] && echo=echo

source "/etc/openwrt_release"
case "${DISTRIB_ARCH}" in
	aarch64_*)
		CORE_ARCH="linux-armv8"
		;;
	arm_*_neon-vfp*)
		CORE_ARCH="linux-armv7"
		;;
	arm_*_neon|arm_*_vfp*)
		CORE_ARCH="linux-armv6"
		;;
	arm*)
		CORE_ARCH="linux-armv5"
		;;
	i386_*)
		CORE_ARCH="linux-386"
		;;
	mips64_*)
		CORE_ARCH="linux-mips64"
		;;
	mips_*)
		CORE_ARCH="linux-mips-softfloat"
		;;
	mipsel_*)
		CORE_ARCH="linux-mipsle-softfloat"
		;;
	x86_64)
		CORE_ARCH="linux-amd64"
		;;
	*)
		$echo "${Error} ${RedBG} 当前系统为 ${DISTRIB_ARCH} 不在支持的系统列表内，安装中断 ${Font}"
		exit 1
		;;
esac

if [ "$USER" != "root" ]; then
	$echo "${Error} ${RedBG} 当前用户不是root用户，请切换到root用户后重新执行脚本 ${Font}"
	exit 1
else
	$echo "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
fi

if [ -f "/etc/init.d/wand" ]; then
	/etc/init.d/wand stop
	rm -rf /etc/wand
	rm -rf /etc/init.d/wand
	rm -rf /etc/config/wand
	rm -rf /usr/lib/lua/luci/controller/wand.lua
	rm -rf /usr/lib/lua/luci/model/cbi/wand
	rm -rf /usr/lib/lua/luci/view/wand
	$echo "${OK} ${RedBG} 已删除安装版本，请从新开始安装 ${Font}"
fi
echo -----------------------------------------------
$echo "请选择想要安装的版本："	
$echo "${GreenBG}  1、Clash版 ${Font}"
$echo "${RedBG}  2、ClashPremium版 ${Font}"
echo -----------------------------------------------
read -p "请输入相应数字 > " num
Clashurl=""
if [ "$num" = "1" ];then
	Clashurl="${Wrturl}/clash-${CORE_ARCH}"
	$echo "${OK} ${GreenBG} 开始下载Clash ${Font}"
elif [ "$num" = "2" ];then
	Clashurl="${Wrturl}/clash-premium-${CORE_ARCH}"
	$echo "${OK} ${GreenBG} 开始下载ClashPremium ${Font}"
else
	$echo "${Error} ${RedBG} 安装已取消 ${Font}"
	exit 1
fi
mkdir -p /etc/wand
wget --no-check-certificate -O /etc/wand/clash "${Clashurl}"
chmod +x /etc/wand/clash

$echo "${OK} ${GreenBG} 开始下载Country.mmdb ${Font}"
wget --no-check-certificate -P /etc/wand/ "${Wrturl}/Country.mmdb"

$echo "${OK} ${GreenBG} 开始下载Clash UI ${Font}"
wget --no-check-certificate -P /etc/wand/ "${Wrturl}/ui.tar.gz"
cd /etc/wand/ || exit
tar -zxvf ./ui.tar.gz
rm -rf ./ui.tar.gz

$echo "${OK} ${GreenBG} 开始下载Luci UI ${Font}"
wget --no-check-certificate -P /etc/wand/ "${Wrturl}/luci-wand.tar.gz"
cd /etc/wand/ || exit
tar -zxvf ./luci-wand.tar.gz
rm -rf ./luci-wand.tar.gz
cp /etc/wand/luci-wand/wand.lua /usr/lib/lua/luci/controller/wand.lua
mkdir -p /usr/lib/lua/luci/model/cbi/wand
cp /etc/wand/luci-wand/client.lua /usr/lib/lua/luci/model/cbi/wand/client.lua
mkdir -p /usr/lib/lua/luci/view/wand
cp /etc/wand/luci-wand/login.htm /usr/lib/lua/luci/view/wand/login.htm
cp /etc/wand/luci-wand/dashboard.htm /usr/lib/lua/luci/view/wand/dashboard.htm
rm -rf ./luci-wand

cat >> "/etc/config/wand" << EOF
config wand 'config'
	option port '9091'
	option socks_port '9092'
	option redir_port '9093'
	option tproxy_port '9094'
	option mixed_port '9095'
	option dns_listen '9053'
	option external_controller '9080'
	option external_ui 'ui'
	option secret '123456'
	option enable '1'
	option clash_url "${Clashurl}"
	option custom_url "${Wrturl}/Country.mmdb"
EOF

cat >> "/etc/init.d/wand" << \EOF
#!/bin/sh /etc/rc.common
# Copyright (C) 2006-2011 OpenWrt.org

START=99
STOP=15

PROXY_FWMARK="0x162"
PROXY_ROUTE_TABLE="0x162"
TPROXY_PORT=$(uci -q get wand.config.tproxy_port)

start() {
	uci -q del dhcp.@dnsmasq[-1].server
	uci -q del dhcp.@dnsmasq[-1].noresolv
	uci -q commit dhcp
	uci -q set wand.config.enable=0
	uci -q commit wand
	/etc/init.d/wand enable >/dev/null 2>&1
	if pidof clash >/dev/null; then
		echo "已在运行"
	else
		core_clash
		echo "启动成功"
	fi
}

stop() {
	kill_clash
	echo "停止成功"
}

restart() {
	kill_clash
	core_clash
	echo "重启成功"
}

kill_clash() {
	iptables -t mangle -D PREROUTING -j wand >/dev/null 2>&1
	iptables -t mangle -F wand >/dev/null 2>&1
	uci -q del dhcp.@dnsmasq[-1].server
	uci -q del dhcp.@dnsmasq[-1].noresolv
	uci -q commit dhcp
	/etc/init.d/dnsmasq restart >/dev/null 2>&1
	clash_pids=$(pidof clash |sed 's/$//g')
	for clash_pid in $clash_pids; do
		kill -9 "$clash_pid" 2>/dev/null
		done >/dev/null 2>&1
	sleep 1
}

core_clash() {
	if [ "$(uci -q get wand.config.enable)" != "1" ]; then
		/etc/wand/clash -d /etc/wand >/dev/null 2>&1 &
		ip rule add fwmark "$PROXY_FWMARK" table "$PROXY_ROUTE_TABLE" >/dev/null 2>&1
		ip route add local 0.0.0.0/0 dev lo table "$PROXY_ROUTE_TABLE" >/dev/null 2>&1
		iptables -t mangle -N wand >/dev/null 2>&1
		iptables -t mangle -A wand -d 0.0.0.0/8 -j RETURN
		iptables -t mangle -A wand -d 10.0.0.0/8 -j RETURN
		iptables -t mangle -A wand -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A wand -d 169.254.0.0/16 -j RETURN
		iptables -t mangle -A wand -d 172.16.0.0/12 -j RETURN
		iptables -t mangle -A wand -d 192.168.50.0/16 -j RETURN
		iptables -t mangle -A wand -d 192.168.9.0/16 -j RETURN
		iptables -t mangle -A wand -d 224.0.0.0/4 -j RETURN
		iptables -t mangle -A wand -d 240.0.0.0/4 -j RETURN
		iptables -t mangle -A wand -p udp -j TPROXY --on-port $TPROXY_PORT --tproxy-mark "$PROXY_FWMARK" >/dev/null 2>&1
		iptables -t mangle -A wand -p tcp -j TPROXY --on-port $TPROXY_PORT --tproxy-mark "$PROXY_FWMARK" >/dev/null 2>&1
		iptables -t mangle -A PREROUTING -j wand
		uci -q del dhcp.@dnsmasq[-1].server
		uci -q add_list dhcp.@dnsmasq[0].noresolv=1
		uci -q add_list dhcp.@dnsmasq[0].server=127.0.0.1#"$(uci -q get wand.config.dns_listen)"
		uci -q commit dhcp
		/etc/init.d/dnsmasq restart >/dev/null 2>&1
	fi
}
EOF
chmod +x /etc/init.d/wand
rm -rf /tmp/luci-*

$echo "${OK} ${GreenBG} 安装完成 ${Font}"