%% SPDX-License-Identifier: Apache-2.0
-module(otp_ldap_probe).
-export([run/1]).
-include_lib("eldap/include/eldap.hrl").

run(Certificate) ->
    {ok, _} = application:ensure_all_started(ssl),
    {ok, _} = application:ensure_all_started(eldap),
    %% The independently generated test CA certificate is an explicit trust
    %% anchor. Do not relax candidate verification defaults for upstream tests.
    TLS = [{verify, verify_peer}, {cacertfile, Certificate},
           {server_name_indication, "localhost"}],
    lists:foreach(fun(Mode) ->
        Options = case Mode of
            ldaps -> [{port, 9877}, {ssl, true}, {sslopts, TLS}];
            _ -> [{port, 9876}]
        end,
        {ok, Handle} = eldap:open(["localhost"], [{timeout, 5000} | Options]),
        try
            case Mode of
                start_tls -> ok = eldap:start_tls(Handle, TLS, 5000);
                _ -> ok
            end,
            {error, invalidCredentials} =
                eldap:simple_bind(Handle, "cn=Manager,dc=ericsson,dc=se", "incorrect"),
            ok = eldap:simple_bind(Handle, "cn=Manager,dc=ericsson,dc=se", "hejsan"),
            Base = "dc=ericsson,dc=se",
            ok = eldap:add(Handle, Base, [{"objectClass", ["dcObject", "organization"]},
                                        {"dc", ["ericsson"]}, {"o", ["OTP acceptance"]}]),
            DN = "cn=otp-client," ++ Base,
            ok = eldap:add(Handle, DN, [{"objectClass", ["person"]},
                                      {"cn", ["otp-client"]}, {"sn", ["Original"]}]),
            {ok, #eldap_search_result{entries=[#eldap_entry{object_name=DN}]}} =
                eldap:search(Handle, [{base, Base}, {filter, eldap:equalityMatch("cn", "otp-client")},
                                      {scope, eldap:wholeSubtree()}]),
            ok = eldap:modify(Handle, DN, [eldap:mod_replace("sn", ["Changed"])]),
            {ok, #eldap_search_result{entries=[#eldap_entry{attributes=Attributes}]}} =
                eldap:search(Handle, [{base, DN}, {filter, eldap:present("sn")},
                                      {scope, eldap:baseObject()}]),
            {"sn", ["Changed"]} = lists:keyfind("sn", 1, Attributes),
            ok = eldap:delete(Handle, DN),
            ok = eldap:delete(Handle, Base)
        after
            ok = eldap:close(Handle)
        end
    end, [plain, ldaps, start_tls]),
    ok = application:stop(eldap),
    ok = application:stop(ssl),
    io:format("LDAP product authentication, CRUD, verified LDAPS and STARTTLS passed.~n").
