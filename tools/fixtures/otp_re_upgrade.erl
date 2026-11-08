%% SPDX-License-Identifier: Apache-2.0
-module(otp_re_upgrade).
-export([run/1]).

run(InvalidLoad)->
    ok=otp_re_test:load("otp_re_test"),
    {module,re}=code:ensure_loaded(re),
    erlang:garbage_collect(),
    Baseline=maps:with([bytes,allocations,resources],otp_re_test:stats()),
    ok=checks(InvalidLoad),
    erlang:garbage_collect(),
    await(fun()->maps:with([bytes,allocations,resources],otp_re_test:stats())==Baseline end),
    await(fun()->maps:get(owners,otp_re_test:stats())==1 end),
    ok.

checks(InvalidLoad)->
    {re,Bytes,Filename}=code:get_object_code(re),
    Sticky=code:is_sticky(re),true=code:unstick_mod(re),
    try
        {ok,Pattern}=re:compile(<<"(?<x>a)">>),
        {module,re}=code:load_binary(re,Filename,Bytes),
        {namelist,[<<"x">>]}=re:inspect(Pattern,namelist),
        {match,[<<"a">>]}=re:run(<<"a">>,Pattern,[{capture,[x],binary}]),
        true=code:soft_purge(re),
        await(fun()->maps:get(owners,otp_re_test:stats())==1 end),
        lists:foreach(fun(Stage)->
            Before=maps:get(owners,otp_re_test:stats()),
            0=otp_re_test:fail_upgrade(Stage),
            {error,on_load_failure}=code:load_binary(re,Filename,Bytes),
            match=re:run(<<"a">>,Pattern,[{capture,none}]),
            true=code:soft_purge(re),
            Before=maps:get(owners,otp_re_test:stats())
        end,[1,2,3]),
        true=register(otp_re_upgrade_observer,self()),
        try
            {error,on_load_failure}=code:load_binary(re,"invalid-load-info",InvalidLoad),
            receive
                {invalid_re_load,{error,{upgrade,"Library upgrade-call unsuccessful (-1)."}}}->ok
            after 1000->error(missing_load_info_veto)
            end
        after unregister(otp_re_upgrade_observer) end,
        match=re:run(<<"a">>,Pattern,[{capture,none}]),
        true=code:soft_purge(re),
        suspended_match(Bytes,Filename),
        dirty_compile(Bytes,Filename,finish),
        dirty_compile(Bytes,Filename,kill),
        true=code:soft_purge(re),
        ok
    after
        otp_re_test:limit(default),otp_re_test:compile_hold(0),
        otp_re_test:fail_upgrade(0),
        case Sticky of true->true=code:stick_mod(re);false->ok end
    end.

suspended_match(Bytes,Filename)->
    {ok,Pattern}=re:compile(<<"b">>,[unicode]),
    _=otp_re_test:limit(1),Parent=self(),
    {Pid,Monitor}=spawn_monitor(fun()->
        receive go->ok end,
        Result=re:run(binary:copy(<<"a">>,4000000),Pattern,[{capture,none}]),
        Parent!{done,self(),Result}
    end),
    1=erlang:trace(Pid,true,[running,{tracer,self()}]),Pid!go,
    await_yield(Pid,Monitor),
    true=erlang:suspend_process(Pid),
    1=erlang:trace(Pid,false,[running]),
    {module,re}=code:load_binary(re,Filename,Bytes),
    false=code:soft_purge(re),
    {namelist,[]}=re:inspect(Pattern,namelist),
    _=otp_re_test:limit(default),true=erlang:resume_process(Pid),
    receive {done,Pid,nomatch}->ok after 10000->error(match_completion_timeout) end,
    receive {'DOWN',Monitor,process,Pid,normal}->ok after 10000->error(match_exit_timeout) end,
    true=code:soft_purge(re),flush_traces(Pid).

await_yield(Pid,Monitor)->
    receive
        {trace,Pid,out,{re,re_match_continue,2}}->ok;
        {trace,Pid,_,_}->await_yield(Pid,Monitor);
        {'DOWN',Monitor,process,Pid,Reason}->error({match_died_before_yield,Reason})
    after 10000->error(match_yield_timeout)
    end.
flush_traces(Pid)->receive {trace,Pid,_,_}->flush_traces(Pid) after 0->ok end.

dirty_compile(Bytes,Filename,Action)->
    Entries=maps:get(compile_entered,otp_re_test:stats()),
    0=otp_re_test:compile_hold(1000),Parent=self(),
    {Pid,Monitor}=spawn_monitor(fun()->
        {ok,_}=re:compile(<<"(a)">>),Parent!{compiled,self()}
    end),
    await(fun()->S=otp_re_test:stats(),maps:get(compile_entered,S)>Entries andalso maps:get(compile_active,S)>0 end),
    {module,re}=code:load_binary(re,Filename,Bytes),
    case Action of
        finish->receive {compiled,Pid}->ok after 10000->error(compile_completion_timeout) end;
        kill->exit(Pid,kill)
    end,
    receive {'DOWN',Monitor,process,Pid,Reason}->
        case Action of finish->normal=Reason;kill->killed=Reason end
    after 10000->error(compile_exit_timeout)
    end,
    await(fun()->maps:get(compile_active,otp_re_test:stats())==0 end),
    true=code:soft_purge(re),
    0=otp_re_test:compile_hold(0),ok.

await(Predicate)->await(Predicate,erlang:monotonic_time(millisecond)+10000).
await(Predicate,Deadline)->
    case Predicate() of
        true->ok;
        false->case erlang:monotonic_time(millisecond)<Deadline of
            true->receive after 1->await(Predicate,Deadline) end;
            false->error(native_checkpoint_timeout)
        end
    end.
