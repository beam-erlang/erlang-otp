%% SPDX-License-Identifier: Apache-2.0
%% Interactive desktop smoke; close each application normally after exercising a control.
-module(otp_windows_gui).
-export([run/0]).
-include_lib("wx/include/wx.hrl").
run() ->
    try
        Name = os:getenv("OTP_GUI_APP"),
        case Name of
            "wx" -> basic_wx();
            _ ->
                {ok,Pid} = start(Name),
                Ref = monitor(process,Pid),
                io:format("GUI_READY ~s ~p~n",[Name,Pid]),
                receive {'DOWN',Ref,process,Pid,Why} ->
                    io:format("GUI_CLOSED ~s ~tp~n",[Name,Why]),
                    case Why of normal -> ok; shutdown -> ok; _ -> error({gui_exit,Why}) end
                after 600000 -> error(gui_timeout) end
        end,
        halt(0)
    catch C:R:S -> io:format(standard_error,"GUI_FAILED ~tp:~tp ~tp~n",[C,R,S]), halt(1) end.
start("observer") -> ok=observer:start(), {ok,whereis(observer)};
start("reltool") -> reltool:start();
start("debugger") -> debugger:start();
start("et") ->
    {ok,Pid}=et_viewer:start([{title,"Windows OTP ET"},{trace_global,false}]),
    Collector=et_viewer:get_collector_pid(Pid),
    {ok,_}=et_collector:report_event(Collector,10,client,server,"Windows event",[{value,42}]),
    {ok,1}=et_collector:get_table_size(Collector),
    {ok,Pid}.
basic_wx() ->
    W=wx:new(), F=wxFrame:new(W,-1,"Windows OTP wx",[{size,{480,220}}]),
    P=wxPanel:new(F),
    T=wxTextCtrl:new(P,1,[{value,"Edit this text"},{pos,{20,30}},{size,{380,40}}]),
    wxFrame:connect(F,close_window),
    true=wxFrame:show(F), io:format("GUI_READY wx~n"),
    receive #wx{event=#wxClose{}} ->
        io:format("GUI_TEXT ~tp~n",[wxTextCtrl:getValue(T)]),
        wxFrame:destroy(F), wx:destroy(), io:format("GUI_CLOSED wx normal~n")
    after 600000 -> error(gui_timeout) end.
