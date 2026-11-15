# stdlib application sources, generation and release rules.
otp_application_version(stdlib _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/argparse.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/array.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base64.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/c.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/calendar.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dets_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dets_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dets_utils.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dets_v9.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dict.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/digraph.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/digraph_utils.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edlin.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edlin_context.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edlin_expand.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edlin_key.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edlin_type_suggestion.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/epp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_abstract_code.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_anno.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_bits.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_compile.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_error.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_eval.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_expand_records.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_features.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_internal.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_lint.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_posix_msg.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_pp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_scan.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_stdlib_errors.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_tar.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/error_logger_file_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/error_logger_tty_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/escript.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eval_bits.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/file_sorter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/filelib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/filename.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gb_sets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gb_trees.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_event.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_fsm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_statem.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/graph.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/io.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/io_ansi.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/io_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/io_lib_format.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/io_lib_fread.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/io_lib_pretty.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/json.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lists.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/log_mf_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/man_docs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/maps.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/math.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ms_transform.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/orddict.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ordsets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/otp_internal.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/peer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pool.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/proc_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/proplists.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/qlc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/qlc_pt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/queue.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/rand.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/random.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/re.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/records.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/shell.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/shell_default.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/shell_docs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/shell_docs_markdown.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/slave.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sofs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/string.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/supervisor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/supervisor_bridge.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/timer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/unicode.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/uri_string.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/win32reg.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/zip.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/zstd.erl"
    "${OTP_GENERATED_ROOT}/stdlib/src/erl_parse.erl"
    "${OTP_GENERATED_ROOT}/stdlib/src/unicode_util.erl"
)

get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_parse.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${OTP_GENERATED_ROOT}/stdlib/src/erl_parse.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_parse.yrl")
otp_generator(TARGET otp_generate_erl_parse
    COMMANDS ${_parser_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/stdlib/src/erl_parse.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_parse.yrl"
        otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CaseFolding.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/CaseFolding.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CaseFolding.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/CaseFolding.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_CaseFolding_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CaseFolding.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CompositionExclusions.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/CompositionExclusions.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CompositionExclusions.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/CompositionExclusions.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_CompositionExclusions_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CompositionExclusions.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/DerivedCoreProperties.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/DerivedCoreProperties.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/DerivedCoreProperties.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/DerivedCoreProperties.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_DerivedCoreProperties_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/DerivedCoreProperties.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/EastAsianWidth.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/EastAsianWidth.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/EastAsianWidth.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/EastAsianWidth.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_EastAsianWidth_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/EastAsianWidth.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/GraphemeBreakProperty.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/GraphemeBreakProperty.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/GraphemeBreakProperty.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/GraphemeBreakProperty.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_GraphemeBreakProperty_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/GraphemeBreakProperty.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/IndicSyllabicCategory.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/IndicSyllabicCategory.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/IndicSyllabicCategory.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/IndicSyllabicCategory.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_IndicSyllabicCategory_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/IndicSyllabicCategory.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/PropList.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/PropList.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/PropList.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/PropList.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_PropList_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/PropList.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/README-UPDATE.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/README-UPDATE.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/README-UPDATE.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/README-UPDATE.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_README_UPDATE_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/README-UPDATE.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/SpecialCasing.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/SpecialCasing.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/SpecialCasing.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/SpecialCasing.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_SpecialCasing_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/SpecialCasing.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/UnicodeData.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/UnicodeData.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/UnicodeData.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/UnicodeData.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_UnicodeData_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/UnicodeData.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/emoji-data.txt"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/emoji-data.txt" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/emoji-data.txt"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/emoji-data.txt"
    VERBATIM
)
add_custom_target(otp_unicode_input_emoji_data_txt DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/emoji-data.txt"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/gen_unicode_mod.escript"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/gen_unicode_mod.escript" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/gen_unicode_mod.escript"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/gen_unicode_mod.escript"
    VERBATIM
)
add_custom_target(otp_unicode_input_gen_unicode_mod_escript DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/gen_unicode_mod.escript"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/vendor.info"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/stdlib/uc_spec"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/vendor.info" "${OTP_GENERATED_ROOT}/stdlib/uc_spec/vendor.info"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/vendor.info"
    VERBATIM
)
add_custom_target(otp_unicode_input_vendor_info DEPENDS
    "${OTP_GENERATED_ROOT}/stdlib/uc_spec/vendor.info"
)
otp_command(_unicode_command "${OTP_GENERATED_ROOT}/stdlib/src"
    "${OTP_BOOTSTRAP_ROOT}/bin/escript"
    "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/gen_unicode_mod.escript")
otp_generator(
    TARGET otp_unicode
    COMMANDS ${_unicode_command}
    OUTPUTS
        "${OTP_GENERATED_ROOT}/stdlib/src/unicode_util.erl"
    DEPENDS ${_unicode_command_INPUTS}
        "${CMAKE_CURRENT_SOURCE_DIR}/uc_spec/gen_unicode_mod.escript"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CaseFolding.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/CompositionExclusions.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/DerivedCoreProperties.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/EastAsianWidth.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/GraphemeBreakProperty.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/IndicSyllabicCategory.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/PropList.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/README-UPDATE.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/SpecialCasing.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/UnicodeData.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/emoji-data.txt"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/gen_unicode_mod.escript"
        "${OTP_GENERATED_ROOT}/stdlib/uc_spec/vendor.info"
)

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP stdlib
    SOURCES ${_sources}
    OPTIONS warn_deprecated_catch warn_obsolete_bool_op
    DEPENDS otp_generate_erl_parse otp_unicode
    INPUTS ${_headers} "${CMAKE_CURRENT_SOURCE_DIR}/doc/src/ms_transform.md" "${CMAKE_CURRENT_SOURCE_DIR}/doc/src/re.md" "${CMAKE_CURRENT_SOURCE_DIR}/doc/src/sofs.md" "${CMAKE_CURRENT_SOURCE_DIR}/doc/src/shell.md" "${CMAKE_CURRENT_SOURCE_DIR}/doc/src/qlc.md" "${CMAKE_CURRENT_SOURCE_DIR}/doc/src/peer.md"
)
