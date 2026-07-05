cmake_minimum_required(VERSION 3.21)
project(spdlog_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/gabime/spdlog.git GIT_TAG v1.15.1)

set(SPDLOG_BUILD_SHARED ${BUILD_SHARED_LIBS} CACHE BOOL "" FORCE)
set(SPDLOG_INSTALL      ON  CACHE BOOL "" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
