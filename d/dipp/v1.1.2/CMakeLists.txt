include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

if(NOT DIPP_USE_RESULT)
	set(DIPP_USE_RESULT ON)
endif()

spm_git_clone(
	URL https://github.com/JassJam/dipp.git
	TAG v1.1.2
)

spm_cmake_configure(
	OPTIONS
	"-DDIPP_USE_RESULT=${DIPP_USE_RESULT}"
)
spm_cmake_build()

spm_create_target(
    NAME dipp
	OUT_TARGET_NAME _target_name
)

if(DIPP_USE_RESULT)
    target_compile_definitions(${_target_name} INTERFACE DIPP_USE_RESULT)
endif()
