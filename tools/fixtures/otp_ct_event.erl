%% SPDX-License-Identifier: Apache-2.0
%% Observe terminal Common Test events without changing suite callbacks.
-module(otp_ct_event).
-behaviour(gen_event).
-include_lib("common_test/include/ct_event.hrl").
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

init([Path]) ->
    {ok, File} = file:open(Path, [write, binary]),
    ok = emit(File, #{event => <<"handler_start">>}),
    {ok, File}.

handle_event(#event{name = Event, data = {Suite, Case, Result}}, File)
  when Event =:= tc_done; Event =:= tc_user_skip; Event =:= tc_auto_skip ->
    Status = case {Event, Result} of
        {tc_user_skip, _} -> <<"user_skipped">>;
        {tc_auto_skip, _} -> <<"auto_skipped">>;
        {tc_done, ok} -> <<"passed">>;
        {tc_done, {skipped, _}} -> <<"user_skipped">>;
        {tc_done, {auto_skipped, _}} -> <<"auto_skipped">>;
        _ -> <<"failed">>
    end,
    Name = case Case of
        Tuple when is_tuple(Tuple) -> element(1,Tuple);
        _ -> Case
    end,
    Configuration = lists:member(Name,[init_per_suite,end_per_suite,
                                        init_per_group,end_per_group]),
    ok = emit(File, #{event => atom_to_binary(Event), suite => text(Suite),
        name => text(Name), context => text(Case), configuration => Configuration,
        status => Status, reason => text(Result)}),
    {ok, File};
handle_event(_, File) -> {ok, File}.

handle_call(_, File) -> {ok, ok, File}.
handle_info(_, File) -> {ok, File}.
code_change(_, File, _) -> {ok, File}.
terminate(_, File) ->
    ok = emit(File, #{event => <<"handler_stop">>}),
    file:close(File).

text(Term) -> unicode:characters_to_binary(io_lib:format("~0tp",[Term])).
emit(File, Record) -> file:write(File,[json:encode(Record),$\n]).
