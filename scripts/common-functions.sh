#!/usr/bin/env bash

set -euo pipefail

downloadTarArchive() {
  local library_name="$1"
  local download_url="$2"
  local need_extra_directory="${3:-false}"

  local archive_name="${download_url##*/}"
  local library_sources="${archive_name%.tar.*}"

  echo "Ensuring sources of ${library_name} in ${library_sources}"

  if [[ ! -d "$library_sources" ]]; then
    curl -fL --retry 3 --retry-all-errors -O "$download_url"

    local extraction_dir="."

    if [[ "$need_extra_directory" == "true" ]]; then
      extraction_dir="$library_sources"
      mkdir -p "$extraction_dir"
    fi

    tar xf "$archive_name" -C "$extraction_dir"
    rm -f "$archive_name"
  fi

  export "SOURCES_DIR_${library_name}=$(pwd)/${library_sources}"
}
