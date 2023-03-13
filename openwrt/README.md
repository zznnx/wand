openwrt version = 22.03.0

opkg update && opkg remove dnsmasq && rm -rf /etc/config/dhcp
opkg install wget tar dnsmasq-full iptables ip-full kmod-tun iptables-mod-extra iptables-mod-tproxy ip6tables-mod-nat luci-compat && reboot

##### ~Use curl:<br>

```Shell
sh -c "$(curl -kfsSl https://ghproxy.com/https://raw.githubusercontent.com/zznnx/wand/openwrt/install.sh)"
```

##### ~Use wget：<br>

```Shell
wget --no-check-certificate -O /tmp/install.sh https://ghproxy.com/https://raw.githubusercontent.com/zznnx/wand/openwrt/install.sh && sh /tmp/install.sh
```
