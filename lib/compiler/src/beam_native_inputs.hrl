%% SPDX-License-Identifier: Apache-2.0
%% Explicit Core and assembly calls retain public dispatch. Language BIF and
%% instruction forms carry their separate execution semantics into assembly.
native_core_calls(Core, #compile{options=Opts}=St) ->
    Attrs = cerl:module_attrs(Core),
    case lists:any(fun({K,_}) -> cerl:concrete(K) =:= beam_native_calls end,Attrs) of
        true -> {ok,Core,St};
        false ->
            S0 = #{next=>0,aliases=>[],bindings=>proplists:get_value(
                       beam_native_bindings,Opts,native_default_bindings())},
            ok = native_validate_bindings(maps:get(bindings,S0)),
            {Defs,S} = lists:mapfoldl(fun({V,F},S1) ->
                {F1,S2} = native_core_tree(F,body,S1), {{V,F1},S2}
            end,S0,cerl:module_defs(Core)),
            Attr = {cerl:c_atom(beam_native_calls),cerl:abstract(maps:get(aliases,S))},
            Code = cerl:update_c_module(Core,cerl:module_name(Core),
                                       cerl:module_exports(Core),[Attr|Attrs],Defs),
            {ok,Code,St}
    end.

native_core_tree(T,Mode,S0) ->
    case cerl:type(T) of
        literal -> {T,S0};
        var -> {T,S0};
        clause ->
            {Ps,S1} = native_core_list(cerl:clause_pats(T),guard,S0),
            {G,S2} = native_core_tree(cerl:clause_guard(T),guard,S1),
            {B,S} = native_core_tree(cerl:clause_body(T),Mode,S2),
            {cerl:update_c_clause(T,Ps,G,B),S};
        call ->
            {[M,F|Args],S1} = native_core_list(
                [cerl:call_module(T),cerl:call_name(T)|cerl:call_args(T)],Mode,S0),
            case cerl:is_c_atom(M) andalso cerl:is_c_atom(F) of
                true ->
                    Mod = cerl:concrete(M), Name = cerl:concrete(F), A = length(Args),
                    {Kind,ID,Target} = case Mode of
                        body -> {public,undefined,'$beam_public'};
                        guard ->
                            {Contract,_} = native_guard_target(Mod,Name,A,maps:get(bindings,S1)),
                            {guard,Contract,erlang}
                    end,
                    {Alias,S} = native_alias(Kind,Mod,Name,A,ID,S1),
                    {cerl:update_c_call(T,cerl:c_atom(Target),cerl:c_atom(Alias),Args),S};
                false ->
                    Opaque = cerl:c_call(cerl:c_atom('$beam_public'),
                                         cerl:c_atom(identity),[M]),
                    {cerl:update_c_call(T,Opaque,F,Args),S1}
            end;
        map ->
            {Arg,S1} = native_core_tree(cerl:map_arg(T),Mode,S0),
            {Pairs,S} = native_core_list(cerl:map_es(T),Mode,S1),
            {cerl:update_c_map(T,Arg,Pairs),S};
        record ->
            {Arg,S1} = native_core_tree(cerl:record_arg(T),Mode,S0),
            {Id,S2} = native_core_tree(cerl:record_id(T),Mode,S1),
            {Es,S} = native_core_list(cerl:record_es(T),Mode,S2),
            {cerl:update_c_record(T,Arg,Id,Es),S};
        record_pair ->
            {[Key,Value],S} = native_core_list(
                [cerl:record_pair_key(T),cerl:record_pair_val(T)],Mode,S0),
            {cerl:update_c_record_pair(T,Key,Value),S};
        _ ->
            {Groups,S} = lists:mapfoldl(fun(G,S1) -> native_core_list(G,Mode,S1) end,
                                       S0,cerl:subtrees(T)),
            {cerl:update_tree(T,Groups),S}
    end.

native_core_list(Ts,Mode,S) ->
    lists:mapfoldl(fun(T,S1) -> native_core_tree(T,Mode,S1) end,S,Ts).

native_assembly_calls({M,E,A,Fs,L},St) ->
    native_assembly_calls({M,E,A,#{},Fs,L},St);
native_assembly_calls({M,E,A,Anno,Fs,L}=Code,St) ->
    case proplists:is_defined(beam_native_calls,A) of
        true -> {ok,Code,St};
        false ->
            {Fs1,S} = native_assembly_tree(Fs,#{next=>0,aliases=>[]}),
            {ok,{M,E,[{beam_native_calls,maps:get(aliases,S)}|A],Anno,Fs1,L},St}
    end.

native_assembly_tree({extfunc,M,F,A},S0) ->
    {Alias,S} = native_alias(public,M,F,A,undefined,S0),
    {{extfunc,'$beam_public',Alias,A},S};
native_assembly_tree({literal,_}=T,S) -> {T,S};
native_assembly_tree(T,S0) when is_tuple(T) ->
    {Es,S} = native_assembly_tree(tuple_to_list(T),S0), {list_to_tuple(Es),S};
native_assembly_tree(T,S) when is_list(T) ->
    lists:mapfoldl(fun native_assembly_tree/2,S,T);
native_assembly_tree(T,S) -> {T,S}.
