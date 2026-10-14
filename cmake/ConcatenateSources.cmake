# Preserve the upstream source-fragment concatenation byte for byte.
file(READ "${FIRST}" _first)
file(READ "${SECOND}" _second)
file(WRITE "${OUTPUT}" "${_first}${_second}")
