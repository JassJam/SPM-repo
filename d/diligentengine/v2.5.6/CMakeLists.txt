cmake_minimum_required(VERSION 3.21)
project(diligentengine_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/DiligentGraphics/DiligentEngine.git GIT_TAG v2.5.6)

set(install_pdb ON)
if(${CMAKE_BUILD_TYPE} STREQUAL "Release")
	set(install_pdb OFF)
endif()

set(DILIGENT_INSTALL_CORE ON CACHE BOOL "Install core module." FORCE)
set(DILIGENT_INSTALL_TOOLS OFF CACHE BOOL "Install tools module." FORCE)
set(DILIGENT_INSTALL_FX OFF CACHE BOOL "Install FX module." FORCE)
set(DILIGENT_INSTALL_SAMPLES OFF CACHE BOOL "Install Samples module." FORCE)
set(DILIGENT_INSTALL_PDB ${install_pdb} CACHE BOOL "Install program debug module." FORCE)
set(DILIGENT_NO_FORMAT_VALIDATION ON CACHE BOOL "" FORCE)

set(CLANG_FORMAT_EXECUTABLE "" CACHE STRING "" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
