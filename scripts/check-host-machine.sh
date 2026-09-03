#!/usr/bin/env bash

set -euo pipefail

checkVariablePresence() {
  local variable_name="$1"
  local message="$2"

  if [[ -z "${!variable_name:-}" ]]; then
    echo "The ${variable_name} environment variable is not defined." >&2
    echo "$message" >&2
    exit 1
  fi
}

checkCommandPresence() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 1
  fi
}

checkVariablePresence \
  "ANDROID_SDK_HOME" \
  "Set ANDROID_SDK_HOME to the absolute Android SDK path."

checkVariablePresence \
  "ANDROID_NDK_HOME" \
  "Set ANDROID_NDK_HOME to the absolute Android NDK path."

if [[ ! -d "$ANDROID_SDK_HOME" ]]; then
  echo "ANDROID_SDK_HOME does not point to a directory: $ANDROID_SDK_HOME" >&2
  exit 1
fi

if [[ ! -d "$ANDROID_NDK_HOME" ]]; then
  echo "ANDROID_NDK_HOME does not point to a directory: $ANDROID_NDK_HOME" >&2
  exit 1
fi

checkCommandPresence curl
checkCommandPresence git
checkCommandPresence make
checkCommandPresence cmake
checkCommandPresence pkg-config
checkCommandPresence nasm
checkCommandPresence ninja
checkCommandPresence meson
checkCommandPresence tar
checkCommandPresence unzip

SDKMANAGER="$ANDROID_SDK_HOME/cmdline-tools/latest/bin/sdkmanager"

if [[ ! -x "$SDKMANAGER" ]]; then
  SDKMANAGER="$ANDROID_SDK_HOME/cmdline-tools/bin/sdkmanager"
fi

if [[ ! -x "$SDKMANAGER" ]]; then
  echo "Android sdkmanager was not found under: $ANDROID_SDK_HOME/cmdline-tools" >&2
  exit 1
fi

ANDROID_NDK_LLVM="$ANDROID_NDK_HOME/toolchains/llvm"

if [[ ! -d "$ANDROID_NDK_LLVM" ]]; then
  echo "Android NDK LLVM toolchain was not found: $ANDROID_NDK_LLVM" >&2
  exit 1
fi

echo "Android SDK: $ANDROID_SDK_HOME"
echo "Android NDK: $ANDROID_NDK_HOME"
echo "Host machine checks passed."
