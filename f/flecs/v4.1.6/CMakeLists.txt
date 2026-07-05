cmake_minimum_required(VERSION 3.21)
project(flecs_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/SanderMertens/flecs.git GIT_TAG v4.1.6)

set(FLECS_STATIC NOT ${BUILD_SHARED_LIBS} CACHE BOOL "" FORCE)
set(FLECS_SHARED ${BUILD_SHARED_LIBS} CACHE BOOL "" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
