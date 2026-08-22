include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/KhronosGroup/Vulkan-Hpp.git
	TAG v1.4.335
)

file(COPY
    "${CMAKE_CURRENT_LIST_DIR}/source/Vulkan-Headers/include"
    DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/install"
)

file(COPY
    "${CMAKE_CURRENT_LIST_DIR}/source/vulkan"
    DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/install/include"
)

spm_create_target(
    NAME vulkan-headers
)
