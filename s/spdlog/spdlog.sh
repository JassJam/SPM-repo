#!/usr/bin/env bash
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>" >&2
    exit 1
fi

VERSION="$1"

DIR="${VERSION}"
FILE="${DIR}/CMakeLists.txt"

if [[ -e "$DIR" ]]; then
    echo "Error: directory '$DIR' already exists." >&2
    exit 1
fi

mkdir -p "$DIR"

cat > "$FILE" <<EOF
cmake_minimum_required(VERSION 3.21)
project(spdlog_pkg)
include(\${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/gabime/spdlog.git GIT_TAG ${DIR})

set(SPDLOG_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(SPDLOG_INSTALL      ON  CACHE BOOL "" FORCE)

add_subdirectory(\${SPM_PKG_SOURCE_DIR} src)
EOF

echo "Created: $FILE"
