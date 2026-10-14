#!/usr/bin/env escript
%% SPDX-License-Identifier: Apache-2.0
%% Run through an explicitly selected installation's escript.
-mode(compile).

main([Prefix, Output, SourceRoot, GeneratedRoot]) ->
    Files = filelib:wildcard(filename:join([Prefix, "**", "*.beam"])),
    Roots = [{SourceRoot, "$SOURCE"}, {GeneratedRoot, "$GENERATED"}],
    Results = maps:from_list([inspect(File, Prefix, Roots) || File <- Files]),
    ok = file:write_file(Output, json:encode(Results)).

inspect(File, Prefix, Roots) ->
    {ok, {Module, Chunks}} = beam_lib:chunks(File,
        [exports, imports, attributes, compile_info, abstract_code]),
    Info = proplists:get_value(compile_info, Chunks),
    Abstract = proplists:get_value(abstract_code, Chunks),
    NormalInfo = [case Pair of
        {source, Path} -> {source, normalize_path(Path, Roots)};
        {options, Options} -> {options, [case Option of
            {i, Path} -> {i, normalize_path(Path, Roots)};
            _ -> Option
        end || Option <- Options]};
        _ -> Pair
    end || Pair <- Info],
    NormalAbstract = case Abstract of
        {raw_abstract_v1, Forms} -> {raw_abstract_v1, [case Form of
            {attribute, Line, file, {Path, FileLine}} ->
                {attribute, Line, file, {normalize_path(Path, Roots), FileLine}};
            _ -> Form
        end || Form <- Forms]};
        _ -> Abstract
    end,
    Literals = literals(File),
    FunctionBodies = case Abstract of
        {raw_abstract_v1, FunctionForms} ->
            Bodies = lists:sort([erl_parse:map_anno(fun(_) -> 0 end,
                source_file_ast(Form, Roots)) || Form = {function,_,_,_,_} <- FunctionForms]),
            [{annotation_free_functions_sha256,
              hex(crypto:hash(sha256, term_to_binary(Bodies)))}];
        _ -> []
    end,
    Fields = [{module, Module} | proplists:delete(abstract_code, Chunks)] ++
        [{attributes_without_vsn,
          proplists:delete(vsn, proplists:get_value(attributes, Chunks))}] ++
        [{attributes_without_build_metadata,
          [case Attribute of
              {asn1_info, Properties} -> {asn1_info, proplists:delete(options, Properties)};
              _ -> Attribute
           end || Attribute <- proplists:delete(vsn, proplists:get_value(attributes, Chunks))]}] ++
        [{path_normalized_compile_info, NormalInfo},
         {abstract_code_sha256, hex(crypto:hash(sha256, term_to_binary(Abstract)))},
         {path_normalized_abstract_code_sha256,
          hex(crypto:hash(sha256, term_to_binary(NormalAbstract)))},
         {literal_terms, Literals},
         {source_file_literal_sha256, hex(crypto:hash(sha256,
              term_to_binary(source_file_literals(Literals, Roots))))}] ++ FunctionBodies,
    Relative = string:prefix(File, Prefix ++ "/"),
    {ok, Bytes} = file:read_file(File),
    Record = maps:from_list([{Name, unicode:characters_to_binary(io_lib:format("~tp.", [Value]))}
                            || {Name, Value} <- Fields]),
    {unicode:characters_to_binary(Relative),
     Record#{sha256 => hex(crypto:hash(sha256, Bytes))}}.

normalize_path(Path, []) -> Path;
normalize_path(Path, [{Root, Label} | Rest]) ->
    case string:prefix(Path, Root ++ "/") of
        nomatch -> normalize_path(Path, Rest);
        Suffix -> Label ++ "/" ++ Suffix
    end.

%% Logger location maps embed ?FILE. Compare only that named field using the
%% basename emitted by upstream's per-source-directory compiler invocation.
%% Other string literals, map fields and the raw literal table remain intact.
source_file_literals(Term, Roots) when is_map(Term) ->
    maps:map(fun
        (file, Path) when is_list(Path) ->
            case normalize_path(Path, Roots) of
                Path -> Path;
                _ -> filename:basename(Path)
            end;
        (_, Value) -> source_file_literals(Value, Roots)
    end, Term);
source_file_literals(Term, Roots) when is_tuple(Term) ->
    list_to_tuple([source_file_literals(V, Roots) || V <- tuple_to_list(Term)]);
source_file_literals([H | T], Roots) ->
    [source_file_literals(H, Roots) | source_file_literals(T, Roots)];
source_file_literals(Term, _) -> Term.

%% Apply the same named source-file-literal comparison to abstract functions.
%% Keep the raw abstract hashes and literal table independent of this projection.
source_file_ast({Kind,Anno,{atom,KeyAnno,file},{string,ValueAnno,Path}}, Roots)
  when Kind =:= map_field_assoc; Kind =:= map_field_exact ->
    Value = case normalize_path(Path, Roots) of
        Path -> Path;
        _ -> filename:basename(Path)
    end,
    {Kind,Anno,{atom,KeyAnno,file},{string,ValueAnno,Value}};
source_file_ast(Term, Roots) when is_tuple(Term) ->
    list_to_tuple([source_file_ast(Value,Roots) || Value <- tuple_to_list(Term)]);
source_file_ast([H|T], Roots) ->
    [source_file_ast(H,Roots)|source_file_ast(T,Roots)];
source_file_ast(Term, _) -> Term.

hex(Bytes) -> binary:encode_hex(Bytes, lowercase).

literals(File) ->
    case beam_lib:chunks(File, ["LitT"]) of
        {ok, {_, [{"LitT", <<Size:32, Payload/binary>>}]}} ->
            Decoded = case Size of
                0 -> Payload;
                _ -> zlib:uncompress(Payload)
            end,
            <<Count:32, Data/binary>> = Decoded,
            parse_literals(Count, Data);
        {error, beam_lib, {missing_chunk, _, "LitT"}} -> []
    end.

parse_literals(0, <<>>) -> [];
parse_literals(Count, <<Size:32, Term:Size/binary, Rest/binary>>) ->
    [binary_to_term(Term) | parse_literals(Count - 1, Rest)].
