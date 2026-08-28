include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/freetype/freetype.git
	TAG VER-2-14-3
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

if(NOT FT_DISABLE_ZLIB)
	set(FT_DISABLE_ZLIB ON)
endif()
if(NOT FT_DISABLE_BZIP2)
	set(FT_DISABLE_BZIP2 ON)
endif()
if(NOT FT_DISABLE_PNG)
	set(FT_DISABLE_PNG ON)
endif()
if(NOT FT_DISABLE_HARFBUZZ)
	set(FT_DISABLE_HARFBUZZ ON)
endif()
if(NOT FT_DISABLE_BROTLI)
	set(FT_DISABLE_BROTLI ON)
endif()
if(NOT FT_ENABLE_ERROR_STRINGS)
	set(FT_ENABLE_ERROR_STRINGS ON)
endif()

spm_cmake_configure(
	OPTIONS
	"-DBUILD_SHARED_LIBS=${_shared_build}"
	"-DFT_DISABLE_ZLIB=${FT_DISABLE_ZLIB}"
	"-DFT_DISABLE_BZIP2=${FT_DISABLE_BZIP2}"
	"-DFT_DISABLE_PNG=${FT_DISABLE_PNG}"
	"-DFT_DISABLE_HARFBUZZ=${FT_DISABLE_HARFBUZZ}"
	"-DFT_DISABLE_BROTLI=${FT_DISABLE_BROTLI}"
	"-DFT_ENABLE_ERROR_STRINGS=${FT_ENABLE_ERROR_STRINGS}"
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
