%% SPDX-License-Identifier: Apache-2.0
%% Erlang-term and BEAM validation; all build work belongs to CMake.
-module(otp_application_validator).
-export([run/0, migrate/0]).

run() ->
    try validate(init:get_plain_arguments()) of
        ok -> halt(0)
    catch Class:Reason:Stack ->
        io:format(standard_error, "OTP application validation failed: ~tp:~tp~n~tp~n",
                  [Class, Reason, Stack]),
        halt(1)
    end.

%% One-time metadata conversion for builds made by the former driver. CMake
%% remains responsible for removing obsolete leaves from this owned-file list.
migrate() ->
    try
        [Out, Receipt] = init:get_plain_arguments(),
        {ok, [Previous]} = file:consult(filename:join(Out, "build.term")),
        Artifacts = [unicode:characters_to_binary(filename:basename(File)) ||
                     File <- maps:get(artifacts, Previous, [])],
        ok = file:write_file(Receipt, [json:encode(Artifacts), $\n]),
        halt(0)
    catch Class:Reason:Stack ->
        io:format(standard_error, "OTP build record migration failed: ~tp:~tp~n~tp~n",
                  [Class, Reason, Stack]),
        halt(1)
    end.

validate([App, Version, Out | Sources]) ->
    Name = list_to_atom(App),
    Modules = lists:map(fun(Source) ->
        Module = list_to_atom(filename:basename(Source, ".erl")),
        Beam = filename:join(Out, atom_to_list(Module) ++ ".beam"),
        {ok, {Module, _}} = beam_lib:chunks(Beam, [exports]),
        Module
    end, Sources),
    true = length(Modules) =:= length(lists:usort(Modules)),
    {ok, [{application, Name, Properties}]} = file:consult(filename:join(Out, App ++ ".app")),
    {modules, Declared} = lists:keyfind(modules, 1, Properties),
    case Declared -- Modules of
        [] -> ok;
        Missing -> error({unbuilt_application_modules, App, Missing})
    end,
    Record = #{application => Name, version => Version, compiler => code:which(compile),
               dependencies => [], sources => Sources, modules => lists:sort(Modules),
               artifacts => [filename:join(Out, atom_to_list(M) ++ ".beam") || M <- Modules]},
    file:write_file(filename:join(Out, "build.term"), io_lib:format("~tp.~n", [Record])).
