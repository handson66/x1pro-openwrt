#!/bin/bash
step(){ echo; echo ">>> \$1"; }
die(){ echo "!! 失败：$*"; exit 1; }

step "1. 512MB 分区补丁（ubi 用满闪存）"
DTS=$(grep -rl "cudy,tr3000-v1" target/linux/ | grep -E "\.dtsi?$")
[ -z "$DTS" ] && die "找不到 TR3000 DTS"
for f in $DTS; do
  sed -i -E 's/reg = <0x5c0000 0x[0-9a-fA-F]+>/reg = <0x5c0000 0x1f240000>/' "$f"
done
grep -n "0x5c0000 0x1f240000" $DTS || die "分区补丁没打上"

step "2. 放宽固件体积上限"
MK=target/linux/mediatek/image/filogic.mk
perl -0pi -e 's/(define Device\/cudy_tr3000-v1\n(?:(?!endef).)*?IMAGE_SIZE := )\S+/${1}480m/s' $MK
awk '/define Device\/cudy_tr3000-v1$/,/endef/' $MK | grep "IMAGE_SIZE" || echo "设备定义无 IMAGE_SIZE，不受限"

step "3. feeds"
./scripts/feeds update -a
[ -d feeds/packages ] && [ -d feeds/luci ] || die "官方 feeds 拉取失败"

step "4. argon 主题"
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon || die "argon"
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config || die "argon-config"

step "5. feeds install"
./scripts/feeds install -a
step "完成"; exit 0
