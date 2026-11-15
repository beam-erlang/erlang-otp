%% SPDX-License-Identifier: Apache-2.0
-module(otp_probe_tests).
-include_lib("eunit/include/eunit.hrl").

collections_test() ->
    ?assertEqual([1,2,3], lists:sort([3,1,2])),
    ?assertEqual(#{a => 1}, maps:from_list([{a,1}])),
    ?assertEqual({value,42}, element(1, queue:out(queue:in(42,queue:new())))).

unicode_test() ->
    Text = [16#03bb,16#1f642],
    ?assertEqual(Text, unicode:characters_to_list(unicode:characters_to_binary(Text))).

regex_test() ->
    ?assertEqual({match,[<<"123">>]}, re:run(<<"abc123">>, "[0-9]+", [{capture,first,binary}])).

compiler_warning_options_test() ->
    Path = filename:join(os:getenv("OTP_TEST_WORK"), "otp_warning_probe.erl"),
    Source = "-module(otp_warning_probe).\n-export([f/0]).\nf() -> 1 = 2.\n",
    Options = [binary, return_errors, return_warnings],
    try
        ok = file:write_file(Path, Source),
        {ok, otp_warning_probe, Unfiltered, Warnings} = compile:noenv_file(Path, Options),
        ?assert(Warnings =/= []),
        ?assertMatch({error, _, [_|_]}, compile:noenv_file(Path, [warnings_as_errors|Options])),
        {ok, otp_warning_probe, Filtered, []} =
            compile:noenv_file(Path, [nowarn_nomatch|Options]),
        %% Diagnostic selection must not change the generated program.
        {ok, otp_warning_probe, Before} = beam_lib:all_chunks(Unfiltered),
        {ok, otp_warning_probe, After} = beam_lib:all_chunks(Filtered),
        Execution = fun(Chunks) ->
            [{Name, Bytes} || {Name, Bytes} <- Chunks,
                lists:member(Name, ["Code","AtU8","ImpT","ExpT","LocT","LitT","FunT","StrT"])]
        end,
        ?assertEqual(Execution(Before), Execution(After)),
        CleanSource = "-module(otp_warning_probe).\n-export([f/0]).\nf() -> ok.\n",
        ok = file:write_file(Path, CleanSource),
        {ok, otp_warning_probe, _, []} =
            compile:noenv_file(Path, [warnings_as_errors|Options]),
        ok = file:write_file(Path, [CleanSource, "unused() -> ok.\n"]),
        {error, [], [{_, UnusedWarnings}]} =
            compile:noenv_file(Path, [warnings_as_errors, nowarn_nomatch|Options]),
        ?assert(lists:any(fun({_,erl_lint,{unused_function,{unused,0}}}) -> true;
                            (_) -> false end, UnusedWarnings)),
        ok = file:write_file(Path, "-module(otp_warning_probe).\nf() -> .\n"),
        ?assertMatch({error, [_|_], _},
                     compile:noenv_file(Path, [warnings_as_errors, nowarn_nomatch|Options]))
    after
        file:delete(Path)
    end.

stdlib_stack_source_basename_test() ->
    Root = filename:absname(os:getenv("OTP_TEST_ROOT")),
    lists:foreach(fun(Module) ->
        Beam = code:which(Module),
        ?assert(is_list(Beam)),
        ?assert(lists:prefix(Root ++ "/", filename:absname(Beam))),
        {module,Module} = code:ensure_loaded(Module)
    end, [lists,erl_error]),
    %% Ordinary compiler metadata remains available to inspection tools.
    CompileSource = proplists:get_value(source, lists:module_info(compile)),
    ?assert(is_list(CompileSource)),
    ?assertEqual("lists.erl", filename:basename(CompileSource)),
    %% Exercise the installed implementation and its real function-clause frame.
    Trace = try lists:reverse(34) of
        Returned -> erlang:error({missing_function_clause,Returned})
    catch error:function_clause:Frames -> Frames
    end,
    [{lists,reverse,[34],Location}|_] = Trace,
    Source = proplists:get_value(file, Location),
    ?assertEqual("lists.erl", Source),
    ?assertEqual(relative, filename:pathtype(Source)),
    Line = proplists:get_value(line, Location),
    ?assert(is_integer(Line) andalso Line > 0),
    Formatted = unicode:characters_to_binary(
        erl_error:format_exception(error,function_clause,Trace)),
    ?assertMatch({_,_}, binary:match(
        Formatted, <<"lists:reverse(34) (lists.erl:">>)).

ssh_crypto_public_api_test() ->
    %% Public fixed test scalars. The control is RFC 7748 section 6.1;
    %% the boundary peer hashes the ASCII label
    %% "otp-ssh-hybrid-leading-zero-peer-v1:" then counter 490 as four
    %% big-endian bytes. A checked integer ladder gives shared prefix 00 18.
    Root = filename:absname(os:getenv("OTP_TEST_ROOT")),
    lists:foreach(fun(Module) ->
        Path = code:which(Module),
        ?assert(is_list(Path)),
        ?assert(lists:prefix(Root ++ "/", filename:absname(Path))),
        {module,Module} = code:ensure_loaded(Module)
    end, [crypto,ssh]),
    {ok,_} = application:ensure_all_started(crypto),
    Kex = proplists:get_value(kex, ssh:default_algorithms(), []),
    ?assert(is_list(Kex) andalso Kex =/= []),
    Local = binary:decode_hex(<<"77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a">>),
    LocalPublic = binary:decode_hex(<<"8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a">>),
    {LocalPublic,_} = crypto:generate_key(ecdh,x25519,Local),
    Fixtures = [
        {control,
         <<"5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb">>,
         <<"de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f">>,
         <<"4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742">>},
        {leading_zero,
         <<"4deb0c7b731ad238d78fac4d7de038eaa80d6667ad6168d4ab9e777edc8376d1">>,
         <<"79fe492bbaf629e2bbb4d4312c29fd510c5cc912f344a1b9160df8bd7d1f2e47">>,
         <<"0018bb90812268ad832eadcc2720858527afb7bda2248cc2c9d3984f128ded34">>}],
    lists:foreach(fun({Label,PrivateHex,PublicHex,RawHex}) ->
        Private = binary:decode_hex(PrivateHex),
        Public = binary:decode_hex(PublicHex),
        ExpectedRaw = binary:decode_hex(RawHex),
        {Public,_} = crypto:generate_key(ecdh,x25519,Private),
        Raw = crypto:compute_key(ecdh,Public,Local,x25519),
        ?assertEqual(ExpectedRaw,Raw),
        ?assertEqual(32,byte_size(Raw)),
        ?assertEqual(Raw,crypto:compute_key(ecdh,LocalPublic,Private,x25519)),
        case Label of
            leading_zero ->
                <<0,Next,_/binary>> = Raw,
                ?assert(Next > 0 andalso Next < 128);
            control -> ok
        end
    end, Fixtures).
