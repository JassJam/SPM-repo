include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/SanderMertens/flecs.git
	TAG v4.1.6
)

set(_static_build "ON")
set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
    set(_static_build "OFF")
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DFLECS_STATIC=${_static_build}"
	"-DFLECS_SHARED=${_shared_build}"
	"-DFLECS_PIC=ON"
)
spm_cmake_build()

spm_create_target(
    NAME flecs
    OUT_TARGET_NAME _target_name
)

if(NOT SPM_BUILD_SHARED_LIBS)
    target_compile_definitions(${_target_name} INTERFACE flecs_STATIC=1)
endif()
