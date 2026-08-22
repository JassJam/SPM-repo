include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_requires(
    NAME zlib
    VERSION v1.3.2
    OPTIONS
    "ZLIB_BUILD_MINIZIP=ON"
    "MINIZIP_INSTALL=ON"
    "MINIZIP_ENABLE_BZIP2=OFF"
    "MINIZIP_BUILD_STATIC=ON"
    "MINIZIP_BUILD_SHARED=OFF"
)

spm_git_clone(
	URL https://github.com/pnggroup/libpng.git
	TAG v1.6.58
)

spm_cmake_configure(
    DEPENDENCIES zlib::zlib
)
spm_cmake_build()

spm_create_target(
    NAME libpng
    DEPENDENCIES zlib::zlib
)
