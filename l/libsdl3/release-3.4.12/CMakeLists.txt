include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/libsdl-org/SDL.git
	TAG release-3.4.12
)

spm_apply_patch(
    PATCHES
        patches/fix-null-cast.patch
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DSDL_INSTALL=ON"
    "-DSDL_TEST_LIBRARY=OFF"
	"-DBUILD_SHARED_LIBS=${_shared_build}"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME libsdl3
	MODULE sdl3
)
