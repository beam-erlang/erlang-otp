# Preserve the retained Perl/sed conversion pipeline without an ERL_TOP shell wrapper.
execute_process(COMMAND "${PERL}" "${TOOLS}/snmp-v2tov1.pl" "${INPUT}"
    COMMAND "${SED}" -f "${TOOLS}/snmp-v2tov1.sed"
    OUTPUT_FILE "${OUTPUT}" RESULTS_VARIABLE results)
foreach(result IN LISTS results)
    if(NOT result STREQUAL "0")
        message(FATAL_ERROR "SNMPv1 MIB conversion failed: ${results}")
    endif()
endforeach()
