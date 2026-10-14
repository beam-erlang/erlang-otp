%% SPDX-License-Identifier: Apache-2.0
-module(otp_wx_probe).
-export([run/0]).
-include_lib("wx/include/wx.hrl").
-include_lib("wx/include/gl.hrl").

run() ->
    State = os:getenv("OTP_WX_STATE"),
    Cycle = case file:read_file(State) of
        {error, enoent} -> 0;
        {ok, Bytes} -> binary_to_integer(Bytes)
    end,
    true = lists:prefix(code:root_dir(), code:which(wx)),
    Wx = wx:new(),
    Frame = wxFrame:new(Wx, -1, "OTP installed wx", [{size, {320, 240}}]),
    ok = wxFrame:connect(Frame, show),
    Panel = wxPanel:new(Frame),
    Text = wxTextCtrl:new(Panel, 1, [{value, "installed libbeam"}]),
    "installed libbeam" = wxTextCtrl:getValue(Text),
    ok = wxTextCtrl:setValue(Text, "edited value"),
    "edited value" = wxTextCtrl:getValue(Text),
    true = wxFrame:show(Frame),
    receive #wx{event = #wxShow{}} -> ok after 5000 -> error(no_show_event) end,
    Canvas = wxGLCanvas:new(Frame, [{attribList, [?WX_GL_RGBA, ?WX_GL_DOUBLEBUFFER, 0]}]),
    Context = wxGLContext:new(Canvas),
    true = wxGLCanvas:setCurrent(Canvas, Context),
    Vendor = gl:getString(?GL_VENDOR),
    Renderer = gl:getString(?GL_RENDERER),
    true = is_list(Vendor) andalso Vendor =/= [],
    true = is_list(Renderer) andalso Renderer =/= [],
    ok = gl:viewport(0, 0, 32, 32),
    ok = gl:clearColor(0.25, 0.5, 0.75, 1.0),
    ok = gl:clear(?GL_COLOR_BUFFER_BIT),
    ok = gl:finish(),
    0 = gl:getError(),
    true = wxGLCanvas:swapBuffers(Canvas),
    ok = wxGLContext:destroy(Context),
    ok = wxFrame:destroy(Frame),
    ok = wx:destroy(),
    io:format("wx product cycle ~p passed; GL ~s / ~s~n", [Cycle, Vendor, Renderer]),
    case Cycle of
        2 -> halt(0);
        _ -> ok = file:write_file(State, integer_to_binary(Cycle + 1)), init:restart()
    end.
