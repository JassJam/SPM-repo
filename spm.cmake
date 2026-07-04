# ============================================================
# SPM - a tiny package manager for CMake
#
# packages/repositories/<l>/<n>/<version>/CMakeLists.txt
#        the RECIPE: how to fetch source and build it.
#        Never add_subdirectory()'d into your project. Run as
#        an isolated configure+build+install at setup time.
#
# packages/cache/<l>/<n>/<hash>/
#        the INSTALLED, PRECOMPILED result of running a recipe.
#        This is what becomes the CMake target you link against.
# ============================================================

cmake_minimum_required(VERSION 3.21)

if(DEFINED SPM_CMAKE_INCLUDED)
	return()
endif()
set(SPM_CMAKE_INCLUDED TRUE)

set(SPM_ROOT "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "Path to spm.cmake's directory")

set(SPM_REMOTE ON CACHE BOOL "Fetch missing recipes from a registry")
set(SPM_VERBOSE_OUTPUT OFF CACHE BOOL "Verbose SPM logging")

# The registry is ONE of:
#   - a local/mounted directory containing plain, already-unzipped recipe
# 		folders at "<registry>/<letter>/<n>/<version>/".
#   - "git+https://..." or "git+ssh://..." — a git repo containing plain,
#     already-unzipped recipe folders in the same layout. Fetched via a
#     PARTIAL, SPARSE clone (--filter=blob:none --sparse), so only the one
#     "<letter>/<n>/<version>/" subtree is actually downloaded — not the
#     whole repo or its history.
#   - a plain "http://" or "https://" base URL serving one tarball per
#     (name, version) at "<registry>/<letter>/<n>/<version>.tar.gz".
# Detected automatically from the string's shape; see _spm_resolve_recipe_dir.
#
# TODO: replace with your actual file server URL, git repo, or mounted path.
set(SPM_REGISTRY "git+https://codeberg.org/JassJam/SPM-repo.git" CACHE STRING
	"Default registry: local/mounted dir, git+https(s)/git+ssh repo, or http(s) tarball server")

# Optional default HTTP headers for the registry (e.g. an auth token),
# semicolon-separated "Key: Value" strings. NOTE: this is a CACHE variable
# and will be written to CMakeCache.txt in plain text — for secrets, prefer
# passing -DSPM_REGISTRY_HEADERS=... on the command line each run (not
# committed), or override per-package via spm_require_package(HEADERS ...).
if(NOT DEFINED SPM_REGISTRY_HEADERS AND DEFINED ENV{SPM_REGISTRY_HEADERS})
	set(_spm_default_headers "$ENV{SPM_REGISTRY_HEADERS}")
else()
	set(_spm_default_headers "")
endif()
set(SPM_REGISTRY_HEADERS "${_spm_default_headers}" CACHE STRING
	"Default HTTP headers sent with registry downloads, semicolon-separated 'Key: Value' entries")

set(SPM_PACKAGES_DIR "${CMAKE_BINARY_DIR}/spm/packages/repositories" CACHE PATH "Recipe root (source of truth)")
set(SPM_CACHE_DIRECTORY "${CMAKE_BINARY_DIR}/spm/packages/cache" CACHE PATH "Precompiled/installed binary cache")
set(SPM_DOWNLOADS_DIR "${CMAKE_BINARY_DIR}/_spm/_downloads" CACHE PATH "Download cache directory")
set(SPM_PARALLEL_JOBS "4" CACHE STRING "Parallel build jobs used when building a recipe")
set(SPM_SKIP_TESTS OFF CACHE BOOL "Skip recipe test phase even if RUN_TESTS was requested (warn instead of fail)")
set(SPM_FORCE_REBUILD OFF CACHE BOOL "Ignore all cache hits and rebuild every requested package from scratch")

find_program(CTEST_EXECUTABLE NAMES ctest)
find_program(GIT_EXECUTABLE NAMES git)

set(SPM_REGISTRY_REF "" CACHE STRING
	"Default branch/tag to check out for git+ registries (empty = repo's default branch)")

macro(_spm_log)
	if(SPM_VERBOSE_OUTPUT)
		message(STATUS "[SPM]: ${ARGV}.")
	endif()
endmacro()

macro(_spm_log_fatal)
	message(FATAL_ERROR "[SPM]: ${ARGV}.")
endmacro()

function(_spm_lowercase_first_char str out_var)
	string(SUBSTRING "${str}" 0 1 _first)
	string(TOLOWER "${_first}" _first)
	set(${out_var} "${_first}" PARENT_SCOPE)
endfunction()

define_property(GLOBAL PROPERTY SPM_REQUIRED_PACKAGES
	BRIEF_DOCS "name@version pairs already resolved by SPM"
	FULL_DOCS  "Used to dedupe and detect version conflicts across the tree")

# ------------------------------------------------------------
# Locate the RECIPE directory for name@version.
#   packages/repositories/<l>/<n>/<version>/CMakeLists.txt
# If missing locally and SPM_REMOTE is ON, resolve it from `registry`:
#   - local directory      used IN PLACE, never copied.
#   - git+https(s)/ssh     sparse partial clone of just that one
#                          subtree, moved into SPM_PACKAGES_DIR.
#   - http(s) URL          tarball downloaded + extracted into
#                          SPM_PACKAGES_DIR.
# Git and tarball modes both have to materialize something on
# disk (there's nothing to point at directly until fetched) —
# only local-directory mode can skip that step entirely.
# Either way, a version directory already existing under
# SPM_PACKAGES_DIR short-circuits everything below — no re-fetch,
# no re-clone, no re-copy, regardless of which mode produced it.
# ------------------------------------------------------------
function(_spm_resolve_recipe_dir name version registry ref headers out_dir)
	if(NOT version)
		_spm_log_fatal("VERSION is required to resolve a recipe for '${name}'")
	endif()

	_spm_lowercase_first_char("${name}" _letter)
	set(_local_repo_dir "${SPM_PACKAGES_DIR}/${_letter}/${name}/${version}")
	set(_path_in_repo "${_letter}/${name}/${version}")

	if(EXISTS "${_local_repo_dir}/CMakeLists.txt")
		_spm_log("Using recipe for '${name}@${version}' at ${_local_repo_dir}")
		set(${out_dir} "${_local_repo_dir}" PARENT_SCOPE)
		return()
	endif()

	if(IS_DIRECTORY "${registry}")
		# --- Local / mounted directory: use in place, no copy ---
		set(_src "${registry}/${_path_in_repo}")
		if(NOT EXISTS "${_src}/CMakeLists.txt")
			_spm_log_fatal(
				"No recipe for '${name}@${version}' found under local registry '${registry}' (expected ${_src})")
		endif()
		_spm_log("Using recipe for '${name}@${version}' directly from local registry ${_src}")
		set(${out_dir} "${_src}" PARENT_SCOPE)
		return()

	elseif(registry MATCHES "^git\\+(.+)$")
		# --- Git registry: partial + sparse clone of ONE subtree ---
		if(NOT GIT_EXECUTABLE)
			_spm_log_fatal("Registry '${registry}' needs git, but no git executable was found")
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

		_spm_log("Sparse-cloning '${_path_in_repo}' from ${_git_url}")
		execute_process(
			COMMAND ${GIT_EXECUTABLE} ${_git_config_args} clone ${_clone_args} "${_git_url}" "${_scratch_dir}"
			RESULT_VARIABLE _git_result
			OUTPUT_VARIABLE _git_output
			ERROR_VARIABLE  _git_output
		)
		if(NOT _git_result EQUAL 0)
			_spm_log_fatal("git clone failed for registry '${registry}':\n${_git_output}")
		endif()

		execute_process(
			COMMAND ${GIT_EXECUTABLE} sparse-checkout set "${_path_in_repo}"
			WORKING_DIRECTORY "${_scratch_dir}"
			RESULT_VARIABLE _sparse_result
			OUTPUT_VARIABLE _sparse_output
			ERROR_VARIABLE  _sparse_output
		)
		if(NOT _sparse_result EQUAL 0)
			file(REMOVE_RECURSE "${_scratch_dir}")
			_spm_log_fatal("git sparse-checkout failed for '${name}@${version}':\n${_sparse_output}")
		endif()

		set(_fetched_dir "${_scratch_dir}/${_path_in_repo}")
		if(NOT EXISTS "${_fetched_dir}/CMakeLists.txt")
			file(REMOVE_RECURSE "${_scratch_dir}")
			_spm_log_fatal(
				"No recipe for '${name}@${version}' found in git registry '${registry}' (expected ${_path_in_repo})")
		endif()

		get_filename_component(_local_repo_parent "${_local_repo_dir}" DIRECTORY)
		file(MAKE_DIRECTORY "${_local_repo_parent}")
		file(RENAME "${_fetched_dir}" "${_local_repo_dir}")
		file(REMOVE_RECURSE "${_scratch_dir}")   # drop .git + anything else left over
		set(${out_dir} "${_local_repo_dir}" PARENT_SCOPE)
		return()

	elseif(registry MATCHES "^https?://")
		# --- Remote registry: one tarball per (name, version), must be
		#     materialized on disk somewhere before it can be used ---
		set(_tarball_url "${registry}/${_path_in_repo}.tar.gz")
		set(_tarball_dest "${SPM_DOWNLOADS_DIR}/${name}-${version}.tar.gz")
		file(MAKE_DIRECTORY "${SPM_DOWNLOADS_DIR}")

		set(_header_args "")
		foreach(_h ${headers})
			list(APPEND _header_args HTTPHEADER "${_h}")
		endforeach()

		_spm_log("Fetching '${name}@${version}' from ${_tarball_url}")
		file(DOWNLOAD "${_tarball_url}" "${_tarball_dest}"
			STATUS _dl_status
			TLS_VERIFY ON
			${_header_args}
		)
		list(GET _dl_status 0 _dl_code)
		if(NOT _dl_code EQUAL 0)
			list(GET _dl_status 1 _dl_message)
			file(REMOVE "${_tarball_dest}")
			_spm_log_fatal(
				"Failed to fetch '${name}@${version}' from ${_tarball_url}: ${_dl_message}")
		endif()

		file(MAKE_DIRECTORY "${_local_repo_dir}")
		file(ARCHIVE_EXTRACT INPUT "${_tarball_dest}" DESTINATION "${_local_repo_dir}")
		file(REMOVE "${_tarball_dest}")
		if(NOT EXISTS "${_local_repo_dir}/CMakeLists.txt")
			file(REMOVE_RECURSE "${_local_repo_dir}")
			_spm_log_fatal("Archive for '${name}@${version}' had no CMakeLists.txt at its root")
		endif()
		set(${out_dir} "${_local_repo_dir}" PARENT_SCOPE)
	else()
		_spm_log_fatal(
			"SPM_REGISTRY '${registry}' is not a local directory, a git+https(s)/ssh URL, or an http(s) URL")
	endif()
endfunction()

function(_spm_list_local_versions name out_var)
	_spm_lowercase_first_char("${name}" _letter)
	set(_pkg_dir "${SPM_PACKAGES_DIR}/${_letter}/${name}")
	set(_versions "")
	if(EXISTS "${_pkg_dir}")
		file(GLOB _entries RELATIVE "${_pkg_dir}" "${_pkg_dir}/*")
		foreach(_entry ${_entries})
			if(IS_DIRECTORY "${_pkg_dir}/${_entry}" AND EXISTS "${_pkg_dir}/${_entry}/CMakeLists.txt")
				list(APPEND _versions ${_entry})
			endif()
		endforeach()
	endif()
	set(${out_var} "${_versions}" PARENT_SCOPE)
endfunction()

# ------------------------------------------------------------
# Hash identifying one specific BUILD of a recipe: the pin
# (version/git ref/url+hash/config overrides) AND the toolchain
# (compiler/build type), so the cache busts automatically if
# either the pin or the toolchain changes.
# ------------------------------------------------------------
function(_spm_get_build_hash name version git_url git_tag url url_hash configs build_type build_shared out_hash)
	string(SHA256 _hash
		"${name}-${version}-${git_url}-${git_tag}-${url}-${url_hash}-${configs}-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}-${build_type}-${build_shared}-${CMAKE_GENERATOR}")
	string(SUBSTRING "${_hash}" 0 16 _hash)
	set(${out_hash} "${_hash}" PARENT_SCOPE)
endfunction()

# ------------------------------------------------------------
# Build+install a recipe as an ISOLATED, out-of-tree CMake
# project (its own configure/build/install), cache the result
# under packages/cache/<l>/<n>/<hash>/, and expose it as an
# IMPORTED target. Never add_subdirectory()'d into the caller's
# build graph.
# ------------------------------------------------------------
function(_spm_build_and_import name version recipe_dir)
	set(options RUN_TESTS FORCE SHARED)
	set(oneValArgs GIT_URL GIT_TAG URL HASH IMPORT_NAME)
	set(multiValArgs PATCHES CONFIGS)
	cmake_parse_arguments(B "${options}" "${oneValArgs}" "${multiValArgs}" ${ARGN})

	if(B_IMPORT_NAME)
		set(_import_name "${B_IMPORT_NAME}")
	else()
		set(_import_name "${name}")
	endif()

	_spm_lowercase_first_char("${name}" _letter)

	# Recipes are always built standalone, so they need a concrete config
	# even if the top-level project never set CMAKE_BUILD_TYPE (common with
	# single-config generators before the first build). Resolve this BEFORE
	# hashing so the cache key reflects what actually gets built.
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

	_spm_get_build_hash("${name}" "${version}" "${B_GIT_URL}" "${B_GIT_TAG}"
		"${B_URL}" "${B_HASH}" "${B_CONFIGS}" "${_pkg_build_type}" "${_pkg_build_shared}" _hash)

	set(_cache_dir  "${SPM_CACHE_DIRECTORY}/${_letter}/${name}/${_hash}")
	set(_build_dir  "${CMAKE_BINARY_DIR}/_spm/${name}-${version}-${_hash}")
	set(_stamp_file "${_cache_dir}/.spm-installed")

	if(B_RUN_TESTS)
		set(_pkg_build_testing "ON")
	else()
		set(_pkg_build_testing "OFF")
	endif()

	if(EXISTS "${_stamp_file}" AND NOT B_FORCE AND NOT SPM_FORCE_REBUILD)
		_spm_log("'${name}@${version}' already built (${_hash}), reusing ${_cache_dir}")
	else()
		if(EXISTS "${_cache_dir}")
			_spm_log("Forcing rebuild of '${name}@${version}' (${_hash}), clearing stale cache")
			file(REMOVE_RECURSE "${_cache_dir}")
		endif()
		if(EXISTS "${_build_dir}")
			file(REMOVE_RECURSE "${_build_dir}")
		endif()
		file(MAKE_DIRECTORY "${_build_dir}")

		# Feed the recipe its inputs via an initial-cache script (-C),
		# since the recipe is configured as its own isolated project
		# and can't see this function's local variables directly.
		set(_input_script "${_build_dir}/spm-input.cmake")
		file(WRITE "${_input_script}" "\
set(SPM_ROOT [==[${SPM_ROOT}]==] CACHE INTERNAL \"\")
set(SPM_PKG_NAME [==[${name}]==] CACHE INTERNAL \"\")
set(SPM_PKG_VERSION [==[${version}]==] CACHE INTERNAL \"\")
set(SPM_PKG_GIT_URL [==[${B_GIT_URL}]==] CACHE INTERNAL \"\")
set(SPM_PKG_GIT_TAG [==[${B_GIT_TAG}]==] CACHE INTERNAL \"\")
set(SPM_PKG_URL [==[${B_URL}]==] CACHE INTERNAL \"\")
set(SPM_PKG_HASH [==[${B_HASH}]==] CACHE INTERNAL \"\")
set(SPM_PKG_PATCHES [==[${B_PATCHES}]==] CACHE INTERNAL \"\")
")
		foreach(_cfg ${B_CONFIGS})
			file(APPEND "${_input_script}" "set(${_cfg} CACHE INTERNAL \"\" FORCE)\n")
		endforeach()

		_spm_log("Configuring '${name}@${version}' (${_hash})")
		set(_toolchain_args "")
		if(CMAKE_TOOLCHAIN_FILE)
			list(APPEND _toolchain_args -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
		else()
			list(APPEND _toolchain_args
				-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
				-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
			)
		endif()
		foreach(_var
			CMAKE_SYSTEM_NAME CMAKE_SYSTEM_PROCESSOR
			CMAKE_OSX_SYSROOT CMAKE_OSX_ARCHITECTURES CMAKE_OSX_DEPLOYMENT_TARGET
			ANDROID_ABI ANDROID_PLATFORM ANDROID_NDK ANDROID_STL
			CMAKE_FIND_ROOT_PATH_MODE_PROGRAM CMAKE_FIND_ROOT_PATH_MODE_LIBRARY
			CMAKE_FIND_ROOT_PATH_MODE_INCLUDE CMAKE_FIND_ROOT_PATH_MODE_PACKAGE
			CMAKE_CXX_STANDARD CMAKE_CXX_STANDARD_REQUIRED CMAKE_CXX_EXTENSIONS
			CMAKE_C_STANDARD CMAKE_C_STANDARD_REQUIRED
		)
			if(DEFINED ${_var})
				list(APPEND _toolchain_args -D${_var}=${${_var}})
			endif()
		endforeach()

		execute_process(
			COMMAND ${CMAKE_COMMAND}
					-S "${recipe_dir}" -B "${_build_dir}"
					-G "${CMAKE_GENERATOR}"
					-C "${_input_script}"
					-DCMAKE_INSTALL_PREFIX=${_cache_dir}
					-DCMAKE_BUILD_TYPE=${_pkg_build_type}
					${_toolchain_args}
					-DBUILD_SHARED_LIBS=${_pkg_build_shared}
					-DBUILD_TESTING=${_pkg_build_testing}
					-DCMAKE_POSITION_INDEPENDENT_CODE=ON
			RESULT_VARIABLE _cfg_result
			OUTPUT_VARIABLE _cfg_output
			ERROR_VARIABLE  _cfg_output
		)
		if(NOT _cfg_result EQUAL 0)
			_spm_log_fatal("Configure failed for '${name}@${version}':\n${_cfg_output}")
		endif()

		_spm_log("Building '${name}@${version}'")
		execute_process(
			COMMAND ${CMAKE_COMMAND} --build "${_build_dir}"
					--config ${_pkg_build_type} --parallel ${SPM_PARALLEL_JOBS}
			RESULT_VARIABLE _build_result
			OUTPUT_VARIABLE _build_output
			ERROR_VARIABLE  _build_output
		)
		if(NOT _build_result EQUAL 0)
			_spm_log_fatal("Build failed for '${name}@${version}':\n${_build_output}")
		endif()

		if(B_RUN_TESTS)
			if(SPM_SKIP_TESTS)
				_spm_log("RUN_TESTS requested for '${name}@${version}' but SPM_SKIP_TESTS is ON, skipping")
			elseif(NOT CTEST_EXECUTABLE)
				_spm_log_fatal(
					"RUN_TESTS requested for '${name}@${version}' but no ctest executable was found")
			else()
				_spm_log("Running test suite for '${name}@${version}'")
				execute_process(
					COMMAND ${CTEST_EXECUTABLE}
							--test-dir "${_build_dir}"
							-C ${_pkg_build_type}
							--output-on-failure
					RESULT_VARIABLE _test_result
					OUTPUT_VARIABLE _test_output
					ERROR_VARIABLE  _test_output
				)
				if(NOT _test_result EQUAL 0)
					_spm_log_fatal(
						"Test phase failed for '${name}@${version}' — refusing to cache a "
						"build that didn't pass its own tests:\n${_test_output}")
				endif()
				_spm_log("Tests passed for '${name}@${version}'")
			endif()
		endif()

		_spm_log("Installing '${name}@${version}' - ${_cache_dir}")
		execute_process(
			COMMAND ${CMAKE_COMMAND} --install "${_build_dir}" --config ${_pkg_build_type}
			RESULT_VARIABLE _install_result
			OUTPUT_VARIABLE _install_output
			ERROR_VARIABLE  _install_output
		)
		if(NOT _install_result EQUAL 0)
			_spm_log_fatal("Install failed for '${name}@${version}':\n${_install_output}")
		endif()

		file(GLOB_RECURSE _installed_files "${_cache_dir}/*")
		if(NOT _installed_files)
			_spm_log_fatal(
				"Recipe for '${name}@${version}' configured and built successfully but "
				"installed nothing into ${_cache_dir}. Check that the recipe enables the "
				"upstream project's INSTALL option (many libraries skip install() rules "
				"when consumed via add_subdirectory() unless explicitly told to install).")
		endif()

		file(WRITE "${_stamp_file}" "ok")
	endif()

	# --- Expose the cached, precompiled result as a CMake target -----------

	find_package(${_import_name} QUIET CONFIG PATHS "${_cache_dir}" NO_DEFAULT_PATH)
	if(${_import_name}_FOUND)
		_spm_log("'${_import_name}' provides a CMake package config, imported via find_package()")
		# Multi-component packages (Abseil, Boost, ICU, ...) expose many
		# targets (absl::strings, absl::time, ...) with no single unified
		# one — a successful find_package() IS the success signal here,
		# there's nothing more generic to verify beyond this.
		return()
	endif()

	find_library(_spm_${_import_name}_LIB
		NAMES ${_import_name} lib${_import_name}
		PATHS "${_cache_dir}/lib" "${_cache_dir}/lib64"
		NO_DEFAULT_PATH
	)
	if(NOT _spm_${_import_name}_LIB)
		_spm_log_fatal(
			"Could not locate a compiled library for '${_import_name}' under ${_cache_dir}. "
			"If this package's real CMake package/target name differs from its recipe name "
			"(e.g. the 'abseil' recipe installs as CMake package 'absl'), pass "
			"IMPORT_NAME to spm_require_package() to point at the real name. If the package "
			"exposes multiple component targets with no single unified library, this generic "
			"single-library fallback doesn't apply — the recipe needs a proper installed "
			"CMake package config instead.")
	endif()

	if(_pkg_build_shared STREQUAL "ON")
		set(_imported_kind SHARED)
	else()
		set(_imported_kind STATIC)
	endif()

	if(NOT TARGET ${_import_name})
		add_library(${_import_name} ${_imported_kind} IMPORTED GLOBAL)
		set_target_properties(${_import_name} PROPERTIES
			IMPORTED_LOCATION "${_spm_${_import_name}_LIB}"
			INTERFACE_INCLUDE_DIRECTORIES "${_cache_dir}/include"
		)
		_spm_log("Registered ${_imported_kind} IMPORTED target '${_import_name}' -> ${_spm_${_import_name}_LIB}")
	endif()
endfunction()

function(spm_clean_cache)
	if(EXISTS "${SPM_CACHE_DIRECTORY}")
		_spm_log("Removing entire SPM binary cache at ${SPM_CACHE_DIRECTORY}")
		file(REMOVE_RECURSE "${SPM_CACHE_DIRECTORY}")
	endif()
endfunction()

# ------------------------------------------------------------
# Public entry point.
#
# spm_require_package(
#   NAME       spdlog
#   VERSION    1.14.1
#
#   GIT_URL    <override recipe's default>
#   GIT_TAG    <override recipe's default>
#   URL        <override recipe's default>
#   HASH       <override recipe's default>
#
#   DIRECTORY  <use an explicit local recipe dir instead of
#               resolving via SPM_PACKAGES_DIR/SPM_REGISTRY>
#
#   REGISTRY   <override SPM_REGISTRY for this package only —
#               a local/mounted directory, a "git+https(s)/ssh" repo
#               (sparse partial clone), or an http(s) tarball server>
#   REGISTRY_REF <branch/tag for a git+ registry override, if not
#                the repo's default branch>
#   HEADERS    "Authorization: Bearer xyz" "X-Custom: value"
#              (override SPM_REGISTRY_HEADERS for this package only;
#               used for http(s) tarball downloads and git+ clones,
#               ignored in local-directory registry mode)
#
#   PATCHES    a.patch b.patch
#   CONFIGS    "SOME_OPTION=ON" "OTHER_OPTION=OFF"
#
#   RUN_TESTS  # run the recipe's own ctest suite before caching
#   FORCE      # ignore any existing cache entry, rebuild
#   SHARED     # build a shared library instead of static (default)
#   IMPORT_NAME <real CMake package/target name>
#              # use when a package's actual CMake package name (what
#              # find_package() looks for) differs from the recipe's
#              # own identity/folder name — e.g. NAME abseil installs
#              # as CMake package "absl", so pass IMPORT_NAME absl.
#              # Defaults to NAME if not given.
# )
# ------------------------------------------------------------
function(spm_require_package)
	set(options RUN_TESTS FORCE SHARED)
	set(oneValArgs NAME VERSION DIRECTORY REGISTRY REGISTRY_REF GIT_URL GIT_TAG URL HASH IMPORT_NAME)
	set(multiValArgs PATCHES CONFIGS HEADERS)
	cmake_parse_arguments(ARG "${options}" "${oneValArgs}" "${multiValArgs}" ${ARGN})

	if(NOT ARG_NAME)
		_spm_log_fatal("NAME argument is required")
	endif()
	if(NOT ARG_VERSION AND NOT ARG_DIRECTORY)
		_spm_log_fatal("VERSION argument is required (or pass DIRECTORY explicitly)")
	endif()

	get_property(_required GLOBAL PROPERTY SPM_REQUIRED_PACKAGES)
	foreach(_entry ${_required})
		if(_entry MATCHES "^${ARG_NAME}@(.*)$")
			if(NOT "${CMAKE_MATCH_1}" STREQUAL "${ARG_VERSION}")
				_spm_log_fatal(
					"Version conflict for '${ARG_NAME}': already required at "
					"'${CMAKE_MATCH_1}', now requested at '${ARG_VERSION}'")
			endif()
			_spm_log("'${ARG_NAME}@${ARG_VERSION}' already resolved, skipping")
			return()
		endif()
	endforeach()
	set_property(GLOBAL APPEND PROPERTY SPM_REQUIRED_PACKAGES "${ARG_NAME}@${ARG_VERSION}")

	if(ARG_DIRECTORY)
		set(_recipe_dir "${ARG_DIRECTORY}")
		if(NOT EXISTS "${_recipe_dir}/CMakeLists.txt")
			_spm_log_fatal("'${_recipe_dir}' does not contain a CMakeLists.txt")
		endif()
	else()
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
		_spm_resolve_recipe_dir("${ARG_NAME}" "${ARG_VERSION}" "${_effective_registry}" "${_effective_ref}" "${_effective_headers}" _recipe_dir)
	endif()

	_spm_log("Building & importing '${ARG_NAME}@${ARG_VERSION}' from ${_recipe_dir}")

	if(NOT ARG_IMPORT_NAME AND EXISTS "${_recipe_dir}/IMPORT_NAME")
		file(STRINGS "${_recipe_dir}/IMPORT_NAME" _import_name_from_file LIMIT_COUNT 1)
		string(STRIP "${_import_name_from_file}" _import_name_from_file)
		if(_import_name_from_file)
			_spm_log("Recipe declares IMPORT_NAME '${_import_name_from_file}' via IMPORT_NAME file")
			set(ARG_IMPORT_NAME "${_import_name_from_file}")
		endif()
	endif()

	set(_run_tests_flag "")
	if(ARG_RUN_TESTS)
		set(_run_tests_flag "RUN_TESTS")
	endif()
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

	_spm_build_and_import("${ARG_NAME}" "${ARG_VERSION}" "${_recipe_dir}"
		GIT_URL     "${ARG_GIT_URL}"
		GIT_TAG     "${ARG_GIT_TAG}"
		URL         "${ARG_URL}"
		HASH        "${ARG_HASH}"
		IMPORT_NAME "${_effective_import_name}"
		PATCHES  ${ARG_PATCHES}
		CONFIGS  ${ARG_CONFIGS}
		${_run_tests_flag}
		${_force_flag}
		${_shared_flag}
	)

	if(NOT TARGET ${_effective_import_name} AND NOT TARGET ${_effective_import_name}::${_effective_import_name})
		_spm_log(
			"Note: no target named '${_effective_import_name}' or "
			"'${_effective_import_name}::${_effective_import_name}' exists after building "
			"'${ARG_NAME}@${ARG_VERSION}'. If this package exposes multiple component "
			"targets, link against those directly. If it doesn't, and this is unexpected, "
			"check IMPORT_NAME matches the package's real CMake package/target name")
	endif()
endfunction()

# ------------------------------------------------------------
# Called FROM A RECIPE (running as its own isolated project) to
# fetch upstream source: either GIT_URL/GIT_TAG (git clone), or
# URL/HASH (download + hash validated). Caller overrides passed
# down from spm_require_package() (SPM_PKG_*) win over the
# recipe's own defaults given here.
# ------------------------------------------------------------
function(spm_fetch_source)
	set(oneValArgs GIT_URL GIT_TAG URL HASH)
	cmake_parse_arguments(DEF "" "${oneValArgs}" "" ${ARGN})

	if(SPM_PKG_GIT_URL)
		set(_git_url ${SPM_PKG_GIT_URL})
	else()
		set(_git_url ${DEF_GIT_URL})
	endif()
	if(SPM_PKG_GIT_TAG)
		set(_git_tag ${SPM_PKG_GIT_TAG})
	else()
		set(_git_tag ${DEF_GIT_TAG})
	endif()
	if(SPM_PKG_URL)
		set(_url ${SPM_PKG_URL})
	else()
		set(_url ${DEF_URL})
	endif()
	if(SPM_PKG_HASH)
		set(_hash ${SPM_PKG_HASH})
	else()
		set(_hash ${DEF_HASH})
	endif()

	include(FetchContent)
	if(_git_url)
		FetchContent_Declare(${SPM_PKG_NAME}
			GIT_REPOSITORY ${_git_url}
			GIT_TAG        ${_git_tag}
			GIT_SHALLOW    FALSE
		)
	elseif(_url)
		if(NOT _hash)
			_spm_log_fatal("URL source for '${SPM_PKG_NAME}' requires a HASH for validation")
		endif()
		FetchContent_Declare(${SPM_PKG_NAME}
			URL      ${_url}
			URL_HASH ${_hash}
		)
	else()
		_spm_log_fatal("spm_fetch_source() needs GIT_URL or URL for '${SPM_PKG_NAME}'")
	endif()

	FetchContent_GetProperties(${SPM_PKG_NAME})
	if(NOT ${SPM_PKG_NAME}_POPULATED)
		FetchContent_Populate(${SPM_PKG_NAME})
	endif()

	foreach(_patch ${SPM_PKG_PATCHES})
		if(NOT GIT_EXECUTABLE)
			_spm_log_fatal("Recipe '${SPM_PKG_NAME}' needs a patch applied, but no git executable was found")
		endif()
		_spm_log("Applying patch '${_patch}' to '${SPM_PKG_NAME}'")
		execute_process(
			COMMAND ${GIT_EXECUTABLE} apply --whitespace=fix "${_patch}"
			WORKING_DIRECTORY "${${SPM_PKG_NAME}_SOURCE_DIR}"
			RESULT_VARIABLE _patch_result
			OUTPUT_VARIABLE _patch_output
			ERROR_VARIABLE  _patch_output
		)
		if(NOT _patch_result EQUAL 0)
			_spm_log_fatal("Failed to apply patch '${_patch}' to '${SPM_PKG_NAME}':\n${_patch_output}")
		endif()
	endforeach()

	set(SPM_PKG_SOURCE_DIR "${${SPM_PKG_NAME}_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

#
# spm_run_external_build(
#   [SOURCE_DIR <dir>]              # default: SPM_PKG_SOURCE_DIR
#   [CONFIGURE_COMMAND <cmd...>]
#   BUILD_COMMAND <cmd...>
#   [INSTALL_COMMAND <cmd...>]
#   [BUILD_IN_SOURCE
# )
function(spm_run_external_build)
	set(options BUILD_IN_SOURCE)
	set(multiValArgs CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND)
	set(oneValArgs SOURCE_DIR)
	cmake_parse_arguments(X "${options}" "${oneValArgs}" "${multiValArgs}" ${ARGN})

	if(NOT X_SOURCE_DIR)
		if(NOT SPM_PKG_SOURCE_DIR)
			_spm_log_fatal("spm_run_external_build() needs SOURCE_DIR (call spm_fetch_source() first, or pass it explicitly)")
		endif()
		set(X_SOURCE_DIR "${SPM_PKG_SOURCE_DIR}")
	endif()
	if(NOT X_BUILD_COMMAND)
		_spm_log_fatal("spm_run_external_build() requires BUILD_COMMAND")
	endif()

	include(ExternalProject)

	set(_ep_args
		SOURCE_DIR      "${X_SOURCE_DIR}"
		BUILD_COMMAND   ${X_BUILD_COMMAND}
		INSTALL_DIR     "${CMAKE_INSTALL_PREFIX}"
		PREFIX          "${CMAKE_CURRENT_BINARY_DIR}/ep"
	)
	if(X_CONFIGURE_COMMAND)
		list(APPEND _ep_args CONFIGURE_COMMAND ${X_CONFIGURE_COMMAND})
	else()
		list(APPEND _ep_args CONFIGURE_COMMAND "")
	endif()
	if(X_INSTALL_COMMAND)
		list(APPEND _ep_args INSTALL_COMMAND ${X_INSTALL_COMMAND})
	else()
		list(APPEND _ep_args INSTALL_COMMAND "")
	endif()
	if(X_BUILD_IN_SOURCE)
		list(APPEND _ep_args BUILD_IN_SOURCE TRUE)
	endif()

	ExternalProject_Add(${SPM_PKG_NAME}_external ${_ep_args})

	if(NOT TARGET spm_external_default)
		add_custom_target(spm_external_default ALL)
	endif()
	add_dependencies(spm_external_default ${SPM_PKG_NAME}_external)
endfunction()
