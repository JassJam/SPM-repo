cmake_minimum_required(VERSION 3.21)
project(asmjit_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/assimp/assimp.git GIT_TAG v6.0.5)

set(ASSIMP_BUILD_FRAMEWORK OFF CACHE BOOL "Build package as Mac OS X Framework bundle." FORCE)
set(ASSIMP_DOUBLE_PRECISION OFF CACHE BOOL "Set to ON to enable double precision processing." FORCE)
set(ASSIMP_ANDROID_JNIIOSYSTEM OFF CACHE BOOL "Android JNI IOSystem support is active." FORCE)
set(ASSIMP_BUILD_ASSIMP_TOOLS OFF CACHE BOOL "If the supplementary tools for Assimp are built in addition to the library." FORCE)
set(ASSIMP_BUILD_TESTS ${BUILD_TESTING} CACHE BOOL "Set to ON to enable double precision processing." FORCE)
set(ASSIMP_INSTALL ON CACHE BOOL "Disable this if you want to use assimp as a submodule." FORCE)
set(ASSIMP_WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)
set(ASSIMP_ASAN OFF CACHE BOOL "" FORCE)
set(ASSIMP_UBSAN OFF CACHE BOOL "" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
