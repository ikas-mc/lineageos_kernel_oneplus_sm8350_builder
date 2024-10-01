#!/bin/sh

BASE_PATH=$(pwd)
export KBUILD_BUILD_HOST=github
export KBUILD_BUILD_USER=github
export ARCH=arm64
echo ">${BASE_PATH}"

# system
echo ">install tools"
sudo apt update -y 
sudo apt install -y elfutils libarchive-tools

#libufdt
echo ">clone libufdt"
git clone --branch android14-qpr2-release --depth 1 "https://android.googlesource.com/platform/system/libufdt.git" libufdt 

#AnyKernel3
echo ">clone AnyKernel3"
git clone --depth 1 https://github.com/osm0sis/AnyKernel3  AnyKernel3

# toolchain
echo ">download toolchain"
mkdir toolchain
cd toolchain
curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
chmod +x ./antman
./antman -S
./antman --patch=glibc
cd $BASE_PATH

#kernel
echo ">clone kernel source"
git clone --branch lineage-21 --depth 1 https://github.com/LineageOS/android_kernel_oneplus_sm8350 kernel

#KernelSU ( <=v0.9.5 only)
echo ">clone KernelSU and patch the kernel"
cd kernel
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
cd $BASE_PATH

#build
echo ">build kernel"
cd kernel
# 20241001 remove WERROR
sed -i 's/CONFIG_CC_WERROR=y/# CONFIG_CC_WERROR=y/g' arch/arm64/configs/vendor/lahaina-qgki_defconfig
export PATH="$BASE_PATH/toolchain/bin:${PATH}"
MAKE_ARGS="CC=clang O=out ARCH=arm64 LLVM=1 LLVM_IAS=1"
make $MAKE_ARGS "vendor/lahaina-qgki_defconfig"
make $MAKE_ARGS -j"$(nproc --all)"
cd $BASE_PATH
cp kernel/out/arch/arm64/boot/Image AnyKernel3/

#create dtb
echo ">create dtb and dtbo.img"
cat $(find kernel/out/arch/arm64/boot/dts/vendor/oplus/lemonadev/ -type f -name "*.dtb" | sort) > AnyKernel3/dtb
python libufdt/utils/src/mkdtboimg.py create AnyKernel3/dtbo.img --page_size=4096 $(find kernel/out/arch/arm64/boot/dts/vendor/oplus/lemonadev/ -type f -name "*.dtbo" | sort)

#create AnyKernel3 zip
echo ">clean AnyKernel3"
rm -rf AnyKernel3/.git* AnyKernel3/README.md
echo "lineageOS-21 oneplus-sm8350 kernel with KernelSU" > AnyKernel3/README.md
sed -i 's/do.devicecheck=1/do.devicecheck=0/g' AnyKernel3/anykernel.sh
sed -i 's!BLOCK=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot;!BLOCK=auto;!g' AnyKernel3/anykernel.sh
sed -i 's/IS_SLOT_DEVICE=0;/IS_SLOT_DEVICE=auto;/g' AnyKernel3/anykernel.sh
