%% SPDX-License-Identifier: Apache-2.0
-module(otp_bootstrap).
-export([start/0]).

%% Private build entry. init supplies literal arguments after -extra; the
%% compiler host and its complete module inventory are selected by the caller.
start() ->
    try execute(init:get_plain_arguments()) of
        ok -> erlang:halt(0)
    catch
        Class:Reason:Stack ->
            io:format(standard_error, "OTP build failed: ~tp:~tp~n~tp~n",
                      [Class, Reason, Stack]),
            erlang:halt(1)
    end.

execute(["seeds", ExpectedRoot, Recipe, SourceRoot, GeneratedRoot, OutputRoot]) ->
    {module, compile} = code:ensure_loaded(compile),
    true = lists:prefix(filename:split(filename:absname(ExpectedRoot)),
                        filename:split(code:which(compile))),
    {ok, [#{format := 1, modules := Modules}]} = file:consult(Recipe),
    lists:foreach(fun(#{source := Source, output := Output, options := Options}) ->
        File = resolve(Source, SourceRoot, GeneratedRoot),
        Destination = filename:join(OutputRoot, Output),
        ok = filelib:ensure_dir(Destination),
        Includes = [resolve(Include, SourceRoot, GeneratedRoot) ||
                    {include, Include} <- Options],
        CompileOptions = [Option || Option <- Options,
                                   element_or_self(Option) =/= include],
        Result = compile:noenv_file(File,
            [deterministic, debug_info, report_errors, report_warnings,
             {outdir, filename:dirname(Destination)}] ++
            [{i, Include} || Include <- Includes] ++ CompileOptions),
        Module = case Result of
            {ok, M} -> M;
            {ok, M, _} -> M;
            Error -> error({seed_compilation_failed, File, Error})
        end,
        true = atom_to_list(Module) ++ ".beam" =:= filename:basename(Destination)
    end, Modules),
    [#{output := PrimEval}] = [M || #{output := O} = M <- Modules,
                                  filename:basename(O) =:= "prim_eval.beam"],
    PrimDirectory = filename:dirname(filename:join(OutputRoot, PrimEval)),
    Stub = filename:join([SourceRoot, "erts", "preloaded", "src", "prim_eval.erl"]),
    {ok, _} = compile:noenv_file(Stub,
        [dabstr, deterministic, debug_info, report_errors, report_warnings,
         {outdir, PrimDirectory}]),
    otp_build_driver:main(["script",
        filename:join([SourceRoot, "erts", "preloaded", "src", "add_abstract_code"]),
        ExpectedRoot, filename:join(OutputRoot, PrimEval),
        filename:join(PrimDirectory, "prim_eval.abstr")]),
    ok;
execute(Arguments) ->
    otp_build_driver:main(Arguments),
    ok.

element_or_self(Term) when is_tuple(Term) -> element(1, Term);
element_or_self(Term) -> Term.

resolve({source, Relative}, SourceRoot, _GeneratedRoot) ->
    filename:join(SourceRoot, Relative);
resolve({generated, Relative}, _SourceRoot, GeneratedRoot) ->
    filename:join(GeneratedRoot, Relative).
