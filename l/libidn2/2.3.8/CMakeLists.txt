include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_download_file(
    URL "https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz"
    DESTINATION "libidn2-2.3.8.tar.gz")

spm_extract_archive(
    ARCHIVE "libidn2-2.3.8.tar.gz"
    DESTINATION source
    STRIP_COMPONENTS 1)

set(_shared "no")
set(_static "yes")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "yes")
    set(_static "no")
endif()

spm_autotools_configure(
    OPTIONS
    "--enable-shared=${_shared}"
    "--enable-static=${_static}"
    --disable-doc
    --disable-nls)

spm_autotools_build()

spm_create_target(NAME libidn2)
