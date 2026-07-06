cmake_minimum_required(VERSION 3.21)
project(libsdl3_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/libsdl-org/SDL.git GIT_TAG release-3.4.12)

set(SDL_INSTALL ON CACHE BOOL "Enable installation of SDL3" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
