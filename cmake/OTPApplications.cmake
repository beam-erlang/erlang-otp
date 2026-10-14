# OTP-owned generation and source compilation through private public-SDK hosts.
find_package(Perl REQUIRED)
set(OTP_APPLICATIONS kernel stdlib compiler parsetools sasl erl_interface common_test syntax_tools crypto asn1 tools public_key ssl runtime_tools mnesia inets eunit xmerl ftp tftp ssh edoc eldap diameter os_mon jinterface dialyzer snmp megaco odbc wx debugger et observer reltool)
set(_otp_driver "${PROJECT_SOURCE_DIR}/tools/otp_build_driver.erl")
set(_otp_tools "${PROJECT_BINARY_DIR}/bootstrap-tools/parsetools/ebin")

file(GLOB_RECURSE _otp_headers CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/lib/kernel/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/stdlib/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/compiler/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/parsetools/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/common_test/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/syntax_tools/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/snmp/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/snmp/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/megaco/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/megaco/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/et/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/xmerl/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/asn1/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/tools/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/public_key/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/public_key/src/public_key_internal.hrl"
    "${PROJECT_SOURCE_DIR}/lib/ssl/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/runtime_tools/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/mnesia/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/inets/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/inets/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/eunit/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/eunit/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/xmerl/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/ftp/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/tftp/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/ssh/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/edoc/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/edoc/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/eldap/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/diameter/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/diameter/src/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/os_mon/include/*.hrl"
    "${PROJECT_SOURCE_DIR}/lib/dialyzer/src/*.hrl")
set(_tool_sources)
set(_tool_outputs)
foreach(_module IN ITEMS ms_transform qlc qlc_pt yecc yeccscan yeccparser leex)
    if(_module MATCHES "^(ms_transform|qlc|qlc_pt)$")
        set(_app stdlib)
    else()
        set(_app parsetools)
    endif()
    list(APPEND _tool_sources "${PROJECT_SOURCE_DIR}/lib/${_app}/src/${_module}.erl")
    list(APPEND _tool_outputs "${_otp_tools}/${_module}.beam")
endforeach()
list(APPEND _tool_outputs "${_otp_tools}/../include/yeccpre.hrl")
add_custom_command(OUTPUT ${_tool_outputs}
    COMMAND ${OTP_SEED_COMMAND}
        tools "${PROJECT_SOURCE_DIR}" "${_otp_tools}" "${OTP_SEED_ROOT}"
    DEPENDS ${_tool_sources} ${_otp_headers} "${_otp_driver}" otp_seed_host
    COMMENT "Building OTP-owned parser and transform tools" VERBATIM)

set(_opcode_dir "${PROJECT_BINARY_DIR}/generated/compiler")
file(MAKE_DIRECTORY "${_opcode_dir}" "${PROJECT_BINARY_DIR}/generated/kernel")
add_custom_command(OUTPUT "${_opcode_dir}/beam_opcodes.erl" "${_opcode_dir}/beam_opcodes.hrl"
    COMMAND "${PERL_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/erts/emulator/utils/beam_makeops"
        -compiler -outdir "${_opcode_dir}" "${PROJECT_SOURCE_DIR}/lib/compiler/src/genop.tab"
    DEPENDS "${PROJECT_SOURCE_DIR}/erts/emulator/utils/beam_makeops"
        "${PROJECT_SOURCE_DIR}/lib/compiler/src/genop.tab"
    COMMENT "Generating OTP compiler opcode metadata" VERBATIM)
set(_dns_header "${PROJECT_BINARY_DIR}/generated/kernel/inet_dns_record_adts.hrl")
add_custom_command(OUTPUT "${_dns_header}"
    COMMAND "${CMAKE_COMMAND}" "-DPERL=${PERL_EXECUTABLE}"
        "-DGENERATOR=${PROJECT_SOURCE_DIR}/lib/kernel/src/inet_dns_record_adts.pl"
        "-DOUTPUT=${_dns_header}" -P "${PROJECT_SOURCE_DIR}/cmake/GenerateDnsHeader.cmake"
    DEPENDS "${PROJECT_SOURCE_DIR}/lib/kernel/src/inet_dns_record_adts.pl"
        "${PROJECT_SOURCE_DIR}/cmake/GenerateDnsHeader.cmake"
    COMMENT "Generating kernel DNS record accessors" VERBATIM)

set(_unicode_generator "${PROJECT_SOURCE_DIR}/lib/stdlib/uc_spec/gen_unicode_mod.escript")
set(_unicode_output "${PROJECT_BINARY_DIR}/generated/stdlib/unicode_util.erl")
file(GLOB _unicode_data CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/lib/stdlib/uc_spec/*.txt")
foreach(_data IN LISTS _unicode_data)
    get_filename_component(_name "${_data}" NAME)
    configure_file("${_data}" "${PROJECT_BINARY_DIR}/generated/uc_spec/${_name}" COPYONLY)
endforeach()
add_custom_command(OUTPUT "${_unicode_output}"
    COMMAND ${OTP_SEED_COMMAND}
        unicode "${_unicode_generator}" "${_unicode_output}" "${OTP_SEED_ROOT}"
    DEPENDS "${_unicode_generator}" ${_unicode_data} "${_otp_driver}" otp_seed_host
    COMMENT "Generating STDLIB Unicode tables from retained specifications" VERBATIM)

foreach(_app IN ITEMS stdlib compiler tools)
    if(_app STREQUAL stdlib)
        set(_parser erl_parse)
    elseif(_app STREQUAL compiler)
        set(_parser core_parse)
    else()
        set(_parser xref_parser)
    endif()
    if(_app STREQUAL tools)
        set(_parser_command ${OTP_BUILD_COMMAND})
        set(_parser_root "${OTP_BUILD_ROOT}")
        set(_parser_host otp_build_host)
    else()
        set(_parser_command ${OTP_SEED_COMMAND})
        set(_parser_root "${OTP_SEED_ROOT}")
        set(_parser_host otp_seed_host)
    endif()
    set(_input "${PROJECT_SOURCE_DIR}/lib/${_app}/src/${_parser}.yrl")
    set(_output "${PROJECT_BINARY_DIR}/generated/${_app}/${_parser}.erl")
    add_custom_command(OUTPUT "${_output}"
        COMMAND ${_parser_command}
            parser "${PROJECT_SOURCE_DIR}" "${_otp_tools}" "${_input}" "${_output}" "${_parser_root}"
        DEPENDS "${_input}" ${_tool_outputs} "${_otp_driver}" ${_parser_host}
        COMMENT "Generating ${_app} parser from the OTP grammar" VERBATIM)
endforeach()

include("${PROJECT_SOURCE_DIR}/cmake/OTPASN1.cmake")

foreach(_app IN LISTS OTP_APPLICATIONS)
    otp_application_version("${_app}" _version)
    set(_source "${PROJECT_SOURCE_DIR}/lib/${_app}/src")
    set(_resources "${_source}")
    set(_generated "${PROJECT_BINARY_DIR}/generated/${_app}")
    set(_ebin "${PROJECT_BINARY_DIR}/otp/lib/${_app}-${_version}/ebin")
    # Preserve normal include_lib discovery for explicit source-built dependencies.
    file(GLOB_RECURSE _public_headers CONFIGURE_DEPENDS RELATIVE "${PROJECT_SOURCE_DIR}/lib/${_app}/include"
        "${PROJECT_SOURCE_DIR}/lib/${_app}/include/*.hrl")
    foreach(_header IN LISTS _public_headers)
        configure_file("${PROJECT_SOURCE_DIR}/lib/${_app}/include/${_header}"
            "${PROJECT_BINARY_DIR}/otp/lib/${_app}-${_version}/include/${_header}" COPYONLY)
    endforeach()
    file(GLOB _sources CONFIGURE_DEPENDS "${_source}/*.erl")
    set(_extra_dependencies)
    set(_code_dependencies)
    if(_app STREQUAL asn1)
        # Runtime templates and prepare_templates are build inputs, not product
        # modules. Preserve upstream's explicit compiler/runtime inventory.
        set(_sources)
        foreach(_module IN ITEMS asn1ct asn1ct_check asn1_db asn1ct_pretty_format
                asn1ct_func asn1ct_gen asn1ct_gen_check asn1ct_gen_per asn1ct_name
                asn1ct_constructed_per asn1ct_constructed_ber_bin_v2 asn1ct_gen_ber_bin_v2
                asn1ct_gen_jer asn1ct_imm asn1ct_value asn1ct_tok asn1ct_parser2
                asn1ct_table asn1ct_partial_decode asn1rt_nif)
            list(APPEND _sources "${_source}/${_module}.erl")
        endforeach()
        list(APPEND _sources "${_generated}/asn1ct_rtt.erl" "${_generated}/asn1ct_eval_ext.erl")
    elseif(_app MATCHES "^(debugger|et|observer|reltool)$")
        otp_application_version(wx _wx_version)
        list(APPEND _code_dependencies "${PROJECT_BINARY_DIR}/otp/lib/wx-${_wx_version}/ebin")
        file(GLOB _gui_headers CONFIGURE_DEPENDS "${_source}/*.hrl"
            "${PROJECT_SOURCE_DIR}/lib/wx/include/*.hrl")
        list(APPEND _extra_dependencies ${_otp_wx_outputs} ${_gui_headers})
        if(_app STREQUAL observer)
            # Upstream's multitrace module is a documentation example.
            list(REMOVE_ITEM _sources "${_source}/multitrace.erl")
            list(APPEND _extra_dependencies "${PROJECT_SOURCE_DIR}/lib/et/include/et.hrl")
            install(FILES "${PROJECT_SOURCE_DIR}/lib/observer/priv/erlang_observer.png"
                DESTINATION "lib/observer-${_version}/priv")
            install(PROGRAMS "${PROJECT_SOURCE_DIR}/lib/observer/priv/bin/etop"
                "${PROJECT_SOURCE_DIR}/lib/observer/priv/bin/cdv"
                DESTINATION "lib/observer-${_version}/priv/bin")
        endif()
        if(_app STREQUAL debugger)
            install(DIRECTORY "${PROJECT_SOURCE_DIR}/lib/debugger/priv"
                DESTINATION "lib/debugger-${_version}" PATTERN "*.license" EXCLUDE)
        endif()
    elseif(_app STREQUAL wx)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPWx.cmake")
    elseif(_app STREQUAL odbc)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPODBC.cmake")
    elseif(_app STREQUAL megaco)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPMegaco.cmake")
    elseif(_app STREQUAL snmp)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPSNMP.cmake")
    elseif(_app STREQUAL jinterface)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPJInterface.cmake")
    elseif(_app STREQUAL os_mon)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPOSMon.cmake")
    elseif(_app STREQUAL diameter)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPDiameter.cmake")
    elseif(_app STREQUAL eldap)
        set(_schema "${PROJECT_SOURCE_DIR}/lib/eldap/asn1/ELDAPv3.asn1")
        set(_generated_erl "${_generated}/ELDAPv3.erl")
        set(_generated_hrl "${_generated}/ELDAPv3.hrl")
        otp_application_version(asn1 _asn1_version)
        add_custom_command(OUTPUT "${_generated_erl}" "${_generated_hrl}"
            COMMAND ${OTP_BUILD_COMMAND}
                eldap "${_schema}" "${_generated}"
                "${PROJECT_BINARY_DIR}/otp/lib/asn1-${_asn1_version}/ebin" "${OTP_BUILD_ROOT}"
            DEPENDS "${_schema}" ${_otp_asn1_outputs} "${_otp_driver}" otp_build_host
            COMMENT "Generating the retained LDAP ASN.1 codec" VERBATIM)
        list(APPEND _sources "${_generated_erl}")
        list(APPEND _extra_dependencies "${_generated_hrl}")
        install(FILES "${_generated_hrl}" DESTINATION "lib/eldap-${_version}/ebin")
        install(FILES "${_schema}" DESTINATION "lib/eldap-${_version}/asn1")
    elseif(_app STREQUAL edoc)
        set(_input "${_source}/edoc_parser.yrl")
        set(_output "${_generated}/edoc_parser.erl")
        add_custom_command(OUTPUT "${_output}"
            COMMAND ${OTP_BUILD_COMMAND}
                parser "${PROJECT_SOURCE_DIR}" "${_otp_tools}" "${_input}" "${_output}" "${OTP_BUILD_ROOT}"
            DEPENDS "${_input}" ${_tool_outputs} "${_otp_driver}" otp_build_host
            COMMENT "Generating the EDoc parser from its retained grammar" VERBATIM)
        list(APPEND _sources "${_output}")
        otp_application_version(xmerl _xmerl_version)
        list(APPEND _code_dependencies "${PROJECT_BINARY_DIR}/otp/lib/xmerl-${_xmerl_version}/ebin")
        list(APPEND _extra_dependencies ${_otp_xmerl_outputs})
    elseif(_app STREQUAL ssh)
        set(_behaviours)
        foreach(_name IN ITEMS ssh_dbg ssh_client_key_api ssh_daemon_channel
                ssh_server_channel ssh_server_key_api ssh_sftpd_file_api
                ssh_channel ssh_client_channel)
            list(APPEND _behaviours "${_source}/${_name}.erl")
        endforeach()
        list(REMOVE_ITEM _sources ${_behaviours})
        list(PREPEND _sources ${_behaviours})
        otp_application_version(public_key _public_key_version)
        list(APPEND _code_dependencies "${PROJECT_BINARY_DIR}/otp/lib/public_key-${_public_key_version}/ebin")
        list(APPEND _extra_dependencies ${_otp_public_key_outputs})
    elseif(_app STREQUAL tftp)
        set(_first "${_source}/tftp.erl" "${_source}/tftp_logger.erl")
        list(REMOVE_ITEM _sources ${_first})
        list(PREPEND _sources ${_first})
    elseif(_app STREQUAL eunit)
        set(_first "${_source}/eunit_autoexport.erl" "${_source}/eunit_listener.erl")
        list(REMOVE_ITEM _sources ${_first})
        list(PREPEND _sources ${_first})
    elseif(_app STREQUAL xmerl)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPXmerl.cmake")
    elseif(_app STREQUAL inets)
        set(_resources "${_source}/inets_app")
        set(_sources)
        foreach(_part IN ITEMS inets_app http_lib http_client http_server)
            file(GLOB _part_sources CONFIGURE_DEPENDS "${_source}/${_part}/*.erl")
            list(APPEND _sources ${_part_sources})
            file(GLOB _part_headers CONFIGURE_DEPENDS "${_source}/${_part}/*.hrl")
            foreach(_header IN LISTS _part_headers)
                get_filename_component(_name "${_header}" NAME)
                configure_file("${_header}"
                    "${PROJECT_BINARY_DIR}/otp/lib/inets-${_version}/src/${_part}/${_name}" COPYONLY)
            endforeach()
        endforeach()
        set(_behaviours "${_source}/inets_app/inets_service.erl"
            "${_source}/http_server/httpd_custom_api.erl")
        list(REMOVE_ITEM _sources ${_behaviours})
        list(PREPEND _sources ${_behaviours})
    elseif(_app STREQUAL ssl)
        set(_behaviours "${_source}/ssl_trace.erl" "${_source}/ssl_crl_cache_api.erl"
            "${_source}/ssl_session_cache_api.erl")
        list(REMOVE_ITEM _sources ${_behaviours})
        list(PREPEND _sources ${_behaviours})
        otp_application_version(public_key _public_key_version)
        list(APPEND _code_dependencies "${PROJECT_BINARY_DIR}/otp/lib/public_key-${_public_key_version}/ebin")
        list(APPEND _extra_dependencies ${_otp_public_key_outputs})
    elseif(_app STREQUAL public_key)
        include("${PROJECT_SOURCE_DIR}/cmake/OTPPublicKey.cmake")
    elseif(_app STREQUAL tools)
        list(APPEND _sources "${_generated}/xref_parser.erl")
    elseif(_app STREQUAL syntax_tools)
        # Upstream's product inventory excludes merl_tests. The transform is
        # compiled last, after its own source-built dependencies are available.
        set(_sources)
        foreach(_module IN ITEMS erl_syntax erl_prettypr erl_syntax_lib
                erl_comment_scan erl_recomment epp_dodger prettypr merl merl_transform)
            list(APPEND _sources "${_source}/${_module}.erl")
        endforeach()
    elseif(_app STREQUAL stdlib)
        list(APPEND _sources "${_generated}/erl_parse.erl" "${_unicode_output}")
    elseif(_app STREQUAL compiler)
        list(APPEND _sources "${_generated}/core_parse.erl" "${_generated}/beam_opcodes.erl")
        list(APPEND _extra_dependencies "${_generated}/beam_opcodes.hrl")
    elseif(_app STREQUAL kernel)
        list(APPEND _extra_dependencies "${_dns_header}")
    endif()
    if(_app MATCHES "^(kernel|stdlib|compiler|parsetools|edoc|syntax_tools|dialyzer|debugger|et|observer|reltool|common_test|sasl|crypto|asn1|tools|public_key|runtime_tools|odbc)$")
        # Inspection tools discover these product sources through the installed app tree.
        # Preserve the selected inventory rather than installing test modules.
        install(FILES ${_sources} DESTINATION "lib/${_app}-${_version}/src")
        file(GLOB _source_headers CONFIGURE_DEPENDS "${_source}/*.hrl")
        list(REMOVE_ITEM _source_headers "${_source}/socket_int.hrl" "${_source}/test_server_internal.hrl")
        if(_source_headers)
            install(FILES ${_source_headers} DESTINATION "lib/${_app}-${_version}/src")
        endif()
    endif()
    if(_app STREQUAL kernel)
        install(FILES "${_dns_header}" DESTINATION "lib/kernel-${_version}/src")
    elseif(_app STREQUAL stdlib)
        install(FILES "${_source}/erl_parse.yrl" DESTINATION "lib/stdlib-${_version}/src")
    elseif(_app STREQUAL edoc)
        install(FILES "${PROJECT_SOURCE_DIR}/lib/edoc/include/edoc_doclet.hrl" DESTINATION "lib/edoc-${_version}/src")
    elseif(_app STREQUAL compiler)
        install(FILES "${_generated}/beam_opcodes.hrl" "${_source}/core_parse.yrl"
            DESTINATION "lib/compiler-${_version}/src")
    elseif(_app STREQUAL tools)
        install(FILES "${_source}/xref_parser.yrl" DESTINATION "lib/tools-${_version}/src")
        file(GLOB _emacs CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/lib/tools/emacs/*.el"
            "${PROJECT_SOURCE_DIR}/lib/tools/emacs/erlang*" "${PROJECT_SOURCE_DIR}/lib/tools/emacs/README")
        install(FILES ${_emacs} DESTINATION "lib/tools-${_version}/emacs")
    elseif(_app STREQUAL asn1)
        install(FILES "${PROJECT_SOURCE_DIR}/lib/asn1/c_src/asn1_erl_nif.c" DESTINATION "lib/asn1-${_version}/c_src")
        install(FILES "${_source}/asn1.app.src" "${_source}/asn1.appup.src" DESTINATION "lib/asn1-${_version}/src")
    elseif(_app STREQUAL public_key)
        install(FILES "${_generated}/pubkey_moduli.hrl" DESTINATION "lib/public_key-${_version}/src")
    endif()
    set(_outputs "${_ebin}/${_app}.app" "${_ebin}/${_app}.appup" "${_ebin}/build.term")
    foreach(_erl IN LISTS _sources)
        get_filename_component(_module "${_erl}" NAME_WE)
        list(APPEND _outputs "${_ebin}/${_module}.beam")
    endforeach()
    set(OTP_INSTALL_${_app}_FILES ${_outputs})
    list(REMOVE_ITEM OTP_INSTALL_${_app}_FILES "${_ebin}/build.term")
    set(_profile_commands)
    if(_app MATCHES "^(compiler|kernel|mnesia|odbc|crypto)$")
        if(_app STREQUAL kernel)
            set(_profile epmd)
        else()
            set(_profile "${_app}")
        endif()
        set(_profile_script "${PROJECT_SOURCE_DIR}/tools/otp_compile_profile.escript")
        list(APPEND _extra_dependencies "${_profile_script}")
        set(_profile_commands COMMAND ${OTP_BUILD_COMMAND} script
            "${_profile_script}" "${OTP_BUILD_ROOT}" "${_ebin}" "${_profile}" "${_version}")
    endif()
    add_custom_command(OUTPUT ${_outputs}
        COMMAND ${OTP_BUILD_COMMAND}
            application "${PROJECT_SOURCE_DIR}" "${_otp_tools}" "${_app}" "${_version}"
            "${_ebin}" "${_generated}" "${_resources}" "${OTP_BUILD_ROOT}" ${_code_dependencies} --sources ${_sources}
        ${_profile_commands}
        DEPENDS ${_sources} ${_otp_headers} ${_extra_dependencies} ${_tool_outputs}
            "${_resources}/${_app}.app.src" "${_resources}/${_app}.appup.src"
            "${PROJECT_SOURCE_DIR}/otp_versions.table" "${_otp_driver}" otp_build_host
        COMMENT "Compiling ${_app}-${_version} from OTP sources" VERBATIM)
    add_custom_target(otp_${_app} DEPENDS ${_outputs})
    if(_app STREQUAL asn1)
        set(_otp_asn1_outputs ${_outputs})
    elseif(_app STREQUAL syntax_tools)
        set(_otp_syntax_outputs ${_outputs})
    elseif(_app STREQUAL xmerl)
        set(_otp_xmerl_outputs ${_outputs})
    elseif(_app STREQUAL public_key)
        set(_otp_public_key_outputs ${_outputs})
    elseif(_app STREQUAL wx)
        set(_otp_wx_outputs ${_outputs})
    endif()
    list(APPEND _otp_application_targets otp_${_app})
    list(APPEND _otp_application_outputs ${_outputs})
endforeach()
add_custom_target(otp_applications ALL)
add_dependencies(otp_applications ${_otp_application_targets})

if(BUILD_TESTING)
    otp_application_version(compiler _compiler_version)
    otp_application_version(stdlib _stdlib_version)
    add_test(NAME source-built-compiler
        COMMAND ${OTP_BUILD_COMMAND}
            verify-compiler
            "${PROJECT_BINARY_DIR}/otp/lib/compiler-${_compiler_version}/ebin"
            "${PROJECT_BINARY_DIR}/otp/lib/stdlib-${_stdlib_version}/ebin"
            "${PROJECT_SOURCE_DIR}/tools/fixtures/otp_compiler_probe.erl"
            "${PROJECT_BINARY_DIR}/checks/compiler" "${OTP_BUILD_ROOT}")
endif()
