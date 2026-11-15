# compiler application sources, generation and release rules.
otp_application_version(compiler _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_a.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_asm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_block.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_bounds.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_call_types.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_clean.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_core_to_ssa.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_dict.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_disasm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_doc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_flatten.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_jump.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_listing.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_alias.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_bc_size.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_bool.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_bsm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_check.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_codegen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_dead.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_destructive_update.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_lint.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_opt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_pp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_pre_codegen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_recv.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_share.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_ss.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_throw.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_type.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_trim.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_types.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_utils.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_validator.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_z.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl_clauses.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl_inline.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl_trees.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/core_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/core_lint.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/core_pp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/core_scan.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_bifs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/rec_env.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_alias.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_bsm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_fold.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_fold_lists.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_inline.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_prepare.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_coverage.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_messages.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_pre_attributes.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/v3_core.erl"
    "${OTP_GENERATED_ROOT}/compiler/src/core_parse.erl"
    "${OTP_GENERATED_ROOT}/compiler/src/beam_opcodes.erl"
)

get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/core_parse.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${OTP_GENERATED_ROOT}/compiler/src/core_parse.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/core_parse.yrl")
otp_generator(TARGET otp_generate_core_parse
    COMMANDS ${_parser_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/compiler/src/core_parse.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/core_parse.yrl"
        otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/compiler/src/beam_opcodes.erl"
        "${OTP_GENERATED_ROOT}/compiler/src/beam_opcodes.hrl"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/compiler/src"
    COMMAND "${PERL_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/erts/emulator/utils/beam_makeops" -compiler -outdir "${OTP_GENERATED_ROOT}/compiler/src" "${CMAKE_CURRENT_SOURCE_DIR}/src/genop.tab"
    DEPENDS
        "${PROJECT_SOURCE_DIR}/erts/emulator/utils/beam_makeops"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/genop.tab"
    VERBATIM
)
add_custom_target(otp_compiler_opcodes DEPENDS
    "${OTP_GENERATED_ROOT}/compiler/src/beam_opcodes.erl"
    "${OTP_GENERATED_ROOT}/compiler/src/beam_opcodes.hrl"
)

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_a.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_asm.erl" PROPERTY OTP_COMPILE_OPTIONS "inline" "{d,'COMPILER_VSN',\"${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_block.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_bounds.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_call_types.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_clean.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_core_to_ssa.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_dict.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_disasm.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_doc.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_flatten.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_jump.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_listing.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_alias.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_bc_size.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_bool.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_bsm.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_check.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_codegen.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_dead.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_destructive_update.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_lint.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_opt.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_pp.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_pre_codegen.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_recv.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_share.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_ss.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_throw.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_ssa_type.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_trim.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_types.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_utils.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_validator.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/beam_z.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl_clauses.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl_inline.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl_trees.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/compile.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/core_lib.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/core_lint.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/core_pp.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/core_scan.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_bifs.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/rec_env.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_alias.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_bsm.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_fold.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_fold_lists.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_inline.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_core_prepare.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_coverage.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_messages.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/sys_pre_attributes.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/v3_core.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
set_property(SOURCE "${OTP_GENERATED_ROOT}/compiler/src/beam_opcodes.erl" PROPERTY OTP_COMPILE_OPTIONS "inline")
otp_add_application(
    APP compiler
    SOURCES ${_sources}
    OPTIONS warn_deprecated_catch warn_obsolete_bool_op warn_unused_import warn_missing_spec
    DEPENDS otp_generate_core_parse otp_compiler_opcodes
    INPUTS ${_headers}
)

install(DIRECTORY "${OTP_GENERATED_ROOT}/compiler/src/" DESTINATION "lib/compiler-${_version}/src" FILES_MATCHING PATTERN "*.hrl")
