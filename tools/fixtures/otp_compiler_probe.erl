%% SPDX-License-Identifier: Apache-2.0
-module(otp_compiler_probe).
-export([run/0]).

run() ->
    Values = [N * 2 || N <- lists:seq(1, 6)],
    #{total := Result} = #{total => lists:sum(Values)},
    ok = native_call_inputs(),
    ok = evaluator_entry(),
    Result.

evaluator_entry() ->
    {ok,Tokens,_} = erl_scan:string("fun() -> erlang:put(expr_entry_probe,42) end."),
    {ok,[Expr]} = erl_parse:parse_exprs(Tokens),
    {value,Fun,[]} = erl_eval:expr(Expr,[]),
    undefined = Fun(),
    42 = erase(expr_entry_probe),
    {integer,1,42} = erl_eval:partial_eval({op,1,'*',{integer,1,6},{integer,1,7}}),
    {ok,LiteralTokens,_} = erl_scan:string("<0.0.0>.",1,[text]),
    {ok,LiteralPid} = erl_eval:extended_parse_term(LiteralTokens),
    true = is_pid(LiteralPid),
    ok.

native_call_inputs() ->
    Source = [{attribute,1,module,otp_native_source},
              {attribute,2,export,[{value,0}]},
              {function,3,value,0,[{clause,3,[],[],[
                  {call,3,{remote,3,{atom,3,erlang},{atom,3,is_float}},[{float,3,1.0}]}]}]}],
    {ok,otp_native_source,SourceBytes,[]} = compile:noenv_forms(Source,
        [binary,deterministic,return_errors,return_warnings]),
    ok = public_float_import(SourceBytes),
    Function = cerl:c_var({value,0}),
    Core = cerl:c_module(cerl:c_atom(otp_native_core),[Function],[],
        [{Function,cerl:c_fun([],cerl:c_call(cerl:c_atom(erlang),
                                           cerl:c_atom(is_float),[cerl:c_float(1.0)]))}]),
    {ok,otp_native_core,CoreBytes,[]} = compile:noenv_forms(Core,
        [from_core,binary,deterministic,return_errors,return_warnings]),
    ok = public_float_import(CoreBytes),
    Asm = {otp_native_assembly,[{value,0}],[],#{},
           [{function,value,0,2,[{label,1},
             {func_info,{atom,otp_native_assembly},{atom,value},0},{label,2},
             {move,{float,1.0},{x,0}},
             {call_ext_only,1,{extfunc,erlang,is_float,1}}]}],3},
    {ok,otp_native_assembly,AsmBytes,[]} = compile:noenv_forms(Asm,
        [from_asm,binary,deterministic,return_errors,return_warnings]),
    ok = public_float_import(AsmBytes),
    ok.

public_float_import(Bytes) ->
    {ok,{_,[{imports,Imports}]}} = beam_lib:chunks(Bytes,[imports]),
    true = lists:member({erlang,is_float,1},Imports),
    [] = [MFA || MFA={'$beam_public',_,_} <- Imports],
    ok.
