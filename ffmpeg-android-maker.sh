#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

export BASE_DIR
export SOURCES_DIR="${BASE_DIR}/sources"
export STATS_DIR="${BASE_DIR}/stats"
export SCRIPTS_DIR="${BASE_DIR}/scripts"
export OUTPUT_DIR="${BASE_DIR}/output"

"${SCRIPTS_DIR}/check-host-machine.sh"

BUILD_DIR="${BASE_DIR}/build"

export BUILD_DIR
export BUILD_DIR_FFMPEG="${BUILD_DIR}/ffmpeg"
export BUILD_DIR_EXTERNAL="${BUILD_DIR}/external"

prepareOutput() {
  local abi="$1"

  local output_lib="${OUTPUT_DIR}/lib/${abi}"
  local output_headers="${OUTPUT_DIR}/include/${abi}"

  mkdir -p "$output_lib"
  mkdir -p "$output_headers"

  cp "${BUILD_DIR_FFMPEG}/${abi}/lib/"*.so "$output_lib/"
  cp -r "${BUILD_DIR_FFMPEG}/${abi}/include/"* "$output_headers/"
}

findFfmpegBinary() {
  local abi="$1"
  local prefix="${BUILD_DIR_FFMPEG}/${abi}"

  local candidates=(
    "${prefix}/bin/ffmpeg"
    "${prefix}/ffmpeg"
    "${BUILD_DIR}/${abi}/ffmpeg"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "Could not find FFmpeg executable for ${abi}." >&2
  echo "Searched:" >&2
  printf '  %s\n' "${candidates[@]}" >&2
  return 1
}

validateMediaCodec() {
  local abi="$1"
  local ffmpeg_binary="$2"

  if [[ ! -x "$ffmpeg_binary" ]]; then
    chmod +x "$ffmpeg_binary"
  fi

  local hwaccels_file="${STATS_DIR}/${abi}-hwaccels.txt"
  local decoders_file="${STATS_DIR}/${abi}-decoders.txt"

  echo "Checking FFmpeg hardware backends for ${abi}..."

  "$ffmpeg_binary" \
    -hide_banner \
    -hwaccels \
    2>&1 | tee "$hwaccels_file"

  if ! grep -Eiq '^[[:space:]]*mediacodec[[:space:]]*$' "$hwaccels_file"; then
    echo "ERROR: MediaCodec hardware acceleration is missing for ${abi}." >&2
    exit 1
  fi

  "$ffmpeg_binary" \
    -hide_banner \
    -decoders \
    2>&1 | tee "$decoders_file"

  if ! grep -Eiq 'mediacodec' "$decoders_file"; then
    echo "ERROR: MediaCodec decoders are missing for ${abi}." >&2
    exit 1
  fi

  "$ffmpeg_binary" \
    -hide_banner \
    -version \
    > "${STATS_DIR}/${abi}-version.txt" 2>&1

  echo "MediaCodec validation passed for ${abi}."
}

checkTextRelocations() {
  local abi="$1"
  local text_rel_stats_file="${STATS_DIR}/text-relocations.txt"
  local shared_library

  : > "$text_rel_stats_file"

  for shared_library in "${BUILD_DIR_FFMPEG}/${abi}/lib/"*.so; do
    "${FAM_READELF}" \
      --dynamic \
      "$shared_library" \
      | grep -E 'TEXTREL|File' \
      >> "$text_rel_stats_file" || true
  done

  if grep -q 'TEXTREL' "$text_rel_stats_file"; then
    echo "ERROR: Text relocations detected for ${abi}." >&2
    cat "$text_rel_stats_file" >&2
    exit 1
  fi
}

rm -rf "$BUILD_DIR"
rm -rf "$STATS_DIR"
rm -rf "$OUTPUT_DIR"

mkdir -p "$BUILD_DIR"
mkdir -p "$STATS_DIR"
mkdir -p "$OUTPUT_DIR"

source "${SCRIPTS_DIR}/export-host-variables.sh"
source "${SCRIPTS_DIR}/parse-arguments.sh"

COMPONENTS_TO_BUILD=("${EXTERNAL_LIBRARIES[@]}")
COMPONENTS_TO_BUILD+=("ffmpeg")

for component in "${COMPONENTS_TO_BUILD[@]}"; do
  echo "Getting source code of component: ${component}"

  source_directory="${SOURCES_DIR}/${component}"
  mkdir -p "$source_directory"

  pushd "$source_directory" >/dev/null

  source "${SCRIPTS_DIR}/${component}/download.sh"

  component_sources_variable="SOURCES_DIR_${component}"

  if [[ -z "${!component_sources_variable:-}" ]]; then
    export "${component_sources_variable}=${source_directory}"
  fi

  popd >/dev/null
done

for abi in ${FFMPEG_ABIS_TO_BUILD}; do
  echo "Building ABI: ${abi}"

  source "${SCRIPTS_DIR}/export-build-variables.sh" "$abi"

  for component in "${COMPONENTS_TO_BUILD[@]}"; do
    component_sources_variable="SOURCES_DIR_${component}"
    component_source_directory="${!component_sources_variable}"

    echo "Building component: ${component}"

    pushd "$component_source_directory" >/dev/null
    source "${SCRIPTS_DIR}/${component}/build.sh"
    popd >/dev/null
  done

  checkTextRelocations "$abi"
  prepareOutput "$abi"

  ffmpeg_binary="$(findFfmpegBinary "$abi")"
  validateMediaCodec "$abi" "$ffmpeg_binary"

  mkdir -p "${OUTPUT_DIR}/bin/${abi}"
  cp "$ffmpeg_binary" "${OUTPUT_DIR}/bin/${abi}/ffmpeg"
  chmod +x "${OUTPUT_DIR}/bin/${abi}/ffmpeg"

  echo "Completed Android ABI: ${abi}"
done

echo
echo "Android FFmpeg build completed successfully."
echo "FFmpeg output: ${OUTPUT_DIR}"
echo "Validation output: ${STATS_DIR}"
