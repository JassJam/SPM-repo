include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

if(NOT DEFINED ERROR_TYPE)
	set(ERROR_TYPE "result")
endif()

if(ERROR_TYPE STREQUAL "result")
	set(DIPP_USE_RESULT ON)
	spm_requires(
		NAME boost
		VERSION 1.92.0
		IMPORT_NAME dipp_deps
		OPTIONS
		"BOOST_INCLUDE_LIBRARIES=leaf"
	)
endif()

spm_git_clone(
	URL https://github.com/JassJam/dipp.git
	TAG v1.1.2
)

spm_cmake_configure(
	OPTIONS
	"-DERROR_TYPE=${ERROR_TYPE}"
    DEPENDENCIES dipp_deps::boost
)
spm_cmake_build()

spm_create_target(
    NAME dipp
	OUT_TARGET_NAME _target_name
    DEPENDENCIES dipp_deps::boost
)

if(DIPP_USE_RESULT)
    target_compile_definitions(${_target_name} INTERFACE DIPP_USE_RESULT)
endif()
