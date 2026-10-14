#!/usr/bin/env escript
%% SPDX-License-Identifier: Apache-2.0
%% Review deterministic ASN.1 helper naming without hiding raw BEAM differences.
-mode(compile).

main([Candidate, Reference, Output]) ->
    Files = filelib:wildcard(filename:join(
        [Candidate, "lib", "public_key-*", "ebin", "*.beam"])),
    Results = maps:from_list([compare(File, Candidate, Reference) || File <- Files]),
    ok = file:write_file(Output, json:encode(Results)).

compare(File, Candidate, Reference) ->
    Relative = string:prefix(File, Candidate ++ "/"),
    Other = filename:join(Reference, Relative),
    {FunctionsA, ExportsA, LabelsA} = inspect(File),
    {FunctionsB, ExportsB, LabelsB} = inspect(Other),
    %% Both graphs use the same number of refinement steps. A helper's label
    %% includes its full body and the previous labels of referenced helpers.
    %% Only generated internal_object_set_argument names are substituted.
    Rounds = max(map_size(LabelsA), map_size(LabelsB)) + 1,
    FinalA = refine(Rounds, FunctionsA, LabelsA),
    FinalB = refine(Rounds, FunctionsB, LabelsB),
    BodiesA = lists:sort([rename(F, FinalA) || F <- FunctionsA]),
    BodiesB = lists:sort([rename(F, FinalB) || F <- FunctionsB]),
    Result = #{
        function_bodies_equal => BodiesA =:= BodiesB,
        exports_equal => lists:sort(rename(ExportsA, FinalA)) =:=
                         lists:sort(rename(ExportsB, FinalB)),
        candidate_helpers => map_size(LabelsA),
        reference_helpers => map_size(LabelsB),
        candidate_functions_sha256 => hash(BodiesA),
        reference_functions_sha256 => hash(BodiesB)},
    {unicode:characters_to_binary(Relative), Result}.

inspect(File) ->
    {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}, {exports, Exports}]}} =
        beam_lib:chunks(File, [abstract_code, exports]),
    Functions = [erl_parse:map_anno(fun(_) -> 0 end, Form) ||
                 Form = {function, _, _, _, _} <- Forms],
    Helpers = maps:from_list([{Name, <<"internal-helper">>} ||
        {function, _, Name, _, _} <- Functions, helper(Name)]),
    {Functions, Exports, Helpers}.

helper(Name) ->
    case re:run(atom_to_list(Name),
                "^get(enc|dec)_internal_object_set_argument_[0-9]+$") of
        nomatch -> false;
        _ -> true
    end.

refine(0, _, Labels) -> Labels;
refine(N, Functions, Labels) ->
    Next = maps:from_list([{Name, hash(rename({Arity, Body}, Labels))} ||
        {function, _, Name, Arity, Body} <- Functions, helper(Name)]),
    refine(N - 1, Functions, Next).

rename(Term, Labels) when is_atom(Term) ->
    case maps:find(Term, Labels) of
        {ok, Label} -> {generated_internal_helper, Label};
        error -> Term
    end;
rename(Term, Labels) when is_tuple(Term) ->
    list_to_tuple([rename(V, Labels) || V <- tuple_to_list(Term)]);
rename([H | T], Labels) ->
    [rename(H, Labels) | rename(T, Labels)];
rename(Term, _) -> Term.

hash(Term) -> binary:encode_hex(crypto:hash(sha256, term_to_binary(Term)), lowercase).
