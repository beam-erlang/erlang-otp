%% SPDX-License-Identifier: Apache-2.0
-module(otp_unicode_contract).
-export([run/0]).

run() ->
    lists:foreach(fun encoding/1,
                  [utf16, {utf16,big}, {utf16,little}, utf32, {utf32,big}, {utf32,little}]),
    ok = check(nested(40000, [16#110000]), utf16),
    ok = check(nested(40000, [16#110000]), {utf32,little}),
    ok.

encoding(Encoding) ->
    Scalars = [0,127,128,255,256,16#D7FF,16#E000,16#FFFE,16#FFFF,16#10000,16#10FFFF],
    Encoded = unicode:characters_to_binary(Scalars, utf8, Encoding),
    Inputs = [Encoded, unaligned(Encoded), [unaligned(Encoded)], [], [0, [127, Encoded]], [Encoded | <<>>],
              [<<>>, [Encoded]], [-1], [16#D800], [16#110000], [1 bsl 100],
              [Encoded, bad], [bad], bad, [0|bad], <<1:1>>,
              <<0:(8191*8), 255, 255, 0>>, [<<0:(8191*8)>>, <<255,255,0>>]],
    lists:foreach(fun(Data) -> check(Data, Encoding) end, Inputs),
    lists:foreach(fun(Offset) ->
        <<A:Offset/binary, B/binary>> = Encoded,
        lists:foreach(fun(Data) -> check(Data, Encoding) end,
                      [[A,B], [A,[B]], [A|B], [[A],[],[B]], [A,0,B]])
    end, lists:seq(0, byte_size(Encoded))),
    lists:foreach(fun(Prefix) ->
        check(Prefix, Encoding),
        check([Prefix], Encoding),
        check([Prefix, []], Encoding)
    end, [<<0>>, <<255>>, <<254,255>>, <<254,255,0>>, <<255,255,0>>,
          <<216>>, <<216,0>>, <<216,0,220>>, <<0,216>>, <<0,216,0>>]),
    ok.

check(Data, Encoding) ->
    Expected = capture(fun() -> unicode:characters_to_binary_int(Data, Encoding) end),
    Expected = capture(fun() -> unicode:characters_to_binary(Data, Encoding) end),
    ExpectedList = list_result(Expected),
    ExpectedList = capture(fun() -> unicode:characters_to_list(Data, Encoding) end),
    ok.

capture(Fun) ->
    try Fun() catch error:Reason -> {raises,Reason} end.

list_result({raises,_}=Error) -> Error;
list_result({Tag,Prefix,Rest}) -> {Tag,unicode:characters_to_list(Prefix,utf8),Rest};
list_result(Binary) -> unicode:characters_to_list(Binary,utf8).

unaligned(Bytes) ->
    Container = <<0:3,Bytes/binary,0:5>>,
    Size = byte_size(Bytes),
    <<_:3,Unaligned:Size/binary,_:5>> = Container,
    Unaligned.

nested(0, Data) -> Data;
nested(N, Data) -> nested(N-1, [Data]).
