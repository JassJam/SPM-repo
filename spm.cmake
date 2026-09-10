include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.24)

#

set(SPM_ROOT
    "${CMAKE_CURRENT_LIST_DIR}"
    CACHE INTERNAL "Path to spm.cmake's directory")

set(SPM_REMOTE
    ON
    CACHE BOOL "Fetch missing recipes from a registry")

set(SPM_LOGGING
    ON
    CACHE BOOL "SPM logging")

set(SPM_VERBOSE_OUTPUT
    OFF
    CACHE BOOL "Verbose SPM logging")

# The registry is one of:
#   - a local/mounted directory containing plain, already-unzipped recipe folders at
#   "<registry>/<letter>/<n>/<version>/". - "git+https://..." or "git+ssh://..." — a git repo containing plain,
#   already-unzipped recipe folders in the same layout.
#   - a plain "http://" or "https://" base URL serving one tarball per (name, version) at "<registry>/<letter>/<n>/<version>.tar.gz".
#   Detected automatically from the string's shape.
set(SPM_REGISTRY
    "git+https://codeberg.org/JassJam/SPM-repo.git"
    CACHE STRING "Default registry: local/mounted dir, git+https(s)/git+ssh repo, or http(s) tarball server")

# Optional default HTTP headers for the registry (e.g. an auth token),
if(NOT DEFINED SPM_REGISTRY_HEADERS AND DEFINED ENV{SPM_REGISTRY_HEADERS})
    set(_spm_default_headers "$ENV{SPM_REGISTRY_HEADERS}")
else()
    set(_spm_default_headers "")
endif()
set(SPM_REGISTRY_HEADERS
    "${_spm_default_headers}"
    CACHE STRING "Default HTTP headers sent with registry downloads, semicolon-separated 'Key: Value' entries")

set(SPM_PACKAGES_DIR
    "${CMAKE_BINARY_DIR}/_spm/packages/repositories"
    CACHE PATH "Recipe root (source of truth)")
set(SPM_CACHE_DIRECTORY
    "${CMAKE_BINARY_DIR}/_spm/packages/cache"
    CACHE PATH "Precompiled/installed binary cache")
set(SPM_DOWNLOADS_DIR
    "${CMAKE_BINARY_DIR}/_spm/downloads"
    CACHE PATH "Download cache directory")
set(SPM_PARALLEL_JOBS
    "4"
    CACHE STRING "Parallel build jobs used when building a recipe")
set(SPM_FORCE_REBUILD
    OFF
    CACHE BOOL "Ignore all cache hits and rebuild every requested package from scratch")
set(SPM_REGISTRY_REF
    ""
    CACHE STRING "Default branch/tag to check out for git+ registries (empty = repo's default branch)")

#

find_program(CTEST_EXECUTABLE NAMES ctest)
find_program(GIT_EXECUTABLE NAMES git)

macro(_spm_requires_git)
    if(NOT GIT_EXECUTABLE)
        spm_log_fatal("no git executable was found")
    endif()
endmacro()

macro(spm_log)
    if(SPM_LOGGING)
        message(STATUS "[SPM]: ${ARGV}.")
    endif()
endmacro()

macro(spm_log_debug)
    if(SPM_VERBOSE_OUTPUT)
        message(STATUS "[SPM]: ${ARGV}.")
    endif()
endmacro()

macro(spm_log_fatal)
    message(FATAL_ERROR "[SPM]: ${ARGV}.")
endmacro()

macro(spm_execute_process)
    spm_log_debug("Executing ${ARGV}")
    execute_process(${ARGV})
endmacro()

#

function(_spm_lowercase_first_char str out_var)
    string(SUBSTRING "${str}" 0 1 _first)
    string(TOLOWER "${_first}" _first)
    set(${out_var}
        "${_first}"
        PARENT_SCOPE)
endfunction()

define_property(
    GLOBAL
    PROPERTY SPM_REQUIRED_PACKAGES
    BRIEF_DOCS "name@version pairs already resolved by SPM"
    FULL_DOCS "Used to dedupe and detect version conflicts across the tree")

#

function(_spm_get_build_hash OUT_HASH)
    set(key ":${ARGN}:")
    string(SHA256 _hash "${key}")

    foreach(
        _var
        CMAKE_GENERATOR_PLATFORM
        CMAKE_GENERATOR
        CMAKE_SYSTEM_NAME
        CMAKE_SYSTEM_PROCESSOR
        CMAKE_BUILD_TYPE
        CMAKE_C_FLAGS
        CMAKE_CXX_FLAGS
        CMAKE_EXE_LINKER_FLAGS
        CMAKE_SHARED_LINKER_FLAGS)
        if(DEFINED ${_var})
            list(APPEND key ${_var}=${${_var}})
        endif()
    endforeach()

    string(SHA256 _hash "${key}")
    set(${OUT_HASH}
        "${_hash}"
        PARENT_SCOPE)
endfunction()

function(_spm_build_and_import name version recipe_dir)
    set(options FORCE SHARED)
    set(oneValArgs
        GIT_URL
        GIT_TAG
        URL
        HASH
        IMPORT_NAME
        OUT_INSTALL_DIR
        OUT_BUILD_DIR)
    set(multiValArgs OPTIONS IMPORT_DEFINITIONS IMPORT_EXCLUDE)
    cmake_parse_arguments(B "${options}" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    _spm_lowercase_first_char("${name}" _letter)

    if(CMAKE_BUILD_TYPE)
        set(_pkg_build_type "${CMAKE_BUILD_TYPE}")
    else()
        set(_pkg_build_type "Release")
    endif()

    if(B_SHARED)
        set(_pkg_build_shared "ON")
    else()
        set(_pkg_build_shared "OFF")
    endif()

    _spm_get_build_hash(
        _hash
        ${name}
        ${version}
        ${B_IMPORT_NAME}
        ${B_GIT_URL}
        ${B_GIT_TAG}
        ${B_URL}
        ${B_HASH}
        ${B_OPTIONS}
        ${_pkg_build_type}
        ${_pkg_build_shared})

    set(_build_hash_dir "${_hash}")
    if(WIN32)
        string(SUBSTRING "${_hash}" 0 16 _build_hash_dir)
    endif()

    set(_build_dir "${CMAKE_BINARY_DIR}/_spm/${name}/${version}/${_build_hash_dir}")
    set(_cache_dir "${SPM_CACHE_DIRECTORY}/${_letter}/${name}/${_hash}")

    if(B_OUT_BUILD_DIR)
        set(${B_OUT_BUILD_DIR}
            "${_build_dir}"
            PARENT_SCOPE)
    endif()
    if(B_OUT_INSTALL_DIR)
        set(${B_OUT_INSTALL_DIR}
            "${_build_dir}/install"
            PARENT_SCOPE)
        spm_log_debug("OUT_INSTALL_DIR: ${_build_dir}/install")
    endif()

    set(_input_script_file_name "spm-input.cmake")
    set(_input_script "${_build_dir}/${_input_script_file_name}")
    file(
        WRITE "${_input_script}"
        "\
set(CMAKE_BUILD_TYPE \"${_pkg_build_type}\" CACHE INTERNAL \"\")
set(CMAKE_PROJECT_INCLUDE \"${_build_dir}/spm-recipe.cmake\" CACHE INTERNAL \"\")
set(BUILD_TESTING OFF CACHE INTERNAL \"\")
set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE INTERNAL \"\")
set(CMAKE_OBJECT_PATH_MAX 1024 CACHE INTERNAL \"\")
")
    block()
    set(SPM_IMPORT_NAME ${B_IMPORT_NAME})
    set(SPM_BUILD_TYPE ${_pkg_build_type})
    set(SPM_BUILD_SHARED_LIBS ${_pkg_build_shared})

    foreach(_cfg ${B_OPTIONS})
        string(FIND "${_cfg}" "=" _eq_pos)
        if(_eq_pos EQUAL -1)
            spm_log_fatal("Malformed OPTIONS entry '${_cfg}', expected NAME=VALUE")
        endif()
        string(SUBSTRING "${_cfg}" 0 ${_eq_pos} _opt_name)
        math(EXPR _val_start "${_eq_pos} + 1")
        string(SUBSTRING "${_cfg}" ${_val_start} -1 _opt_val)

        if(DEFINED _SPM_YAML_SUBLIST_SEP AND _opt_val MATCHES "${_SPM_YAML_SUBLIST_SEP}")
            string(REPLACE "${_SPM_YAML_SUBLIST_SEP}" ";" _opt_val "${_opt_val}")
        endif()

        set(${_opt_name} ${_opt_val})
        file(APPEND "${_input_script}" "set(${_opt_name} \"${_opt_val}\" CACHE INTERNAL \"\" FORCE)\n")
    endforeach()

    spm_log_debug("Configuring '${name}@${version}' (${_hash})")
    foreach(
        _var
        CMAKE_GENERATOR_PLATFORM
        CMAKE_TOOLCHAIN_FILE
        CMAKE_SYSTEM_NAME
        CMAKE_SYSTEM_PROCESSOR
        CMAKE_C_COMPILER
        CMAKE_C_FLAGS
        CMAKE_C_STANDARD
        CMAKE_CXX_COMPILER
        CMAKE_CXX_FLAGS
        CMAKE_CXX_STANDARD)
        if(DEFINED ${_var})
            file(APPEND "${_input_script}" "set(${_var} \"${${_var}}\" CACHE INTERNAL \"\" FORCE)\n")
        endif()
    endforeach()

    file(GLOB _files_to_copy ${recipe_dir}/*)
    file(COPY ${_files_to_copy} DESTINATION ${_build_dir})
    file(COPY "${SPM_ROOT}/spm.cmake" "${SPM_ROOT}/spm-recipe.cmake" DESTINATION "${_build_dir}")

    add_subdirectory(${_build_dir} ${_cache_dir} SYSTEM)
    endblock()
endfunction()

# Locate the recipe directory for name@version.
# packages/repositories/<l>/<n>/<version>/CMakeLists.txt If missing locally and
# SPM_REMOTE is ON, resolve it from `registry`: - local directory      used IN
# PLACE, never copied. - git+https(s)/ssh     sparse partial clone of just that
# one subtree, moved into SPM_PACKAGES_DIR. - http(s) URL          tarball
# downloaded + extracted into SPM_PACKAGES_DIR.
function(
    _spm_resolve_recipe_dir
    name
    version
    registry
    ref
    headers
    out_dir)
    if(NOT version)
        spm_log_fatal("VERSION is required to resolve a recipe for '${name}'")
    endif()

    _spm_lowercase_first_char("${name}" _letter)
    set(_local_repo_dir "${SPM_PACKAGES_DIR}/${_letter}/${name}/${version}")
    set(_path_in_repo "${_letter}/${name}/${version}")

    if(EXISTS "${_local_repo_dir}/CMakeLists.txt")
        spm_log_debug("Using recipe for '${name}@${version}' at ${_local_repo_dir}")
        set(${out_dir}
            "${_local_repo_dir}"
            PARENT_SCOPE)
        return()
    endif()

    if(IS_DIRECTORY "${registry}")
        set(_src "${registry}/${_path_in_repo}")
        if(NOT EXISTS "${_src}/CMakeLists.txt")
            spm_log_fatal(
                "No recipe for '${name}@${version}' found under local registry '${registry}' (expected ${_src})")
        endif()
        spm_log_debug("Using recipe for '${name}@${version}' directly from local registry ${_src}")
        set(${out_dir}
            "${_src}"
            PARENT_SCOPE)
        return()

    elseif(registry MATCHES "^git\\+(.+)$")
        if(NOT GIT_EXECUTABLE)
            spm_log_fatal("Registry '${registry}' needs git, but no git executable was found")
        endif()
        set(_git_url "${CMAKE_MATCH_1}")

        set(_git_config_args "")
        foreach(_h ${headers})
            list(APPEND _git_config_args -c "http.extraHeader=${_h}")
        endforeach()

        set(_scratch_dir "${CMAKE_BINARY_DIR}/_spm/_downloads/${name}-${version}-git")
        if(EXISTS "${_scratch_dir}")
            file(REMOVE_RECURSE "${_scratch_dir}")
        endif()

        set(_clone_args --filter=blob:none --sparse --depth 1)
        if(ref)
            list(APPEND _clone_args --branch "${ref}")
        endif()

        spm_log_debug("Sparse-cloning '${_path_in_repo}' from ${_git_url}")
        spm_execute_process(
            COMMAND
            ${GIT_EXECUTABLE}
            ${_git_config_args}
            clone
            ${_clone_args}
            "${_git_url}"
            "${_scratch_dir}"
            RESULT_VARIABLE
            _git_result
            OUTPUT_VARIABLE
            _git_output
            ERROR_VARIABLE
            _git_output)
        if(NOT _git_result EQUAL 0)
            spm_log_fatal("git clone failed for registry '${registry}':\n${_git_output}")
        endif()

        spm_execute_process(
            COMMAND
            ${GIT_EXECUTABLE}
            sparse-checkout
            set
            "${_path_in_repo}"
            WORKING_DIRECTORY
            "${_scratch_dir}"
            RESULT_VARIABLE
            _sparse_result
            OUTPUT_VARIABLE
            _sparse_output
            ERROR_VARIABLE
            _sparse_output)
        if(NOT _sparse_result EQUAL 0)
            file(REMOVE_RECURSE "${_scratch_dir}")
            spm_log_fatal("git sparse-checkout failed for '${name}@${version}':\n${_sparse_output}")
        endif()

        set(_fetched_dir "${_scratch_dir}/${_path_in_repo}")
        if(NOT EXISTS "${_fetched_dir}/CMakeLists.txt")
            file(REMOVE_RECURSE "${_scratch_dir}")
            spm_log_fatal(
                "No recipe for '${name}@${version}' found in git registry '${registry}' (expected ${_path_in_repo})")
        endif()

        get_filename_component(_local_repo_parent "${_local_repo_dir}" DIRECTORY)
        file(MAKE_DIRECTORY "${_local_repo_parent}")
        file(RENAME "${_fetched_dir}" "${_local_repo_dir}")
        file(REMOVE_RECURSE "${_scratch_dir}")
        set(${out_dir}
            "${_local_repo_dir}"
            PARENT_SCOPE)
        return()

    elseif(registry MATCHES "^https?://")
        set(_tarball_url "${registry}/${_path_in_repo}.tar.gz")
        set(_tarball_dest "${SPM_DOWNLOADS_DIR}/${name}-${version}.tar.gz")
        file(MAKE_DIRECTORY "${SPM_DOWNLOADS_DIR}")

        set(_header_args "")
        foreach(_h ${headers})
            list(APPEND _header_args HTTPHEADER "${_h}")
        endforeach()

        spm_log_debug("Fetching '${name}@${version}' from ${_tarball_url}")
        file(
            DOWNLOAD "${_tarball_url}" "${_tarball_dest}"
            STATUS _dl_status
            TLS_VERIFY ON
            ${_header_args})
        list(GET _dl_status 0 _dl_code)
        if(NOT _dl_code EQUAL 0)
            list(GET _dl_status 1 _dl_message)
            file(REMOVE "${_tarball_dest}")
            spm_log_fatal("Failed to fetch '${name}@${version}' from ${_tarball_url}: ${_dl_message}")
        endif()

        file(MAKE_DIRECTORY "${_local_repo_dir}")
        file(ARCHIVE_EXTRACT INPUT "${_tarball_dest}" DESTINATION "${_local_repo_dir}")
        file(REMOVE "${_tarball_dest}")
        if(NOT EXISTS "${_local_repo_dir}/CMakeLists.txt")
            file(REMOVE_RECURSE "${_local_repo_dir}")
            spm_log_fatal("Archive for '${name}@${version}' had no CMakeLists.txt at its root")
        endif()
        set(${out_dir}
            "${_local_repo_dir}"
            PARENT_SCOPE)
    else()
        spm_log_fatal("SPM_REGISTRY '${registry}' is not a local directory, a git+https(s)/ssh URL, or an http(s) URL")
    endif()
endfunction()

function(_spm_require_package_enter)
    set(oneValArgs ALREADY_ENTERED REGISTRY REGISTRY_REF)
    set(multiValArgs HEADERS)
    cmake_parse_arguments(B "" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    get_property(_count GLOBAL PROPERTY SPM_REQUIRE_STACK_COUNT)
    if(_count)
        math(EXPR _new_count "${_count} + 1")
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_COUNT "${_new_count}")

        set(${B_ALREADY_ENTERED}
            TRUE
            PARENT_SCOPE)
        spm_log_debug("Re-entering (depth ${_new_count}), loaded saved registry/registry_ref/headers")
    else()
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_COUNT "1")
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_REGISTRY "${B_REGISTRY}")
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_REGISTRY_REF "${B_REGISTRY_REF}")
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_HEADERS "${B_HEADERS}")

        set(${B_ALREADY_ENTERED}
            FALSE
            PARENT_SCOPE)
        spm_log_debug("Entering (depth 1), saving directory/registry/registry_ref/headers")
    endif()
endfunction()

function(_spm_require_package_exit)
    get_property(_count GLOBAL PROPERTY SPM_REQUIRE_STACK_COUNT)
    if(NOT _count)
        spm_log_fatal("_spm_require_package_exit() called without a matching enter")
    endif()

    math(EXPR _new_count "${_count} - 1")

    if(_new_count LESS_EQUAL 0)
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_COUNT)
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_REGISTRY)
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_REGISTRY_REF)
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_HEADERS)
        spm_log_debug("Exiting (depth 0), cleared saved directory/registry/registry_ref/headers")
    else()
        set_property(GLOBAL PROPERTY SPM_REQUIRE_STACK_COUNT "${_new_count}")
        spm_log_debug("Exiting (depth ${_new_count})")
    endif()
endfunction()

# spm_require_package(
#   NAME                spdlog
#   VERSION             1.14.1
#   [GIT_URL            <override recipe's default>]
#   [GIT_TAG            <override recipe's default>]
#   [URL                <override recipe's default>]
#   [HASH               <override recipe's default>]
#   [DIRECTORY          <use an explicit local recipe dir instead of resolving via SPM_PACKAGES_DIR/SPM_REGISTRY>]
#   [REGISTRY]          <override SPM_REGISTRY for this package only>]
#   [REGISTRY_REF       <branch/tag for a git+ registry override, if not the repo's default branch>]
#   [OPTIONS]           "SOME_OPTION=ON" "OTHER_OPTION=OFF"]
#   [FORCE]             # force recompile and install the recipe
#   [SHARED]            # build a shared library instead of static (default)
#   [IMPORT_NAME        <pakage namespace to use>]
#   [OUT_INSTALL_DIR    <install_dir>]
# )
function(spm_require_package)
    set(options FORCE SHARED)
    set(oneValArgs
        NAME
        VERSION
        REGISTRY
        REGISTRY_REF
        GIT_URL
        GIT_TAG
        URL
        HASH
        IMPORT_NAME
        OUT_INSTALL_DIR)
    set(multiValArgs OPTIONS HEADERS IMPORT_DEFINITIONS IMPORT_EXCLUDE)
    cmake_parse_arguments(ARG "${options}" "${oneValArgs}" "${multiValArgs}" ${ARGN})

    if(NOT ARG_NAME OR NOT ARG_VERSION)
        spm_log_fatal("NAME and VERSION argument is required")
    endif()

    _spm_require_package_enter(
        ALREADY_ENTERED
        _already_entered
        REGISTRY
        ${ARG_REGISTRY}
        REGISTRY_REF
        ${ARG_REGISTRY_REF}
        HEADERS
        ${ARG_HEADERS})
    if(_already_entered)
        get_property(ARG_REGISTRY GLOBAL PROPERTY SPM_REQUIRE_STACK_REGISTRY)
        get_property(ARG_REGISTRY_REF GLOBAL PROPERTY SPM_REQUIRE_STACK_REGISTRY_REF)
        get_property(ARG_HEADERS GLOBAL PROPERTY SPM_REQUIRE_STACK_HEADERS)
    endif()

    if(ARG_REGISTRY)
        set(_effective_registry "${ARG_REGISTRY}")
    else()
        set(_effective_registry "${SPM_REGISTRY}")
    endif()
    if(ARG_REGISTRY_REF)
        set(_effective_ref "${ARG_REGISTRY_REF}")
    else()
        set(_effective_ref "${SPM_REGISTRY_REF}")
    endif()
    if(ARG_HEADERS)
        set(_effective_headers "${ARG_HEADERS}")
    else()
        set(_effective_headers "${SPM_REGISTRY_HEADERS}")
    endif()

    _spm_resolve_recipe_dir("${ARG_NAME}" "${ARG_VERSION}" "${_effective_registry}" "${_effective_ref}"
                            "${_effective_headers}" _recipe_dir)

    set(_unsupported_script "${_recipe_dir}/Support.cmake")
    if(EXISTS "${_unsupported_script}")
        unset(SPM_UNSUPPORTED_REASON)
        include("${_unsupported_script}")
        if(SPM_UNSUPPORTED_REASON)
            spm_log_debug("Recipe for '${ARG_NAME}@${ARG_VERSION}' is unsupported here: ${SPM_UNSUPPORTED_REASON}")
            _spm_require_package_exit()
            return()
        endif()
    endif()

    spm_log_debug("Building & importing '${ARG_NAME}@${ARG_VERSION}' from ${_recipe_dir}")

    set(_force_flag "")
    if(ARG_FORCE)
        set(_force_flag "FORCE")
    endif()
    set(_shared_flag "")
    if(ARG_SHARED)
        set(_shared_flag "SHARED")
    endif()
    if(ARG_IMPORT_NAME)
        set(_effective_import_name "${ARG_IMPORT_NAME}")
    else()
        set(_effective_import_name "${ARG_NAME}")
    endif()

    _spm_build_and_import(
        "${ARG_NAME}"
        "${ARG_VERSION}"
        "${_recipe_dir}"
        GIT_URL
        "${ARG_GIT_URL}"
        GIT_TAG
        "${ARG_GIT_TAG}"
        URL
        "${ARG_URL}"
        HASH
        "${ARG_HASH}"
        IMPORT_NAME
        "${_effective_import_name}"
        OPTIONS
        ${ARG_OPTIONS}
        ${_force_flag}
        ${_shared_flag}
        OUT_INSTALL_DIR
        _out_install_dir)

    if(ARG_OUT_INSTALL_DIR)
        set(${ARG_OUT_INSTALL_DIR}
            "${_out_install_dir}"
            PARENT_SCOPE)
    endif()

    set_property(GLOBAL APPEND PROPERTY SPM_REQUIRED_PACKAGES "${_pkg_key}")
    set_property(GLOBAL PROPERTY "SPM_INSTALL_DIR_${_pkg_key}" "${_out_install_dir}")

    _spm_require_package_exit()

    spm_log("Configured '${ARG_NAME}@${ARG_VERSION}'")
endfunction()
