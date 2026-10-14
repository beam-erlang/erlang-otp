%% SPDX-License-Identifier: Apache-2.0
-module(otp_service).
-behaviour(gen_server).
-export([start_link/0, init/1, handle_call/3, handle_cast/2, terminate/2,
         compress/1, decompress/1]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    process_flag(trap_exit, true),
    {ok, Backend} = application:get_env(otp_service, backend),
    {ok, Listener} = gen_tcp:listen(0, [{inet_backend, Backend}, binary,
                                      {active, false}, {packet, 4},
                                      {send_timeout, 5000},
                                      {send_timeout_close, true},
                                      {ip, {127, 0, 0, 1}}]),
    {ok, Listener}.

handle_call(port, _From, Listener) ->
    {ok, {{127, 0, 0, 1}, Port}} = inet:sockname(Listener),
    {reply, Port, Listener};
handle_call({exchange, Path}, _From, Listener) ->
    {ok, Peer} = gen_tcp:accept(Listener, 5000),
    try
        {ok, Compressed} = gen_tcp:recv(Peer, 0, 5000),
        Bytes = decompress(Compressed),
        {ok, File} = file:open(Path, [raw, binary, read, write, exclusive]),
        Stored = try
            ok = file:write(File, Bytes),
            {ok, 0} = file:position(File, bof),
            {ok, Bytes} = file:read(File, byte_size(Bytes)),
            eof = file:read(File, 1),
            Bytes
        after
            ok = file:close(File)
        end,
        ok = gen_tcp:send(Peer, compress(Stored)),
        {reply, {ok, byte_size(Stored)}, Listener}
    after
        ok = gen_tcp:close(Peer)
    end.

handle_cast(Request, _Listener) -> erlang:error({unexpected_cast, Request}).

terminate(_Reason, Listener) -> ok = gen_tcp:close(Listener).

compress(Bytes) ->
    Stream = zlib:open(),
    try
        ok = zlib:deflateInit(Stream),
        try iolist_to_binary(zlib:deflate(Stream, Bytes, finish))
        after ok = zlib:deflateEnd(Stream)
        end
    after zlib:close(Stream)
    end.

decompress(Bytes) ->
    Stream = zlib:open(),
    try
        ok = zlib:inflateInit(Stream),
        try iolist_to_binary(zlib:inflate(Stream, Bytes))
        after ok = zlib:inflateEnd(Stream)
        end
    after zlib:close(Stream)
    end.
