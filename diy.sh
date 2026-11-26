#!/bin/bash
step(){ echo; echo ">>> \$1"; }
die(){ echo "!! 失败：\$1"; exit 1; }

step "1. 512MB 分区补丁"
DTS=$(grep -rl "cudy,tr3000-v1" target/linux/ | grep -E "\.dtsi?$")
echo "DTS: $DTS"
[ -z "$DTS" ] && die "找不到 TR3000 DTS"
for f in $DTS; do
  sed -i -E 's/reg = <0x5c0000 0x[0-9a-fA-F]+>/reg = <0x5c0000 0x1f240000>/' "$f"
done
grep -n "0x5c0000" $DTS || die "ubi@0x5c0000 不存在"

step "2. IMAGE_SIZE"
MK=target/linux/mediatek/image/filogic.mk
perl -0pi -e 's/(define Device\/cudy_tr3000-v1\n(?:(?!endef).)*?IMAGE_SIZE := )\S+/${1}480m/s' $MK
awk '/define Device\/cudy_tr3000-v1$/,/endef/' $MK

step "3. 添加 feeds"
cat >> feeds.conf.default <<'EOF'
src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git
src-git passwall https://github.com/xiaorouji/openwrt-passwall.git
src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main
src-git istore https://github.com/linkease/istore.git;main
src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master
EOF
cat feeds.conf.default

step "4. feeds update"
./scripts/feeds update -a; echo "feeds update 返回码: $?"
for f in packages luci; do
  [ -d feeds/$f ] || { echo "!! 核心 feed $f 失败"; exit 1; }
done
for f in passwall_packages passwall nikki istore kenzo; do
  if [ -d feeds/$f ]; then echo "OK   feed $f"
  else echo "!! feed $f 失败，重试单独拉取"; ./scripts/feeds update $f || echo "!! feed $f 仍失败，跳过该插件"
  fi
done
./scripts/feeds update -i

step "5. golang"
rm -rf feeds/packages/lang/golang
git clone --depth 1 -b 25.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang \
 || git clone --depth 1 -b 24.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang \
 || die "golang 拉取失败"

step "6. 额外包"
rm -rf feeds/packages/net/mosdns feeds/packages/net/v2ray-geodata
git clone --depth 1 -b v5 https://github.com/sbwml/luci-app-mosdns package/mosdns || echo "!! mosdns 失败"
git clone --depth 1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata || echo "!! geodata 失败"
git clone --depth 1 https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale || echo "!! tailscale luci 失败"
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon || echo "!! argon 失败"
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config || echo "!! argon-config 失败"

step "7. turboacc"
curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh \
  && bash add_turboacc.sh --no-sfe || echo "!! turboacc 跳过"

step "8. feeds install"
for p in packages luci routing telephony nikki istore; do ./scripts/feeds install -a -p $p; done
./scripts/feeds install -a -f -p passwall_packages
./scripts/feeds install -a -f -p passwall
./scripts/feeds install -p kenzo luci-app-adguardhome adguardhome luci-app-vlmcsd vlmcsd luci-app-zerotier

step "diy.sh 完成"
exit 0
