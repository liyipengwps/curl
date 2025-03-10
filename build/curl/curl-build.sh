#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS libcurl libraries with Bitcode enabled

# Credits:
#
# Felix Schwarz, IOSPIRIT GmbH, @@felix_schwarz.
#   https://gist.github.com/c61c0f7d9ab60f53ebb0.git
# Bochun Bai
#   https://github.com/sinofool/build-libcurl-ios
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL
# Preston Jennings
#   https://github.com/prestonj/Build-OpenSSL-cURL
#   curl: https://curl.se/download/

set -e

CURL_VERSION="curl-8.5.0"

DEVELOPER=$(xcode-select -print-path)
CC_BITCODE_FLAG="-fembed-bitcode"

NGHTTP2="$(pwd)/../nghttp2/build"

build() {
	ARCH="$1"
	PLATFORM="$2"
	min_version=$3

	NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/${PLATFORM}/${ARCH}"
	NGHTTP2LIB="-L${NGHTTP2}/${PLATFORM}/${ARCH}/lib"

	sdk_cfg="-isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}.sdk"
	arch_cfg="-arch ${ARCH}"

	export CFLAGS="${arch_cfg} ${sdk_cfg} ${CC_BITCODE_FLAG} ${min_version}"

	echo -e "Building ${CURL_VERSION} for ${PLATFORM} ${ARCH}"

	# 用编译出来的一直找不到error: --with-openssl was given but OpenSSL could not be detected，说明--with-openssl用法有问题，还不如用系统的签
	SSL_CFG="--with-secure-transport"

	host_cfg="--host=arm64-apple-darwin" #等号右边的双引号不能省略，要不然传值容易出现问题

	echo "准备./configure"

	common_cfg="--disable-shared --enable-static -with-random=/dev/urandom"
	prefix_cfg="-prefix=${build_dir}/${PLATFORM}/${ARCH}"
	./configure ${prefix_cfg} ${common_cfg} ${SSL_CFG} ${NGHTTP2CFG} ${host_cfg}
	if [[ $? == 0 ]]; then
		echo "./configure 完成，开始make"
	else
		echo "./configure 失败"
		exit 1
	fi

	make -j8
	if [[ $? == 0 ]]; then
		echo "make完成，开始install"
	else
		echo "make失败"
		exit 1
	fi

	make install
	if [[ $? == 0 ]]; then
		echo "install完成，开始clean"
	else
		echo "install失败"
		exit 1
	fi

	make clean
}

build_dir="$(pwd)/build"

echo -e "Cleaning up"
rm -rf ${build_dir}
mkdir -p ${build_dir}

rm -rf "${CURL_VERSION}"

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
	echo "Downloading ${CURL_VERSION}.tar.gz"
	curl -LO https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
	echo "Using ${CURL_VERSION}.tar.gz"
fi

echo "Unpacking curl"
tar xfz "${CURL_VERSION}.tar.gz"

echo -e "Building iOS libraries"

cd "${CURL_VERSION}"
build "armv7" "iPhoneOS" "-miphoneos-version-min=9.0"
build "arm64" "iPhoneOS" "-miphoneos-version-min=9.0"
build "arm64" "iPhoneSimulator" "-miphonesimulator-version-min=9.0"
build "x86_64" "iPhoneSimulator" "-miphonesimulator-version-min=9.0"
build "arm64" "MacOSX" "-mmacosx-version-min=10.13"
build "x86_64" "MacOSX" "-mmacosx-version-min=10.13"
build "arm64" "AppleTVOS" "-mappletvos-version-min=9.0"
build "arm64" "AppleTVSimulator" "-mappletvsimulator-version-min=9.0"
build "x86_64" "AppleTVSimulator" "-mappletvsimulator-version-min=9.0"
build "arm64" "WatchOS" "-mwatchos-version-min=4.0"
build "arm64_32" "WatchOS" "-mwatchos-version-min=4.0"
build "arm64" "WatchSimulator" "-mwatchsimulator-version-min=4.0"
build "x86_64" "WatchSimulator" "-mwatchsimulator-version-min=4.0"
cd ..

echo -e "Cleaning up"
rm -rf ${CURL_VERSION}
rm -rf "${CURL_VERSION}.tar.gz"

echo -e "Done"
