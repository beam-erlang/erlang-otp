#!/usr/bin/env escript
%% SPDX-License-Identifier: Apache-2.0
-mode(compile).

main([Source, Output]) ->
    {ok, [{script, _, _} = Script]} = file:consult(Source),
    ok = filelib:ensure_dir(Output),
    ok = file:write_file(Output, term_to_binary(Script)).
