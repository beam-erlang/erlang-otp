%% SPDX-License-Identifier: Apache-2.0
-module(otp_odbc_probe).
-export([run/0]).

run() ->
    State = os:getenv("OTP_ODBC_STATE"),
    Cycle = case file:read_file(State) of
        {error, enoent} -> 0;
        {ok, Bytes} -> binary_to_integer(Bytes)
    end,
    {ok, [odbc]} = application:ensure_all_started(odbc),
    true = lists:prefix(code:root_dir(), code:which(odbc)),
    {ok, Connection} = odbc:connect(os:getenv("OTP_ODBC_CONNECTION"), [{auto_commit, off}]),
    {updated, _} = odbc:sql_query(Connection, "CREATE TABLE otp_product (id integer, value varchar(80))"),
    {updated, 1} = odbc:param_query(Connection, "INSERT INTO otp_product VALUES (?, ?)",
        [{sql_integer, [42]}, {{sql_varchar, 80}, ["installed libbeam"]}]),
    ok = odbc:commit(Connection, commit),
    {selected, ["id", "value"], [{42, "installed libbeam"}]} =
        odbc:sql_query(Connection, "SELECT id, value FROM otp_product"),
    {updated, 1} = odbc:sql_query(Connection, "UPDATE otp_product SET id=43"),
    ok = odbc:commit(Connection, rollback),
    {selected, ["id"], [{42}]} = odbc:sql_query(Connection, "SELECT id FROM otp_product"),
    {updated, _} = odbc:sql_query(Connection, "DROP TABLE otp_product"),
    ok = odbc:commit(Connection, commit),
    ok = odbc:disconnect(Connection),
    ok = application:stop(odbc),
    undefined = whereis(odbc_sup),
    io:format("ODBC product cycle ~p passed~n", [Cycle]),
    case Cycle of
        2 -> halt(0);
        _ -> ok = file:write_file(State, integer_to_binary(Cycle + 1)), init:restart()
    end.
