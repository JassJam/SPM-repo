include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/asmjit/asmjit.git
	TAG 0bd5787b54b575ed94bf32ac452153b34385c514
)

set(_shared_build "OFF")
set(_asmjit_static "ON")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
	set(_asmjit_static "OFF")
endif()

spm_cmake_configure(
	OPTIONS
	"-DBUILD_SHARED_LIBS=${_shared_build}"
	"-DASMJIT_STATIC=${_asmjit_static}"
)
spm_cmake_build()

spm_create_target(
    NAME asmjit
    OUT_TARGET_NAME _target_name
)
if(_asmjit_static)
	target_compile_definitions(${_target_name} INTERFACE ASMJIT_STATIC)
endif()
