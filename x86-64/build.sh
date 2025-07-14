#!/bin/bash
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "编译固件大小为: $PROFILE MB"
echo "Include Docker: $INCLUDE_DOCKER"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

# ============= 同步第三方插件库==============
# 下载 run 文件仓库
echo "🔄 Cloning run file repo..."
git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo

# 拷贝 run/x86 下所有 run 文件和ipk文件 到 extra-packages 目录
mkdir -p /home/build/immortalwrt/extra-packages
cp -r /tmp/store-run-repo/run/x86/* /home/build/immortalwrt/extra-packages/

echo "✅ Run files copied to extra-packages:"
ls -lh /home/build/immortalwrt/extra-packages/*.run
# 解压并拷贝ipk到packages目录
sh prepare-packages.sh
ls -lah /home/build/immortalwrt/packages/

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建..."

# 增强：支持USB/手机共享/有线/无线驱动
# ==============================================================

# 创建临时日志文件
LOG_FILE="/tmp/autobuild_drivers.log"
echo "===== 驱动集成日志 [$(date)] =====" > $LOG_FILE

# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-filebrowser-zh-cn"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-opkg-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"

# ===== 驱动增强区域开始 =====
echo "=== 检测和添加系统驱动支持 ===" >> $LOG_FILE

# 检查并添加USB基础支持 (如未包含)
if ! grep -q "kmod-usb-core" <<< "$PACKAGES"; then
    echo "[+] 添加USB核心驱动" >> $LOG_FILE
    PACKAGES="$PACKAGES kmod-usb-core kmod-usb2 kmod-usb3"
fi

# 添加USB存储支持
PACKAGES="$PACKAGES kmod-usb-storage kmod-usb-storage-extras kmod-usb-storage-uas"
echo "[+] 添加USB存储支持" >> $LOG_FILE

# 添加USB网络共享支持 (手机热点)
USB_NET_DRIVERS="kmod-usb-net kmod-usb-net-cdc-ether kmod-usb-net-rndis kmod-usb-net-ipheth"
for driver in $USB_NET_DRIVERS; do
    if ! grep -q "$driver" <<< "$PACKAGES"; then
        PACKAGES="$PACKAGES $driver"
        echo "[+] 添加USB网络驱动: $driver" >> $LOG_FILE
    fi
done

# 添加手机MTP支持
MTP_DRIVERS="kmod-fs-f2fs kmod-nls-cp437 kmod-nls-iso8859-1"
for driver in $MTP_DRIVERS; do
    if ! grep -q "$driver" <<< "$PACKAGES"; then
        PACKAGES="$PACKAGES $driver"
        echo "[+] 添加MTP驱动: $driver" >> $LOG_FILE
    fi
done

# 添加有线网卡驱动支持 (主流芯片组)
WIRED_DRIVERS="
    kmod-e1000e        # Intel千兆网卡
    kmod-igb           # Intel万兆网卡
    kmod-ixgbe         # Intel 10GbE网卡
    kmod-tg3           # Broadcom网卡
    kmod-r8169         # Realtek RTL8169
    kmod-r8125         # Realtek RTL8125 2.5G
    kmod-forcedeth     # NVIDIA网卡
    kmod-atl1          # Atheros千兆
    kmod-atl2          # Atheros千兆
    kmod-atl1e         # Atheros千兆
    kmod-alx           # Qualcomm/Atheros网卡
"
for driver in $WIRED_DRIVERS; do
    if ! grep -q "$driver" <<< "$PACKAGES"; then
        PACKAGES="$PACKAGES $driver"
        echo "[+] 添加有线网卡驱动: $driver" >> $LOG_FILE
    fi
done

# 添加Intel无线驱动
INTEL_WIRELESS="
    kmod-iwlwifi       # Intel无线核心驱动
    kmod-iwl3945       # 3945ABG
    kmod-iwl4965       # 4965AGN
    kmod-iwl1000       # 1000系列
    kmod-iwl2000       # 2000系列
    kmod-iwl3160       # 3160AC
    kmod-iwl7260       # 7260AC
    kmod-iwl7265       # 7265AC
    kmod-iwl7265d      # 7265DAC
    iwlwifi-firmware-7260 # 固件
"
for driver in $INTEL_WIRELESS; do
    if ! grep -q "$driver" <<< "$PACKAGES"; then
        PACKAGES="$PACKAGES $driver"
        echo "[+] 添加Intel无线驱动: $driver" >> $LOG_FILE
    fi
done

# 添加其他常见无线驱动
OTHER_WIRELESS="
    kmod-rtl818x       # Realtek RTL818x通用
    kmod-rtl8192ce     # RTL8192CE
    kmod-rtl8192cu     # RTL8192CU
    kmod-rtl8192de     # RTL8192DE
    kmod-rtl8192se     # RTL8192SE
    kmod-rtl8192ee     # RTL8192EE
    kmod-rtl8723ae     # RTL8723AE
    kmod-rtl8723be     # RTL8723BE
    kmod-rtl8812au-ct  # RTL8812AU/8821AU
    kmod-rtl88x2bu     # RTL88x2BU
    wpad-openssl       # WPA2/WPA3企业加密
"
for driver in $OTHER_WIRELESS; do
    if ! grep -q "$driver" <<< "$PACKAGES"; then
        PACKAGES="$PACKAGES $driver"
        echo "[+] 添加通用无线驱动: $driver" >> $LOG_FILE
    fi
done

# 添加无线管理应用
PACKAGES="$PACKAGES luci-app-wifischedule"
echo "[+] 添加无线管理应用: luci-app-wifischedule" >> $LOG_FILE

# ===== 驱动增强区域结束 =====

# ====自添加====
#PACKAGES="$PACKAGES "
#格式如上
PACKAGES="$PACKAGES luci-app-autoreboot"
PACKAGES="$PACKAGES luci-i18n-ddns-go-zh-cn"
PACKAGES="$PACKAGES luci-i18n-eqos-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ipsec-vpnd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-mwan3-zh-cn"
PACKAGES="$PACKAGES luci-i18n-openlist-zh-cn"
PACKAGES="$PACKAGES luci-i18n-openvpn-server-zh-cn"
PACKAGES="$PACKAGES luci-i18n-qos-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ramfree-zh-cn"
PACKAGES="$PACKAGES luci-i18n-softethervpn-zh-cn"
PACKAGES="$PACKAGES luci-i18n-upnp-zh-cn"
PACKAGES="$PACKAGES luci-i18n-usb-printer-zh-cn"
PACKAGES="$PACKAGES luci-i18n-zerotier-zh-cn"



# ====结束自添加====
# 显示最终包列表
echo -e "\n===== 最终包列表 ====="
echo $PACKAGES | tr ' ' '\n' | sort

# 显示日志文件位置
echo -e "\n驱动集成日志已保存至: $LOG_FILE"
echo "请检查驱动添加情况后再执行构建"



# 静态文件服务器dufs(推荐)
PACKAGES="$PACKAGES luci-i18n-dufs-zh-cn"

# ============= imm仓库外的第三方插件==============
# ============= 若启用 则打开注释 ================
# istore商店
#PACKAGES="$PACKAGES luci-app-store"
# 首页和网络向导
#PACKAGES="$PACKAGES luci-i18n-quickstart-zh-cn"
# 去广告adghome
#PACKAGES="$PACKAGES luci-app-adguardhome"
# 代理相关
PACKAGES="$PACKAGES luci-app-ssr-plus"
#PACKAGES="$PACKAGES luci-app-passwall2"
#PACKAGES="$PACKAGES luci-i18n-nikki-zh-cn"
# VPN
#PACKAGES="$PACKAGES luci-app-tailscale"
#PACKAGES="$PACKAGES luci-i18n-tailscale-zh-cn"
# 分区扩容 by sirpdboy 
#PACKAGES="$PACKAGES luci-app-partexp"
#PACKAGES="$PACKAGES luci-i18n-partexp-zh-cn"
# 酷猫主题 by sirpdboy 
#PACKAGES="$PACKAGES luci-theme-kucat"
# 网络测速 by sirpdboy 
#PACKAGES="$PACKAGES luci-app-netspeedtest"
#PACKAGES="$PACKAGES luci-i18n-netspeedtest-zh-cn"

# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PROFILE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
