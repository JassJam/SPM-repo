cmake_minimum_required(VERSION 3.21)
project(abseil_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/abseil/abseil-cpp.git GIT_TAG 20260526.0)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
