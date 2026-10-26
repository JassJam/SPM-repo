include_guard(DIRECTORY)

set(_spm_default_hash "@SPM_HASH@")
set(_spm_default_url
    "https://codeberg.org/JassJam/SPM-repo/releases/download/@SPM_TAG@/spm-release.tar.gz")

if(NOT SPM_DOWNLOAD_URL)
    set(SPM_DOWNLOAD_URL "${_spm_default_url}")
endif()
if(NOT SPM_DOWNLOAD_HASH)
    set(SPM_DOWNLOAD_HASH "${_spm_default_hash}")
endif()

if(SPM_SOURCE_CACHE)
elseif(DEFINED ENV{SPM_SOURCE_CACHE})
    set(SPM_SOURCE_CACHE "$ENV{SPM_SOURCE_CACHE}")
else()
    set(SPM_SOURCE_CACHE "${CMAKE_BINARY_DIR}/_spm")
endif()

set(_spm_archive "${SPM_SOURCE_CACHE}/spm-release.tar.gz")
set(_spm_dir "${SPM_SOURCE_CACHE}/spm-${SPM_DOWNLOAD_HASH}")

set(_spm_need_download TRUE)
if(EXISTS "${_spm_archive}")
    file(SHA256 "${_spm_archive}" _spm_actual_hash)
    if(_spm_actual_hash STREQUAL SPM_DOWNLOAD_HASH)
        set(_spm_need_download FALSE)
    endif()
endif()

if(_spm_need_download)
    message(STATUS "SPM: downloading ${SPM_DOWNLOAD_URL}")
    file(MAKE_DIRECTORY "${SPM_SOURCE_CACHE}")
    file(DOWNLOAD
        "${SPM_DOWNLOAD_URL}"
        "${_spm_archive}"
        EXPECTED_HASH SHA256=${SPM_DOWNLOAD_HASH}
        TLS_VERIFY ON
        STATUS _spm_status)
    list(GET _spm_status 0 _spm_code)
    if(NOT _spm_code EQUAL 0)
        list(GET _spm_status 1 _spm_msg)
        file(REMOVE "${_spm_archive}")
        message(FATAL_ERROR "SPM: download failed (${_spm_code}): ${_spm_msg}")
    endif()
    file(REMOVE_RECURSE "${_spm_dir}")
endif()

if(NOT EXISTS "${_spm_dir}/spm.cmake")
    file(MAKE_DIRECTORY "${_spm_dir}")
    file(ARCHIVE_EXTRACT INPUT "${_spm_archive}" DESTINATION "${_spm_dir}")
endif()

include("${_spm_dir}/spm.cmake")
