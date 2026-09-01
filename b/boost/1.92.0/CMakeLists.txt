include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_download_file(
	URL https://github.com/boostorg/boost/releases/download/boost-1.92.0/boost-1.92.0-cmake.7z
	EXPECTED_HASH SHA256=158852d45a7ce23de167a3dc2e57b04490829b233f06e835d5c81a65547ef68b
	DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/downloads/boost.7z"
)

spm_extract_archive(
    ARCHIVE "${CMAKE_CURRENT_SOURCE_DIR}/downloads/boost.7z"
    DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/source"
    STRIP_COMPONENTS 1
    DELETE_ARCHIVE
)

set(_options "")
if(NOT DEFINED BOOST_INSTALL_LAYOUT)
    list(APPEND _options "-DBOOST_INSTALL_LAYOUT=system")
endif()

spm_cmake_configure(
    OPTIONS
    ${_options}
)
spm_cmake_build()

spm_create_target(
    NAME boost
)
