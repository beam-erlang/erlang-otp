%% SPDX-License-Identifier: Apache-2.0
%% Executed by the selected private source-built OTP host.
main([Output, CodePath | Sources]) ->
    true = code:add_patha(CodePath),
    ok = filelib:ensure_dir(filename:join(Output, "placeholder")),
    lists:foreach(fun(Source) ->
        {ok, _} = compile:file(Source, [debug_info, report_errors, report_warnings,
                                       {outdir, Output}])
    end, Sources).
