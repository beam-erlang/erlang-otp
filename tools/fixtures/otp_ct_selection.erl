%% SPDX-License-Identifier: Apache-2.0
%% Inspect declarations in a separate installed VM before executing a suite.
-module(otp_ct_selection).
-export([write/3]).

write(Suite, Directory, Output) ->
    ok = filelib:ensure_dir(filename:join(Directory,"placeholder")),
    ok = file:set_cwd(Directory),
    ok = ct:install([{logdir,Directory}]),
    ct_util:start(Directory),
    Record = try
        Tree = ct_framework:get_suite(Suite,all),
        #{status => <<"resolved">>, tree => text(Tree),
          cases => cases(Suite,Tree,[])}
    catch
        Class:Reason -> #{status => <<"blocked">>, reason => text({Class,Reason})}
    after
        ct_util:stop(normal)
    end,
    ok = file:write_file(Output,json:encode(Record)).

cases(Suite, Tests, Groups) when is_list(Tests) ->
    lists:append([cases(Suite,Test,Groups) || Test <- Tests]);
cases(Suite, {conf,Properties,_Init,Tests,_End}, Groups) ->
    Name = proplists:get_value(name,Properties),
    cases(Suite,Tests,Groups ++ [#{name => text(Name), properties => text(Properties)}]);
cases(_Suite, {ct_framework,error_in_suite,Reason}, _Groups) ->
    error({error_in_suite,Reason});
cases(_Suite, {Module,Case}, Groups) when is_atom(Module), is_atom(Case) ->
    [#{suite => text(Module), name => text(Case), groups => Groups}];
cases(Suite, Case, Groups) when is_atom(Case) ->
    [#{suite => text(Suite), name => text(Case), groups => Groups}];
cases(_Suite, Other, _Groups) ->
    error({unsupported_selection,Other}).

text(Term) -> unicode:characters_to_binary(io_lib:format("~0tp",[Term])).
