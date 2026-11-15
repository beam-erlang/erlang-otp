# Application source declarations are explicit; bootstrap/tool dependencies own build order.
foreach(_application IN LISTS OTP_APPLICATIONS)
    add_subdirectory("${_application}")
endforeach()
