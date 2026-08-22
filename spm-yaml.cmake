include_guard(GLOBAL)

include(${CMAKE_CURRENT_LIST_DIR}/spm.cmake)

# spm-yaml.cmake
#
# packages:
#   - name: boost
#     version: 1.92.0
#     import_name: boost
#     registry: ./registry
#     git_url: https://github.com/boostorg/boost.git
#     git_tag: boost-1.92.0
#     options:
#       - BOOST_ENABLE_MPI=OFF
#       - BOOST_ENABLE_PYTHON=OFF
#     force: true
#     shared: false
#
# is equivalent to:
#
# spm_require_package(
#     NAME boost
#     VERSION 1.92.0
#     IMPORT_NAME boost
#     REGISTRY ./registry
#     GIT_URL https://github.com/boostorg/boost.git
#     GIT_TAG boost-1.92.0
#     OPTIONS BOOST_ENABLE_MPI=OFF BOOST_ENABLE_PYTHON=OFF
#     FORCE
#     SHARED
# )
function(_spm_yaml_strip_quotes str out_var)
    string(REGEX REPLACE "^[ \t]*[\"']|[\"'][ \t]*$" "" _stripped "${str}")
    string(STRIP "${_stripped}" _stripped)
    set(${out_var} "${_stripped}" PARENT_SCOPE)
endfunction()

macro(_spm_yaml_apply_scalar_kv _kv_key _kv_val)
    _spm_yaml_strip_quotes("${_kv_val}" _kv_val_clean)
    string(TOLOWER "${_kv_key}" _kv_key_lower)

    if(_kv_key_lower STREQUAL "force")
        if(_kv_val_clean MATCHES "^(true|yes|on|1)$")
            list(APPEND _item_args FORCE)
        endif()
    elseif(_kv_key_lower STREQUAL "shared")
        if(_kv_val_clean MATCHES "^(true|yes|on|1)$")
            list(APPEND _item_args SHARED)
        endif()
    else()
        string(TOUPPER "${_kv_key}" _kv_key_upper)
        list(APPEND _item_args ${_kv_key_upper} "${_kv_val_clean}")
    endif()
endmacro()

function(_spm_yaml_dispatch_package)
    set(_args "${ARGN}")
    set(_flat "")
    set(_options "")
    set(_have_options FALSE)

    list(LENGTH _args _n)
    set(_i 0)
    while(_i LESS _n)
        list(GET _args ${_i} _tok)
        if(_tok STREQUAL "OPTIONS")
            math(EXPR _i "${_i} + 1")
            list(GET _args ${_i} _opt_val)
            list(APPEND _options "${_opt_val}")
            set(_have_options TRUE)
        else()
            list(APPEND _flat "${_tok}")
        endif()
        math(EXPR _i "${_i} + 1")
    endwhile()

    if(_have_options)
        list(APPEND _flat OPTIONS ${_options})
    endif()

    spm_log("Loading package from YAML: ${_flat}")
    spm_require_package(${_flat})
endfunction()

# spm_require_packages_from_yaml(
#   FILE <path/to/packages.yaml>
# )
function(spm_require_packages_from_yaml)
    set(oneValArgs FILE)
    cmake_parse_arguments(Y "" "${oneValArgs}" "" ${ARGN})

    if(NOT Y_FILE)
        spm_log_fatal("spm_require_packages_from_yaml() requires FILE")
    endif()
    if(NOT EXISTS "${Y_FILE}")
        spm_log_fatal("spm_require_packages_from_yaml(): '${Y_FILE}' does not exist")
    endif()

    file(STRINGS "${Y_FILE}" _lines ENCODING UTF-8)

    set(_item_args "")
    set(_have_item FALSE)
    set(_item_indent -1)
    set(_pending_list_key "")

    foreach(_line IN LISTS _lines)
        if(_line MATCHES "^[ \t]*#" OR _line MATCHES "^[ \t]*$")
            continue()
        endif()

        # --- dash + "key: value", starts a new item (or is malformed) --
        if(_line MATCHES "^( *)- +([A-Za-z_][A-Za-z0-9_]*):( +(.+))?$")
            string(LENGTH "${CMAKE_MATCH_1}" _indent)
            set(_key "${CMAKE_MATCH_2}")
            set(_val "${CMAKE_MATCH_4}")

            if(_have_item AND _indent GREATER _item_indent)
                spm_log_fatal("spm_require_packages_from_yaml(): nested list-of-maps is not supported (line: '${_line}')")
            endif()

            # new item: flush the previous one
            if(_have_item)
                _spm_yaml_dispatch_package(${_item_args})
            endif()
            set(_item_args "")
            set(_have_item TRUE)
            set(_item_indent ${_indent})
            set(_pending_list_key "")

            if(_val STREQUAL "")
                string(TOUPPER "${_key}" _pending_list_key)
            else()
                _spm_yaml_apply_scalar_kv("${_key}" "${_val}")
            endif()

        # --- dash + bare value, entry in the currently open array ------
        elseif(_line MATCHES "^( *)- +(.+)$")
            string(LENGTH "${CMAKE_MATCH_1}" _indent)
            set(_val "${CMAKE_MATCH_2}")

            if(NOT _pending_list_key)
                spm_log_fatal("spm_require_packages_from_yaml(): '- ${_val}' found with no open array key above it")
            endif()
            if(NOT _have_item OR _indent LESS_EQUAL _item_indent)
                spm_log_fatal("spm_require_packages_from_yaml(): array entry '- ${_val}' is not indented deeper than its item")
            endif()

            _spm_yaml_strip_quotes("${_val}" _val)
            list(APPEND _item_args ${_pending_list_key} "${_val}")

        # --- plain "key: value" or "key:", scalar, or opens an array --
        elseif(_line MATCHES "^( *)([A-Za-z_][A-Za-z0-9_]*):( +(.+))?$")
            set(_key "${CMAKE_MATCH_2}")
            set(_val "${CMAKE_MATCH_4}")

            if(_key STREQUAL "packages")
                continue()   # top-level wrapper key, nothing to record
            endif()
            if(NOT _have_item)
                spm_log_fatal("spm_require_packages_from_yaml(): key '${_key}' found before any '- name: ...' entry")
            endif()

            set(_pending_list_key "")

            if(_val STREQUAL "")
                string(TOUPPER "${_key}" _pending_list_key)
            else()
                _spm_yaml_apply_scalar_kv("${_key}" "${_val}")
            endif()
        endif()
    endforeach()

    if(_have_item)
        _spm_yaml_dispatch_package(${_item_args})
    endif()
endfunction()
