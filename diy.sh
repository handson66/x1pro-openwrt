#!/bin/bash
set -e

# ---------- 1. 512MB 分区：ubi 从 0x5c0000 扩到闪存可用末尾 ----------
DTS=$(grep -rl "cudy,tr3000-v1" target/linux/ | grep -E "\.dtsi?$" || true)
echo "TR3000 DTS 文件: $DTS"
[ -z "$DTS" ] && { echo "!! 找不到 TR3000 DTS"; exit 1; }
for f in $DTS; do
  sed -i -E 's/reg = <0x5c0000 0x[0-9a-fA-F]+>/reg = <0x5c0000 0x1f240000>/' "$f"
done
grep -n "0x5c0000" $DTS || { echo "!! 没有 ubi@0x5c0000，分区布局与预期不符"; exit 1; }

# 放宽固件体积上限
MK=target/linux/mediatek/image/filogic.mk
perl -0pi -e 's/(define Device\/cudy_tr3000-v1\n(?:(?!endef).)*?IMAGE_SIZE := )\S+/${1}480m/s' $MK
echo "===== TR3000 设备定义 ====="
awk '/define Device\/cudy_tr3000-v1$/,/endef/' $MK
awk '/define Device\/cudy_tr3000-v1$/,/endef/' $MK | grep -q "IMAGE_SIZE := 480m" \
  || echo "!! IMAGE_SIZE 未修改，若编译报 image too big 请贴日志"

# ---------- 2. 第三方 feeds ----------
cat >> feeds.conf.default <<'EOF'
src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main
src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main
src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main
src-git istore https://github.com/linkease/istore.git;main
src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master
EOF

./scripts/feeds update -a

# 新版 golang
rm -rf feeds/packages/lang/golang
git clone --depth 1 -b 25.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang \
 || git clone --depth 1 -b 24.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

# MosDNS
rm -rf feeds/packages/net/mosdns feeds/packages/net/v2ray-geodata
git clone --depth 1 -b v5 https://github.com/sbwml/luci-app-mosdns package/mosdns
git clone --depth 1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# daed（Honk 备用）
git clone --depth 1 https://github.com/QiuSimons/luci-app-daed package/dae

# Tailscale LuCI
git clone --depth 1 https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# argon 主题
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# turboacc（失败则跳过）
curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh \
  && bash add_turboacc.sh --no-sfe || echo "!! turboacc 添加失败，已跳过"

# 安装 feeds
./scripts/feeds install -a -p packages
./scripts/feeds install -a -p luci
./scripts/feeds install -a -p routing
./scripts/feeds install -a -p telephony
./scripts/feeds install -a -f -p passwall_packages
./scripts/feeds install -a -f -p passwall
./scripts/feeds install -a -p nikki
./scripts/feeds install -a -p istore
./scripts/feeds install -p kenzo luci-app-adguardhome adguardhome luci-app-vlmcsd vlmcsd luci-app-zerotier || true
