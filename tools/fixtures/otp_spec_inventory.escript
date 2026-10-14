%% SPDX-License-Identifier: Apache-2.0
%% Resolve retained specifications with the installed Common Test implementation.
-mode(compile).

main([Source0, Output]) ->
    Source = filename:absname(Source0),
    Directories = filelib:wildcard(filename:join([Source,"lib","*","test"])) ++
        [filename:join([Source,"erts","test"]),
         filename:join([Source,"erts","emulator","test"]),
         filename:join([Source,"erts","epmd","test"])],
    Specs = lists:sort(lists:append([
        filelib:wildcard(filename:join(D,"*.spec")) ++
        filelib:wildcard(filename:join(D,"*.dynspec")) || D <- Directories])),
    Bindings = [{'TestCCompiler',{gnuc,undefined}}, {'Os',"Unix"}],
    Rows = [read_spec(S, Source, Bindings) || S <- Specs],
    ok = file:write_file(Output, json:encode(#{specifications => Rows})).

read_spec(Path, Source, Bindings) ->
    Base = #{path => text(relative(Path, Source))},
    case filename:extension(Path) of
        ".dynspec" ->
            case file:script(Path, Bindings) of
                {ok, Terms} -> Base#{kind => <<"dynamic">>,
                    bindings => text(format(Bindings)),
                    terms => text(format(Terms)), status => <<"resolved">>};
                Error -> Base#{kind => <<"dynamic">>, status => <<"blocked">>,
                               reason => text(format(Error))}
            end;
        ".spec" ->
            case ct_testspec:get_tests([Path]) of
                {ok, Selections} ->
                    Nodes = lists:append([N || {_,N} <- Selections]),
                    Base#{kind => <<"static">>, status => <<"resolved">>,
                        nodes => [#{node => text(atom_to_list(Node)),
                            run => [#{directory => text(relative(Dir,Source)),
                                      suite => text(format(Suite)),
                                      selection => text(format(Cases))}
                                    || {Dir,Suite,Cases} <- Run],
                            skips => [text(format(normalize(Skip,Source))) || Skip <- Skips],
                            skip_selections => [skip_selection(Skip,Source) || Skip <- Skips]}
                            || {Node,Run,Skips} <- Nodes]};
                Error -> Base#{kind => <<"static">>, status => <<"blocked">>,
                               reason => text(format(Error))}
            end
    end.

skip_selection({Directory,Suite,Reason},Source) ->
    #{directory=>text(relative(Directory,Source)), suite=>text(format(Suite)),
      selection=><<"all">>, reason=>text(format(Reason)), kind=><<"suite">>};
skip_selection({Directory,Suite,Cases,Reason},Source) ->
    #{directory=>text(relative(Directory,Source)), suite=>text(format(Suite)),
      selection=>text(format(Cases)), reason=>text(format(Reason)), kind=><<"cases">>}.

normalize(Tuple, Source) when is_tuple(Tuple) ->
    list_to_tuple([normalize(X,Source) || X <- tuple_to_list(Tuple)]);
normalize([$/|_]=Path, Source) -> relative(Path,Source);
normalize(Value, _) -> Value.

relative(Path, Source) ->
    Prefix = Source ++ "/",
    case lists:prefix(Prefix,Path) of
        true -> lists:nthtail(length(Prefix),Path);
        false -> Path
    end.

text(Value) -> unicode:characters_to_binary(Value).
format(Value) -> lists:flatten(io_lib:format("~0tp",[Value])).
