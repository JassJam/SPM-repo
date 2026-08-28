include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/microsoft/mimalloc.git
	TAG v3.3.2
)

spm_apply_patch(
	PATCHES
	patches/mimalloc-multiconfig-obj.patch
)

if(WIN32 AND CMAKE_SIZEOF_VOID_P EQUAL 4)
	spm_apply_patch(
		PATCHES
		patches/x86-port.patch
	)
endif()

set(_static_build "ON")
set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
    set(_static_build "OFF")
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DMI_BUILD_STATIC=${_static_build}"
	"-DMI_BUILD_SHARED=${_shared_build}"
	"-DMI_BUILD_TESTS=OFF"
	"-DMI_INSTALL_TOPLEVEL=ON"
)
spm_cmake_build()

spm_create_target(
    NAME mimalloc
    OUT_TARGET_NAME _target_name
)

if(SPM_BUILD_SHARED_LIBS)
    target_compile_definitions(${_target_name} INTERFACE MI_SHARED_LIB=1)
endif()
