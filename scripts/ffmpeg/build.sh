#!/usr/bin/env bash

set -euo pipefail

case "$ANDROID_ABI" in
  x86)
    # x86 assembler optimizations can create text relocations.
    EXTRA_BUILD_CONFIGURATION_FLAGS="${EXTRA_BUILD_CONFIGURATION_FLAGS:-} --disable-asm"
    ;;

  x86_64)
    EXTRA_BUILD_CONFIGURATION_FLAGS="${EXTRA_BUILD_CONFIGURATION_FLAGS:-} --x86asmexe=${NASM_EXECUTABLE}"
    ;;
esac

if [[ "${FFMPEG_GPL_ENABLED:-false}" == "true" ]]; then
  EXTRA_BUILD_CONFIGURATION_FLAGS="${EXTRA_BUILD_CONFIGURATION_FLAGS:-} --enable-gpl"
fi

ADDITIONAL_COMPONENTS=""

for library_name in ${FFMPEG_EXTERNAL_LIBRARIES:-}; do
  ADDITIONAL_COMPONENTS="${ADDITIONAL_COMPONENTS} --enable-${library_name}"
done

DEP_CFLAGS="-I${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/include"
DEP_LD_FLAGS="-L${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/lib ${FFMPEG_EXTRA_LD_FLAGS:-}"

# Android 15 supports devices using 16 KB memory pages.
EXTRA_LDFLAGS="-Wl,-z,max-page-size=16384 ${DEP_LD_FLAGS}"

./configure \
  --prefix="${BUILD_DIR_FFMPEG}/${ANDROID_ABI}" \
  --enable-cross-compile \
  --target-os=android \
  --arch="${TARGET_TRIPLE_MACHINE_ARCH}" \
  --sysroot="${SYSROOT_PATH}" \
  --cc="${FAM_CC}" \
  --cxx="${FAM_CXX}" \
  --ld="${FAM_LD}" \
  --ar="${FAM_AR}" \
  --as="${FAM_CC}" \
  --nm="${FAM_NM}" \
  --ranlib="${FAM_RANLIB}" \
  --strip="${FAM_STRIP}" \
  --extra-cflags="-O3 -fPIC ${DEP_CFLAGS}" \
  --extra-ldflags="${EXTRA_LDFLAGS}" \
  --enable-shared \
  --disable-static \
  --enable-jni \
  --enable-mediandk \
  --enable-pthreads \
  --enable-mediacodec \
  --enable-decoder=h264_mediacodec \
  --enable-decoder=hevc_mediacodec \
  --enable-decoder=vp8_mediacodec \
  --enable-decoder=vp9_mediacodec \
  --enable-decoder=mpeg4_mediacodec \
  --disable-vulkan \
  --pkg-config="${PKG_CONFIG_EXECUTABLE}" \
  ${EXTRA_BUILD_CONFIGURATION_FLAGS:-} \
  ${ADDITIONAL_COMPONENTS}

if ! grep -Eq '^#define CONFIG_MEDIACODEC 1$' config.h; then
  echo "ERROR: CONFIG_MEDIACODEC is not enabled." >&2
  grep -E 'CONFIG_(MEDIACODEC|JNI|ANDROID|MEDIANDK|PTHREADS)' config.h || true
  exit 1
fi

if ! grep -Eq '^#define CONFIG_JNI 1$' config.h; then
  echo "ERROR: CONFIG_JNI is not enabled." >&2
  exit 1
fi

if ! grep -Eq '^#define CONFIG_H264_MEDIACODEC_DECODER 1$' config_components.h; then
  echo "ERROR: h264_mediacodec decoder is not enabled." >&2
  grep -i 'mediacodec' config_components.h || true
  exit 1
fi


"${MAKE_EXECUTABLE}" clean
"${MAKE_EXECUTABLE}" -j"${HOST_NPROC}"
"${MAKE_EXECUTABLE}" install
