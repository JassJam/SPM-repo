cmake_minimum_required(VERSION 3.21)
project(mimalloc_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/DiligentGraphics/DiligentEngine.git GIT_TAG v2.5.6)

set(DILIGENT_INSTALL_CORE ON CACHE BOOL "Install core module." FORCE)
set(DILIGENT_INSTALL_TOOLS ON CACHE BOOL "Install tools module." FORCE)
set(DILIGENT_INSTALL_FX ON CACHE BOOL "Install FX module." FORCE)
set(DILIGENT_INSTALL_SAMPLES ON CACHE BOOL "Install Samples module." FORCE)
set(DILIGENT_INSTALL_PDB ON CACHE BOOL "Install program debug module." FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
