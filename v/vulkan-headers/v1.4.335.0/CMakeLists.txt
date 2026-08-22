include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/KhronosGroup/Vulkan-Hpp.git
	TAG v1.4.335
)

set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-copy-install")
spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
if(NOT ${exists})
	file(COPY
		"${CMAKE_CURRENT_LIST_DIR}/source/Vulkan-Headers/include"
		DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/install"
	)
	file(COPY
		"${CMAKE_CURRENT_LIST_DIR}/source/vulkan"
		DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/install/include"
	)

    spm_write_stamp_file(FILE "${_stamp_file}")
endif()

spm_create_target(
    NAME vulkan-headers
)
