# CMake's ordinary file installation and upstream Install both overwrite files
# in place. Stage the complete tree first, then replace each destination by
# rename: live mappings and macOS's vnode code-signature cache keep old inodes.
# The publisher also moves new subtrees intact to retain their directory modes.
install(CODE [[
    set(_otp_requested_prefix "${CMAKE_INSTALL_PREFIX}")
    string(RANDOM LENGTH 16 ALPHABET 0123456789abcdef _otp_install_nonce)
    set(CMAKE_INSTALL_PREFIX "${_otp_requested_prefix}/.otp-install-${_otp_install_nonce}")
    file(MAKE_DIRECTORY "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}")
]])
