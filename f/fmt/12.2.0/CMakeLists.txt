cmake_minimum_required(VERSION 3.21)
project(fmt_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/fmtlib/fmt.git GIT_TAG 12.2.0)

set(FMT_DOC OFF CACHE BOOL "Generate the doc target." FORCE)
set(FMT_INSTALL ON CACHE BOOL "Generate the install target." FORCE)
set(FMT_TEST ON CACHE BOOL "Generate the test target." FORCE)
set(FMT_FUZZ OFF CACHE BOOL "Generate the fuzz target." FORCE)
set(FMT_OS ON CACHE BOOL "Include OS-specific APIs." FORCE)
set(FMT_MODULE OFF CACHE BOOL "Build a module library." FORCE)
set(FMT_SYSTEM_HEADERS ON CACHE BOOL "Expose headers with marking them as system." FORCE)
set(FMT_UNICODE ON CACHE BOOL "Enable Unicode support." FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
