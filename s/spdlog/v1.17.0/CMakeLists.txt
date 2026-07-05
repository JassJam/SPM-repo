cmake_minimum_required(VERSION 3.21)
project(spdlog_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/gabime/spdlog.git GIT_TAG v1.17.0)

set(SPDLOG_BUILD_SHARED ${BUILD_SHARED_LIBS} CACHE BOOL "" FORCE)
set(SPDLOG_INSTALL ON CACHE BOOL "" FORCE)

set(SPDLOG_SYSTEM_INCLUDES ON CACHE BOOL "" FORCE)
set(SPDLOG_INSTALL ON CACHE BOOL "" FORCE)
set(SPDLOG_USE_STD_FORMAT ON CACHE BOOL "" FORCE)
set(SPDLOG_FMT_EXTERNAL OFF CACHE BOOL "Use external fmt library instead of bundled." FORCE)
set(SPDLOG_FMT_EXTERNAL_HO OFF CACHE BOOL "Use external fmt header-only library instead of bundled." FORCE)
set(SPDLOG_NO_EXCEPTIONS OFF CACHE BOOL "Compile with -fno-exceptions. Call abort() on any spdlog exceptions." FORCE)
set(SPDLOG_NO_TZ_OFFSET OFF CACHE BOOL "Omit %z timezone offset (use on platforms without tm_gmtoff)." FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
