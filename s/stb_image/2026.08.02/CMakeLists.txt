include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/nothings/stb.git
	TAG 2c980bb59875b0d32144a71867fbdebb2f77cd20
)

set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-init-stb")
spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
if(NOT exists)
	file(GLOB _files_to_copy ${CMAKE_CURRENT_LIST_DIR}/source/*.h ${CMAKE_CURRENT_LIST_DIR}/source/*.c)
	file(COPY ${_files_to_copy} DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/install/include/stb)
    spm_write_stamp_file(FILE "${_stamp_file}")
endif()

spm_create_target(NAME stb_image)
