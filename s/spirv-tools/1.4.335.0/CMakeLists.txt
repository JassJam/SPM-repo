include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/KhronosGroup/SPIRV-Tools.git
	TAG vulkan-sdk-1.4.335.0
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_requires(
	NAME spirv-headers
	VERSION 1.4.335.0
	OUT_INSTALL_DIR _install_dir
)
string(REPLACE "\\" "/" _install_dir "${_install_dir}")

spm_cmake_configure(
	OPTIONS
		"-DSPIRV_SKIP_TESTS=ON"
		"-DSPIRV_WERROR=OFF"
		"-DBUILD_SHARED_LIBS=${_shared_build}"
		"-DSPIRV-Headers_SOURCE_DIR=${_install_dir}"
    DEPENDENCIES spirv-headers::spirv-headers
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME spirv-tools
    MODULE SPIRV-Tools
)
