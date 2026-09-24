include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_download_file(
    URL "https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz"
    DESTINATION "libidn2-2.3.8.tar.gz")

spm_extract_archive(
    ARCHIVE "libidn2-2.3.8.tar.gz"
    DESTINATION source
    STRIP_COMPONENTS 1)

spm_requires(NAME libunistring VERSION 1.4.2)

set(_idn2_deps libunistring::libunistring)

set(_shared "no")
set(_static "yes")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "yes")
    set(_static "no")
endif()

set(_configure_opts
    "--enable-shared=${_shared}"
    "--enable-static=${_static}"
    --disable-doc
    --disable-nls)

if(MSVC)
    spm_write_msvc_compile_wrapper(_msvc_compile_wrapper)

    list(APPEND _configure_opts
        "CC=${_msvc_compile_wrapper} cl -nologo"
        "CXX=${_msvc_compile_wrapper} cl -nologo -EHsc"
        "CFLAGS=-MD"
        "CXXFLAGS=-MD"
        "LD=link"
        "NM=dumpbin -symbols"
        "AR=${_msvc_compile_wrapper} lib -nologo"
        "RANLIB=:")
endif()

spm_autotools_configure(
    OPTIONS
    ${_configure_opts}
    DEPENDENCIES
    ${_idn2_deps})

spm_autotools_build()

spm_create_target(NAME libidn2 DEPENDENCIES ${_idn2_deps})
