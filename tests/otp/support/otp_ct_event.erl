%% The original suites and hooks remain responsible for test behavior.
%% This handler records raw events, including subordinate Mnesia test modules.
-module(otp_ct_event).
-behaviour(gen_event).
-include_lib("common_test/include/ct_event.hrl").
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

init([Path]) ->
    {ok, Io} = file:open(Path, [write, {encoding, utf8}]),
    ok = write_runtime(Path ++ ".runtime.json"),
    {ok, {Io, Path}}.

handle_event(#event{name=Name,node=Node,data=Data}, {Io, Path} = State) ->
    Row = #{event => normalize(Name), node => normalize(Node),
            data => normalize(Data), data_erlang => iolist_to_binary(io_lib:format("~0tp", [Data])),
            monotonic_us => erlang:monotonic_time(microsecond)},
    ok = io:put_chars(Io, [json:encode(Row), $\n]),
    case Name of
        stop_logging -> ok = write_runtime(Path ++ ".runtime-final.json");
        _ -> ok
    end,
    {ok, State}.

handle_call(_, State) -> {ok, ok, State}.
handle_info(_, State) -> {ok, State}.
terminate(_, {Io, _}) -> file:close(Io).
code_change(_, State, _) -> {ok, State}.

%% Observe the actual ct_run process without loading optional applications.
%% Only these selected startup arguments are retained; cookies are not logged.
write_runtime(Path) ->
    Type = os:type(),
    System = case Type of
        {unix, linux} -> <<"Linux">>;
        {unix, darwin} -> <<"Darwin">>;
        {win32, _} -> <<"Windows">>;
        _ -> normalize(Type)
    end,
    Facts = #{<<"format">> => 1, <<"node">> => normalize(node()),
        <<"vm_start_time">> => erlang:system_info(start_time),
        <<"root_dir">> => normalize(code:root_dir()),
        <<"erts_version">> => normalize(erlang:system_info(version)),
        <<"otp_release">> => normalize(erlang:system_info(otp_release)),
        <<"emu_flavor">> => normalize(erlang:system_info(emu_flavor)),
        <<"emu_type">> => normalize(erlang:system_info(emu_type)),
        <<"system_architecture">> => normalize(erlang:system_info(system_architecture)),
        <<"os_type">> => normalize(Type), <<"system_name">> => System,
        <<"schedulers">> => erlang:system_info(schedulers),
        <<"schedulers_online">> => erlang:system_info(schedulers_online),
        <<"dirty_cpu_schedulers">> => erlang:system_info(dirty_cpu_schedulers),
        <<"dirty_io_schedulers">> => erlang:system_info(dirty_io_schedulers),
        <<"sasl_started">> => lists:keymember(sasl, 1, application:which_applications()),
        <<"sasl_errlog_type">> => normalize(application:get_env(sasl, errlog_type)),
        <<"enabled_features">> => normalize(erl_features:enabled()),
        <<"boot_argument">> => normalize(init:get_argument(boot)),
        <<"epmd_port_argument">> => normalize(init:get_argument(epmd_port)),
        <<"home">> => normalize(os:getenv("HOME")),
        <<"dynamic_trace">> => normalize(erlang:system_info(dynamic_trace)),
        <<"lock_counting">> => erlang:system_info(lock_counting),
        <<"crypto_fips">> => loaded_fact(crypto, info_fips),
        <<"mnesia_debug_compiled">> => loaded_fact(mnesia_lib, is_debug_compiled)},
    file:write_file(Path, [json:encode(Facts), $\n]).

loaded_fact(Module, Function) ->
    case code:is_loaded(Module) of
        false -> <<"unobserved">>;
        _ -> case apply(Module, Function, []) of
                 true -> true;
                 false -> false;
                 Value -> normalize(Value)
             end
    end.

normalize(Term) when is_atom(Term) -> atom_to_binary(Term);
normalize(Term) when is_binary(Term) ->
    case unicode:characters_to_binary(Term) of
        Bin when is_binary(Bin) -> Bin;
        _ -> iolist_to_binary(io_lib:format("~0tp", [Term]))
    end;
normalize(Term) when is_number(Term) -> Term;
normalize(Term) when is_tuple(Term) -> [normalize(X) || X <- tuple_to_list(Term)];
normalize(Term) when is_list(Term) ->
    case split_list(Term, []) of
        {proper, Values} ->
            case io_lib:printable_unicode_list(Values) of
                true when Values =/= [] -> unicode:characters_to_binary(Values);
                _ -> [normalize(X) || X <- Values]
            end;
        {improper, Values, Tail} ->
            #{improper_list => [normalize(X) || X <- Values], tail => normalize(Tail)}
    end;
normalize(Term) when is_map(Term) ->
    %% Maps may have arbitrary Erlang keys. Preserve them as pairs.
    #{pairs => [[normalize(K), normalize(V)] || {K,V} <- maps:to_list(Term)]};
normalize(Term) -> iolist_to_binary(io_lib:format("~0tp", [Term])).

split_list([], Acc) -> {proper, lists:reverse(Acc)};
split_list([Head|Tail], Acc) -> split_list(Tail, [Head|Acc]);
split_list(Tail, Acc) -> {improper, lists:reverse(Acc), Tail}.
