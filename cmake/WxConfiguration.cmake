# Select wxWidgets, probe its capabilities and record its native dependency identity.

include_guard(GLOBAL)

if(WIN32)
    include("${CMAKE_CURRENT_LIST_DIR}/WxWindows.cmake")
    return()
endif()

include(CheckCXXSourceCompiles)
include(CheckCXXCompilerFlag)
include(CMakePushCheckState)

set(OTP_WX_CONFIG "" CACHE FILEPATH "Explicit installed wx-config executable")

if(NOT IS_ABSOLUTE "${OTP_WX_CONFIG}"
    OR NOT EXISTS "${OTP_WX_CONFIG}"
    OR IS_DIRECTORY "${OTP_WX_CONFIG}"
)
    message(FATAL_ERROR "Set OTP_WX_CONFIG to an explicit absolute installed wx-config executable")
endif()

file(REAL_PATH "${OTP_WX_CONFIG}" _wx_config_real)
file(STRINGS "${PROJECT_SOURCE_DIR}/UPSTREAM_COMMIT" _wx_upstream LIMIT_COUNT 1)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${OTP_WX_CONFIG}"
    "${_wx_config_real}"
)

function(_otp_wx_query output)
    execute_process(
        COMMAND "${OTP_WX_CONFIG}" ${ARGN}
        RESULT_VARIABLE _result
        OUTPUT_VARIABLE _output
        ERROR_VARIABLE _error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )

    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "wx-config ${ARGN} failed (${_result}): ${_error}")
    endif()

    set(${output} "${_output}" PARENT_SCOPE)
endfunction()

# Preserve each framework as a single CMake library item. Passing the two
# wx-config tokens separately would turn its name into an erroneous -l flag.
function(_otp_wx_link_items output raw)
    separate_arguments(_items UNIX_COMMAND "${raw}")
    set(_libraries)
    set(_framework FALSE)

    foreach(_item IN LISTS _items)
        if(_framework)
            unset(_framework_path CACHE)
            find_library(_framework_path NAMES "${_item}" REQUIRED)
            list(APPEND _libraries "${_framework_path}")
            set(_framework FALSE)
        elseif(_item STREQUAL "-framework")
            set(_framework TRUE)
        else()
            list(APPEND _libraries "${_item}")
        endif()
    endforeach()

    if(_framework)
        message(FATAL_ERROR "Incomplete framework option from selected wx-config")
    endif()

    set(${output} "${_libraries}" PARENT_SCOPE)
endfunction()

function(_otp_wx_json_string output value)
    string(REPLACE "\\" "\\\\" _value "${value}")
    string(REPLACE "\"" "\\\"" _value "${_value}")
    string(REPLACE "\n" "\\n" _value "${_value}")
    string(REPLACE "\r" "\\r" _value "${_value}")
    string(REPLACE "\t" "\\t" _value "${_value}")
    set(${output} "\"${_value}\"" PARENT_SCOPE)
endfunction()

macro(_otp_wx_json_set object key value)
    _otp_wx_json_string(_wx_quoted "${value}")
    string(JSON ${object} SET "${${object}}" "${key}" "${_wx_quoted}")
endmacro()

_otp_wx_query(OTP_WX_VERSION_FULL --version-full)

if(OTP_WX_VERSION_FULL VERSION_LESS 3.0.2)
    message(FATAL_ERROR
        "wxWidgets ${OTP_WX_VERSION_FULL} is older than the pinned 3.0.2 requirement"
    )
endif()

_otp_wx_query(_wx_prefix --prefix)

# Match the original Debug selection, falling back to standard libraries when
# debug libraries are unavailable. A debug-only installation forces native Debug.
execute_process(
    COMMAND "${OTP_WX_CONFIG}" --unicode --debug=no --version
    RESULT_VARIABLE _wx_release_result
    OUTPUT_QUIET
    ERROR_QUIET
)
execute_process(
    COMMAND "${OTP_WX_CONFIG}" --unicode --debug=yes --version
    RESULT_VARIABLE _wx_debug_result
    OUTPUT_QUIET
    ERROR_QUIET
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND _wx_debug_result EQUAL 0)
    set(_wx_variant --unicode --debug=yes)
    set(OTP_WX_FORCED_DEBUG FALSE)
    set(OTP_WX_SELECTED_DEBUG TRUE)
elseif(_wx_release_result EQUAL 0)
    set(_wx_variant --unicode --debug=no)
    set(OTP_WX_FORCED_DEBUG FALSE)
    set(OTP_WX_SELECTED_DEBUG FALSE)
else()
    _otp_wx_query(_wx_debug_version --unicode --debug=yes --version)
    set(_wx_variant --unicode --debug=yes)
    set(OTP_WX_FORCED_DEBUG TRUE)
    set(OTP_WX_SELECTED_DEBUG TRUE)
endif()

_otp_wx_query(OTP_WX_VERSION_FULL ${_wx_variant} --version-full)
_otp_wx_query(OTP_WX_SELECTED_CONFIG ${_wx_variant} --selected-config)
_otp_wx_query(_wx_cc ${_wx_variant} --cc)
_otp_wx_query(_wx_cflags ${_wx_variant} --cflags)
_otp_wx_query(_wx_cxxflags ${_wx_variant} --cxxflags)
separate_arguments(_wx_c_options UNIX_COMMAND "${_wx_cflags}")
separate_arguments(_wx_cxx_options UNIX_COMMAND "${_wx_cxxflags}")

if(APPLE)

    # wx-config's compiler can carry an external dependency's deployment floor.
    # The product floor is selected independently of the SDK's own floor.
    string(REGEX MATCH "-mmacosx-version-min=([0-9.]+)" _wx_min_flag "${_wx_cc}")

    if(_wx_min_flag AND CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS CMAKE_MATCH_1)
        message(FATAL_ERROR
            "Selected wxWidgets requires macOS ${CMAKE_MATCH_1}; OTP deployment target is ${CMAKE_OSX_DEPLOYMENT_TARGET}"
        )
    endif()

    enable_language(OBJC)
    find_library(_wx_gl_framework OpenGL REQUIRED)
    find_library(_wx_cocoa_framework Cocoa REQUIRED)
    find_library(_wx_carbon_framework Carbon REQUIRED)
    set(_wx_gl_libraries "${_wx_gl_framework}")
    set(_wx_gl_header OpenGL/gl.h)
    set(_wx_glu_header OpenGL/glu.h)
    set(_wx_definitions _MACOSX _THREAD_SAFE _REENTRANT HAVE_OPENGL_GL_H=1 HAVE_OPENGL_GLU_H=1)
else()
    find_package(OpenGL REQUIRED)

    if(NOT TARGET OpenGL::GL OR NOT TARGET OpenGL::GLU)
        message(FATAL_ERROR "wx requires the platform OpenGL and GLU development libraries")
    endif()

    set(_wx_gl_libraries OpenGL::GL OpenGL::GLU)
    set(_wx_gl_header GL/gl.h)
    set(_wx_glu_header GL/glu.h)
    set(_wx_definitions _GNU_SOURCE _THREAD_SAFE _REENTRANT HAVE_GL_GL_H=1 HAVE_GL_GLU_H=1)

    # The pinned recipe uses GLib when its development package is present.
    find_package(PkgConfig QUIET)

    if(PkgConfig_FOUND)
        pkg_check_modules(OTP_WX_GLIB QUIET IMPORTED_TARGET glib-2.0)

        if(OTP_WX_GLIB_FOUND)
            list(APPEND _wx_definitions HAVE_GLIB=1)
        endif()
    endif()
endif()

# Compile and link only: configuration never starts a GUI or requires a display.
# Recheck every capability rather than trusting stale cache entries after an
# explicitly selected installation has changed in place.
string(SHA256
    _wx_probe_key
        "${_wx_config_real}|${OTP_WX_VERSION_FULL}|${OTP_WX_SELECTED_CONFIG}|${_wx_cxxflags}|${_wx_variant}|${CMAKE_OSX_DEPLOYMENT_TARGET}"
)

macro(_otp_wx_check source output)
    set(_wx_probe "${output}_${_wx_probe_key}")
    unset("${_wx_probe}" CACHE)
    check_cxx_source_compiles("${source}" "${_wx_probe}")
    set(${output} "${${_wx_probe}}")
endmacro()

cmake_push_check_state(RESET)
set(CMAKE_REQUIRED_FLAGS "${_wx_cxxflags}")
block(PROPAGATE OTP_WX_HAS_REQUIRED_FEATURES)
    # Upstream compiles these feature checks; actual wx linkage is checked below.
    set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
_otp_wx_check(
    "#include <wx/wx.h>\n#if !wxUSE_UNICODE || !wxCHECK_VERSION(3,0,2)\n#error Unicode wxWidgets 3.0.2 or newer is required\n#endif\n#if !(wxMAJOR_VERSION > 2 && (wxMINOR_VERSION == 0 || WXWIN_COMPATIBILITY_3_0 == 1))\n#error wxWidgets compatibility 3.0 is required\n#endif\n#if !wxUSE_GLCANVAS\n#error wxWidgets GL canvas support is required\n#endif\nint main() { return 0; }"
    OTP_WX_HAS_REQUIRED_FEATURES
)
endblock()

if(NOT OTP_WX_HAS_REQUIRED_FEATURES)
    message(FATAL_ERROR
        "Selected wxWidgets lacks required Unicode, compatibility 3.0 or GL canvas support"
    )
endif()

# WebView is optional in upstream, and is enabled only after an actual link.
execute_process(
    COMMAND "${OTP_WX_CONFIG}" ${_wx_variant} --libs core,base,html,webview
    RESULT_VARIABLE _wx_webview_result
    OUTPUT_VARIABLE _wx_webview_libs
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
set(OTP_WX_HAS_WEBVIEW FALSE)

if(_wx_webview_result EQUAL 0)
    _otp_wx_link_items(CMAKE_REQUIRED_LIBRARIES "${_wx_webview_libs}")
    _otp_wx_check(
        "#include <wx/wx.h>\n#include <wx/webview.h>\nint main() { return wxWebView::New() == nullptr; }"
        OTP_WX_HAS_WEBVIEW
    )
endif()

set(OTP_WX_COMPONENTS stc,xrc,html,adv,xml,core,base,gl,aui)

if(OTP_WX_HAS_WEBVIEW)
    string(APPEND OTP_WX_COMPONENTS ",webview")
    list(APPEND _wx_definitions WXE_WEBVIEW=1)
endif()

_otp_wx_query(_wx_libs ${_wx_variant} --libs "${OTP_WX_COMPONENTS}")
execute_process(
    COMMAND "${OTP_WX_CONFIG}" ${_wx_variant} --static --libs "${OTP_WX_COMPONENTS}"
    RESULT_VARIABLE _wx_static_result
    OUTPUT_VARIABLE _wx_static_libs
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
set(OTP_WX_LINKAGE shared)

if(_wx_static_result EQUAL 0 AND NOT _wx_static_libs STREQUAL "")
    set(_wx_libs "${_wx_static_libs}")
    set(OTP_WX_LINKAGE static)
endif()

_otp_wx_link_items(_wx_link_items "${_wx_libs}")
set(CMAKE_REQUIRED_LIBRARIES ${_wx_link_items})
_otp_wx_check(
    "#include <wx/wx.h>\n#include <wx/stc/stc.h>\nclass MyApp : public wxApp { bool OnInit() override { wxString s = wxString::FromUTF8(\"foo\"); return new wxStyledTextCtrl() != nullptr; } };\nwxIMPLEMENT_APP(MyApp);"
    OTP_WX_CAN_LINK
)

if(NOT OTP_WX_CAN_LINK)
    message(FATAL_ERROR
        "Cannot link the selected wxWidgets component closure: ${OTP_WX_COMPONENTS}"
    )
endif()

set(CMAKE_REQUIRED_LIBRARIES ${_wx_gl_libraries})
_otp_wx_check(
    "#include <${_wx_gl_header}>\n#include <${_wx_glu_header}>\nint main() { const GLubyte *v = glGetString(GL_VERSION); GLUtesselator *t = gluNewTess(); gluDeleteTess(t); return v != nullptr; }"
    OTP_WX_CAN_LINK_GL_GLU
)

if(NOT OTP_WX_CAN_LINK_GL_GLU)
    message(FATAL_ERROR "Selected platform lacks usable OpenGL and GLU headers/libraries")
endif()

foreach(_type IN ITEMS GLintptr GLintptrARB GLchar GLcharARB GLhalfARB GLint64EXT)
    string(TOUPPER "${_type}" _type_upper)
    _otp_wx_check(
        "#include <${_wx_gl_header}>\nint main() { return sizeof(${_type}) == 0; }"
        OTP_WX_HAVE_${_type_upper}
    )

    if(OTP_WX_HAVE_${_type_upper})
        list(APPEND _wx_definitions HAVE_${_type_upper}=1)
    endif()
endforeach()

_otp_wx_check(
    "#include <${_wx_glu_header}>\n#ifndef CALLBACK\n#define CALLBACK\n#endif\nvoid CALLBACK foo() {}\nint main() { GLUtesselator *t = nullptr; gluTessCallback(t, GLU_TESS_VERTEX, (GLvoid (*)(...)) foo); return 0; }"
    OTP_WX_TESS_CB_TIGER_STYLE
)

if(OTP_WX_TESS_CB_TIGER_STYLE)
    list(APPEND _wx_definitions TESS_CB_TIGER_STYLE=1)
endif()

cmake_pop_check_state()
list(APPEND _wx_definitions HAVE_GL_SUPPORT=1)

# Resolve and fingerprint the selected native libraries, not just the selector.
# wx-config may report shared installation directories outside its own prefix.
set(_wx_library_dirs)

foreach(_item IN LISTS _wx_link_items)
    if(_item MATCHES "^-L(.+)$")
        list(APPEND _wx_library_dirs "${CMAKE_MATCH_1}")
    endif()
endforeach()

set(_wx_receipt
    "upstream_commit=${_wx_upstream}\nwx_config=${OTP_WX_CONFIG}\nwx_config_real=${_wx_config_real}\nversion=${OTP_WX_VERSION_FULL}\nselected_config=${OTP_WX_SELECTED_CONFIG}\nprefix=${_wx_prefix}\ncompiler=${_wx_cc}\nvariant=${_wx_variant}\nforced_debug=${OTP_WX_FORCED_DEBUG}\ncomponents=${OTP_WX_COMPONENTS}\nwebview=${OTP_WX_HAS_WEBVIEW}\ncflags=${_wx_cflags}\ncxxflags=${_wx_cxxflags}\nlibs=${_wx_libs}\n"
)
set(_wx_artifacts "${_wx_config_real}")
set(_wx_resolved_link_items)

foreach(_item IN LISTS _wx_link_items)
    if(_item MATCHES "^-l(wx[^ ]+)$")
        set(_wx_library_name "${CMAKE_MATCH_1}")
        unset(_wx_library CACHE)
        set(_wx_saved_suffixes "${CMAKE_FIND_LIBRARY_SUFFIXES}")

        if(OTP_WX_LINKAGE STREQUAL static)
            set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
        endif()

        find_library(_wx_library
            NAMES "${_wx_library_name}"
            PATHS ${_wx_library_dirs}
            NO_DEFAULT_PATH
            REQUIRED
        )
        set(CMAKE_FIND_LIBRARY_SUFFIXES "${_wx_saved_suffixes}")
        list(APPEND _wx_artifacts "${_wx_library}")
        list(APPEND _wx_resolved_link_items "${_wx_library}")
    elseif(APPLE AND _item MATCHES "[.]framework$")
        get_filename_component(_framework_name "${_item}" NAME_WE)
        list(APPEND _wx_artifacts "${_item}/${_framework_name}.tbd")
        list(APPEND _wx_resolved_link_items "${_item}")
    else()
        list(APPEND _wx_resolved_link_items "${_item}")
    endif()
endforeach()

foreach(_item IN LISTS _wx_cxx_options)
    if(_item MATCHES "^-I(.+)$")
        set(_wx_include_dir "${CMAKE_MATCH_1}")

        foreach(_header IN ITEMS wx/setup.h wx/version.h)
            if(EXISTS "${_wx_include_dir}/${_header}")
                list(APPEND _wx_artifacts "${_wx_include_dir}/${_header}")
            endif()
        endforeach()
    endif()
endforeach()

# Bind the non-system dylib closure too: image codecs and other wx dependencies
# can impose a newer deployment floor than the wx component that loads them.
set(_wx_system_libraries)

if(APPLE)
    set(_wx_pending ${_wx_artifacts})
    set(_wx_scanned)

    while(_wx_pending)
        list(POP_FRONT _wx_pending _artifact)
        file(REAL_PATH "${_artifact}" _real)

        if(NOT _real MATCHES "[.]dylib$" OR _real IN_LIST _wx_scanned)
            continue()
        endif()

        list(APPEND _wx_scanned "${_real}")
        execute_process(
            COMMAND /usr/bin/otool -L "${_real}"
            RESULT_VARIABLE _result
            OUTPUT_VARIABLE _dependencies
            ERROR_VARIABLE _error
        )

        if(NOT _result EQUAL 0)
            message(FATAL_ERROR
                "Cannot inspect selected wxWidgets dependency closure ${_real}: ${_error}"
            )
        endif()

        execute_process(
            COMMAND /usr/bin/otool -l "${_real}"
            RESULT_VARIABLE _result
            OUTPUT_VARIABLE _load_commands
            ERROR_VARIABLE _error
        )

        if(NOT _result EQUAL 0)
            message(FATAL_ERROR
                "Cannot inspect selected wxWidgets load commands ${_real}: ${_error}"
            )
        endif()

        get_filename_component(_loader_dir "${_real}" DIRECTORY)
        set(_rpaths)
        string(REGEX MATCHALL "path [^\n]+ \\(offset [0-9]+\\)" _rpath_lines "${_load_commands}")

        foreach(_rpath_line IN LISTS _rpath_lines)
            string(REGEX REPLACE "^path (.+) \\(offset [0-9]+\\)$" "\\1" _rpath "${_rpath_line}")
            string(REPLACE "@loader_path" "${_loader_dir}" _rpath "${_rpath}")
            list(APPEND _rpaths "${_rpath}")
        endforeach()

        string(REPLACE "\n" ";" _dependency_lines "${_dependencies}")

        foreach(_line IN LISTS _dependency_lines)
            if(_line MATCHES "^[ \t]+([^ \t]+)[ \t]+\\(compatibility version")
                set(_dependency "${CMAKE_MATCH_1}")

                if(_dependency MATCHES "^(/usr/lib/|/System/Library/)")
                    list(APPEND _wx_system_libraries "${_dependency}")
                    continue()
                elseif(_dependency MATCHES "^@loader_path/(.+)$")
                    set(_dependency "${_loader_dir}/${CMAKE_MATCH_1}")
                elseif(_dependency MATCHES "^@rpath/(.+)$")
                    set(_rpath_name "${CMAKE_MATCH_1}")

                    foreach(_rpath IN LISTS _rpaths)
                        if(IS_ABSOLUTE "${_rpath}" AND EXISTS "${_rpath}/${_rpath_name}")
                            set(_dependency "${_rpath}/${_rpath_name}")
                            break()
                        endif()
                    endforeach()
                endif()

                if(NOT IS_ABSOLUTE "${_dependency}" OR NOT EXISTS "${_dependency}")
                    message(FATAL_ERROR
                        "Cannot resolve selected wxWidgets dependency ${_dependency} from ${_real}"
                    )
                endif()

                list(APPEND _wx_artifacts "${_dependency}")
                list(APPEND _wx_pending "${_dependency}")
            endif()
        endforeach()
    endwhile()
endif()

list(REMOVE_DUPLICATES _wx_artifacts)
list(REMOVE_DUPLICATES _wx_system_libraries)
set(_wx_receipt_json "{}")
string(JSON _wx_receipt_json SET "${_wx_receipt_json}" schema_version 1)

foreach(_field IN ITEMS
    upstream_commit
    version
    selected_config
    prefix
    compiler
    linkage
    deployment_target
    system
    architecture
)
    if(_field STREQUAL upstream_commit)
        set(_value "${_wx_upstream}")
    elseif(_field STREQUAL version)
        set(_value "${OTP_WX_VERSION_FULL}")
    elseif(_field STREQUAL selected_config)
        set(_value "${OTP_WX_SELECTED_CONFIG}")
    elseif(_field STREQUAL linkage)
        set(_value "${OTP_WX_LINKAGE}")
    elseif(_field STREQUAL deployment_target)
        set(_value "${CMAKE_OSX_DEPLOYMENT_TARGET}")
    elseif(_field STREQUAL system)
        set(_value "${CMAKE_SYSTEM_NAME}")
    elseif(_field STREQUAL architecture)
        set(_value "${CMAKE_SYSTEM_PROCESSOR}")
    elseif(_field STREQUAL compiler)
        set(_value "${_wx_cc}")
    else()
        set(_value "${_wx_prefix}")
    endif()

    _otp_wx_json_set(_wx_receipt_json "${_field}" "${_value}")
endforeach()

_otp_wx_json_set(_wx_receipt_json selector "${OTP_WX_CONFIG}")
_otp_wx_json_set(_wx_receipt_json selector_real_path "${_wx_config_real}")
file(SHA256 "${_wx_config_real}" _wx_selector_sha256)
_otp_wx_json_set(_wx_receipt_json selector_sha256 "${_wx_selector_sha256}")
string(JSON _wx_receipt_json SET "${_wx_receipt_json}" unicode true)

if(OTP_WX_SELECTED_DEBUG)
    string(JSON _wx_receipt_json SET "${_wx_receipt_json}" debug true)
else()
    string(JSON _wx_receipt_json SET "${_wx_receipt_json}" debug false)
endif()

if(OTP_WX_HAS_WEBVIEW)
    string(JSON _wx_receipt_json SET "${_wx_receipt_json}" webview true)
else()
    string(JSON _wx_receipt_json SET "${_wx_receipt_json}" webview false)
endif()

string(REPLACE "," ";" _wx_components "${OTP_WX_COMPONENTS}")
separate_arguments(_wx_raw_link_options UNIX_COMMAND "${_wx_libs}")

foreach(_field IN ITEMS components cflags cxxflags link_flags system_libraries)
    if(_field STREQUAL components)
        set(_values ${_wx_components})
    elseif(_field STREQUAL cflags)
        set(_values ${_wx_c_options})
    elseif(_field STREQUAL cxxflags)
        set(_values ${_wx_cxx_options})
    elseif(_field STREQUAL system_libraries)
        set(_values ${_wx_system_libraries})
    else()
        set(_values ${_wx_raw_link_options})
    endif()

    set(_array "[]")
    set(_index 0)

    foreach(_value IN LISTS _values)
        _otp_wx_json_string(_wx_quoted "${_value}")
        string(JSON _array SET "${_array}" ${_index} "${_wx_quoted}")
        math(EXPR _index "${_index} + 1")
    endforeach()

    string(JSON _wx_receipt_json SET "${_wx_receipt_json}" "${_field}" "${_array}")
endforeach()

set(_wx_artifact_json "[]")
set(_wx_artifact_index 0)

foreach(_artifact IN LISTS _wx_artifacts)
    file(REAL_PATH "${_artifact}" _real)
    file(SHA256 "${_real}" _hash)
    string(APPEND _wx_receipt "artifact=${_real}\nsha256=${_hash}\n")
    set(_entry "{}")
    _otp_wx_json_set(_entry path "${_artifact}")
    _otp_wx_json_set(_entry real_path "${_real}")
    _otp_wx_json_set(_entry sha256 "${_hash}")

    if(APPLE AND _real MATCHES "[.]dylib$")
        execute_process(
            COMMAND /usr/bin/otool -l "${_real}"
            RESULT_VARIABLE _result
            OUTPUT_VARIABLE _load_commands
            ERROR_VARIABLE _error
        )

        if(NOT _result EQUAL 0)
            message(FATAL_ERROR "Cannot inspect selected wxWidgets library ${_real}: ${_error}")
        endif()

        string(REGEX MATCH "minos[ \t]+([0-9.]+)" _minos "${_load_commands}")

        if(_minos)
            set(_floor "${CMAKE_MATCH_1}")
            string(APPEND _wx_receipt "macos_minimum=${_floor}\n")
            _otp_wx_json_set(_entry macos_minimum "${_floor}")
            _otp_wx_json_set(_entry
                deployment_evidence "LC_BUILD_VERSION minos from /usr/bin/otool -l"
            )

            if(CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS _floor)
                message(FATAL_ERROR
                    "Selected wxWidgets library ${_real} requires macOS ${_floor}; OTP deployment target is ${CMAKE_OSX_DEPLOYMENT_TARGET}"
                )
            endif()
        endif()
    endif()

    string(JSON _wx_artifact_json SET "${_wx_artifact_json}" ${_wx_artifact_index} "${_entry}")
    math(EXPR _wx_artifact_index "${_wx_artifact_index} + 1")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_artifact}" "${_real}")
endforeach()

file(WRITE "${PROJECT_BINARY_DIR}/wx-selection.txt" "${_wx_receipt}")
string(JSON _wx_receipt_json SET "${_wx_receipt_json}" artifacts "${_wx_artifact_json}")
file(WRITE "${PROJECT_BINARY_DIR}/wx-selection.json" "${_wx_receipt_json}\n")
