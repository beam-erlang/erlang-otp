# ODBC's port program uses the application-owned EI client library and the
# selected system driver manager. It has no VM-private dependency.
find_package(ODBC REQUIRED)
include(CheckCSourceCompiles)
check_c_source_compiles("#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
int main(void) { struct sockaddr_in6 address; return sizeof(address.sin6_addr) == 0; }"
    OTP_ODBC_HAVE_SOCKADDR_IN6)
list(REMOVE_ITEM _sources "${_source}/odbc_debug.erl")
add_executable(otp_odbcserver "${PROJECT_SOURCE_DIR}/lib/odbc/c_src/odbcserver.c")
if(NOT WIN32)
    target_compile_definitions(otp_odbcserver PRIVATE UNIX)
endif()
if(OTP_ODBC_HAVE_SOCKADDR_IN6)
    target_compile_definitions(otp_odbcserver PRIVATE HAVE_STRUCT_SOCKADDR_IN6_SIN6_ADDR=1)
endif()
target_link_libraries(otp_odbcserver PRIVATE otp_ei ODBC::ODBC)
set_target_properties(otp_odbcserver PROPERTIES OUTPUT_NAME odbcserver
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/lib/odbc-${_version}/priv/bin")
install(TARGETS otp_odbcserver RUNTIME DESTINATION "lib/odbc-${_version}/priv/bin")
install(FILES "${PROJECT_SOURCE_DIR}/lib/odbc/c_src/odbcserver.c"
    "${PROJECT_SOURCE_DIR}/lib/odbc/c_src/odbcserver.h"
    DESTINATION "lib/odbc-${_version}/c_src")
