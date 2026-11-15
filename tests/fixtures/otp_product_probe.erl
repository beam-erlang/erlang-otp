%% SPDX-License-Identifier: Apache-2.0
-module(otp_product_probe).
-export([run/0]).

run() ->
    lists:foreach(fun({Name, Check}) ->
        io:format("Checking installed ~p~n", [Name]),
        ok = Check()
    end, [{dialyzer, fun dialyzer/0}, {edoc, fun edoc/0},
          {eldap, fun eldap/0}, {diameter, fun diameter/0},
          {megaco, fun megaco/0}, {reltool, fun reltool/0},
          {tftp, fun tftp/0}, {odbc, fun odbc/0}]),
    io:put_chars("otp-product-applications-ok\n").

sample() ->
    Source = filename:join(os:getenv("OTP_TEST_WORK"), "otp_product_sample.erl"),
    ok = file:write_file(Source,
        "-module(otp_product_sample).\n-export([value/0]).\n"
        "-spec value() -> integer().\nvalue() -> 42.\n"),
    Source.

dialyzer() ->
    Source = sample(),
    Output = filename:join(os:getenv("OTP_TEST_WORK"), "dialyzer"),
    ok = file:make_dir(Output),
    {ok,otp_product_sample} = compile:noenv_file(Source,[debug_info,{outdir,Output}]),
    Beam = filename:join(Output, "otp_product_sample.beam"),
    Plt = filename:join(Output, "sample.plt"),
    %% The one-module PLT has no ERTS entries for generated module_info calls.
    %% Keep other analysis warnings enabled and require none for this sample.
    [] = dialyzer:run([{analysis_type,plt_build},{files,[Beam]},
                       {output_plt,Plt},{check_plt,false},{get_warnings,true},
                       {warnings,[no_unknown]}]),
    {ok,[{files,Files}]} = dialyzer:plt_info(Plt),
    true = lists:member(Beam,Files),
    ok.

edoc() ->
    Output = filename:join(os:getenv("OTP_TEST_WORK"), "edoc"),
    ok = edoc:files([sample()],[{dir,Output}]),
    {ok,Html} = file:read_file(filename:join(Output,"otp_product_sample.html")),
    true = byte_size(Html) > 0,
    {ok,Css} = file:read_file(filename:join(Output,"stylesheet.css")),
    {ok,Css} = file:read_file(filename:join(code:priv_dir(edoc),"stylesheet.css")),
    ok.

eldap() ->
    {control,"1.2.840.113556.1.4.319",true,Bytes} =
        eldap:paged_result_control(10,"private-cookie"),
    {ok,{'RealSearchControlValue',10,"private-cookie"}} =
        'ELDAPv3':decode('RealSearchControlValue',Bytes),
    {present,"cn"} = eldap:present("cn"),
    ok.

diameter() ->
    {ok,_} = application:ensure_all_started(diameter),
    try
        0 = diameter_gen_base_rfc6733:id(),
        [] = diameter:services(),
        Id = diameter:session_id("otp-product-probe"),
        true = is_list(Id),
        ok
    after application:stop(diameter) end.

megaco() ->
    Text = <<"MEGACO/1 [127.0.0.1]\nTransaction = 1 { Context = - { "
             "ServiceChange = root { Services { Method = Restart, "
             "Reason = \"901\" } } } }">>,
    {ok,Message} = megaco_pretty_text_encoder:decode_message([],Text),
    {ok,Encoded} = megaco_pretty_text_encoder:encode_message([],Message),
    {ok,Message} = megaco_pretty_text_encoder:decode_message([],iolist_to_binary(Encoded)),
    {ok,Binary} = megaco_binary_encoder:encode_message([],Message),
    {ok,Message} = megaco_binary_encoder:decode_message([],iolist_to_binary(Binary)),
    ok.

reltool() ->
    {ok,Server} = reltool:start_server([{sys,[{root_dir,code:root_dir()}]}]),
    try
        {ok,{sys,Options}} = reltool:get_config(Server),
        true = is_list(Options),
        ok
    after ok = reltool:stop(Server) end.

tftp() ->
    {ok,_} = application:ensure_all_started(tftp),
    Root = filename:join(os:getenv("OTP_TEST_WORK"),"tftp"),
    ok = file:make_dir(Root),
    Bytes = <<"private installed TFTP transfer">>,
    ok = file:write_file(filename:join(Root,"sample.txt"),Bytes),
    {ok,Daemon} = tftp:start([{port,0},{udp,[{ip,{127,0,0,1}}]},
        {callback,{"",tftp_file,[{root_dir,Root}]}}]),
    try
        {ok,Options} = tftp:info(Daemon),
        Port = proplists:get_value(port,Options),
        {ok,Bytes} = tftp:read_file("sample.txt",binary,
                                  [{host,{127,0,0,1}},{port,Port}]),
        ok
    after
        unlink(Daemon),
        exit(Daemon,shutdown),
        application:stop(tftp)
    end.

odbc() ->
    {ok,_} = application:ensure_all_started(odbc),
    try
        %% A private missing DSN reaches the selected native manager without a DB.
        {error,{"IM002",_,_}} = odbc:connect("DSN=otp_product_probe_missing_dsn;",
            [{extended_errors,on},{timeout,5000}]),
        ok
    after application:stop(odbc) end.
