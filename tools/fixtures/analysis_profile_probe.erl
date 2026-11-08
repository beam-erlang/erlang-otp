%% SPDX-License-Identifier: Apache-2.0
-module(analysis_profile_probe).
-export([run/1]).

run(Directory) ->
    Source = filename:join(Directory, "analysis_subject.erl"),
    ok = subject(Source, "", "erlang:is_integer(X)"),
    [{erlang,is_integer,1}] = calls(Source, []),
    [{'$beam_public',_,1}] = calls(Source, [{beam_native_bindings,[]}]),
    [{erlang,is_float,1}] = calls(Source,
        [{beam_native_bindings,[{vm_is_float_1,erlang,is_integer,1}]}]),
    ok = subject(Source, "", "custom:check(X)"),
    [{erlang,is_integer,1}] = calls(Source,
        [{beam_native_bindings,[{vm_is_integer_1,custom,check,1}]}]),
    [{'$beam_public',_,1}] = calls(Source,
        [{beam_native_bindings,[{bytes_referenced_size_modern_1,custom,check,1}]}]),
    ok = subject(Source, "", "ordinary:identity(X)"),
    [{ordinary,identity,1}] = calls(Source, [{beam_native_bindings,[]}]),
    ok = subject(Source, "-compile({beam_native_bindings,[]}).\n",
                 "erlang:is_integer(X)"),
    [{'$beam_public',_,1}] = calls(Source, []),
    ok = file:delete(Source),
    ok = file:delete(filename:rootname(Source) ++ ".beam"),
    io:put_chars("ANALYSIS_PROFILES_OK\n").

subject(Path, Options, Expression) ->
    file:write_file(Path, ["-module(analysis_subject).\n-export([run/1]).\n",
                          Options, "run(X) -> ", Expression, ".\n"]).

calls(Source, Options) ->
    {ok,Core} = dialyzer_utils:get_core_from_src(Source, Options),
    {ok,analysis_subject} = compile:file(Source,
        [debug_info,{outdir,filename:dirname(Source)}]),
    {ok,BeamCore} = dialyzer_utils:get_core_from_beam(
        filename:rootname(Source) ++ ".beam", Options),
    Calls = core_calls(Core),
    Calls = core_calls(BeamCore),
    Calls.

core_calls(Core) ->
    [{_,Fun}] = [{V,F} || {V,F} <- cerl:module_defs(Core),
                          cerl:var_name(V) =:= {run,1}],
    cerl_trees:fold(fun(T, Acc) ->
        case cerl:type(T) of
            call -> [{cerl:concrete(cerl:call_module(T)),
                      cerl:concrete(cerl:call_name(T)),
                      cerl:call_arity(T)} | Acc];
            _ -> Acc
        end
    end, [], Fun).
