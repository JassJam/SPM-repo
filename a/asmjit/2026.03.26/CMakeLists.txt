cmake_minimum_required(VERSION 3.21)
project(asmjit_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/asmjit/asmjit.git GIT_TAG 0bd5787b54b575ed94bf32ac452153b34385c514)

set(ASMJIT_STATIC ${BUILD_SHARED_LIBS} CACHE BOOL "" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
