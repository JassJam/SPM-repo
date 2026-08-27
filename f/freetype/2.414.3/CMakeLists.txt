include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/freetype/freetype.git
	TAG VER-2-14-3
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DBUILD_SHARED_LIBS=${_shared_build}"
)
spm_cmake_build()

file(RENAME
     ${CMAKE_CURRENT_SOURCE_DIR}/install/include/freetype2/freetype
     ${CMAKE_CURRENT_SOURCE_DIR}/install/include/freetype)
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/install/include/freetype2/ft2build.h
     DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/install/include)
file(REMOVE_RECURSE ${CMAKE_CURRENT_SOURCE_DIR}/install/include/freetype2)

spm_create_target(
    NAME freetype
)
