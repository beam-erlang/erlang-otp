%% SPDX-License-Identifier: Apache-2.0
%% Project-owned checks; all generated suites live in a fresh scratch directory.
-module(otp_ct_evidence_probe).
-export([run/1]).

run(Work) ->
    ok = filelib:ensure_dir(filename:join(Work, "placeholder")),
    {ok, []} = file:list_dir(Work),
    Stage = filename:join(Work, "suites"),
    ok = filelib:ensure_dir(filename:join(Stage, "placeholder")),
    Suite = otp_ct_accounting_probe_SUITE,
    ok = file:write_file(filename:join(Stage, atom_to_list(Suite) ++ ".erl"),
      "-module(otp_ct_accounting_probe_SUITE).\n"
      "-export([all/0,groups/0,init_per_group/2,end_per_group/2,pass/1,repeated/1,fail/1,skip/1,gap/0,gap/1,cleanup/1,end_per_testcase/2]).\n"
      "all()->otp_ct_metadata_helper:all().\n"
      "groups()->otp_ct_metadata_helper:groups().\n"
      "init_per_group(_,C)->C.\nend_per_group(broken_cleanup,_)->erlang:error(expected_group_cleanup_failure);\nend_per_group(_,C)->C.\n"
      "pass(_)->false=code:is_loaded(otp_ct_evidence),false=code:is_loaded(otp_ct_prepare),"
      "false=code:is_loaded(otp_ct_support),\"otp_ct_event.beam\"=filename:basename(code:which(otp_ct_event)),ok.\n"
      "repeated(_)->ok.\nfail(_)->ct:fail(expected_failure).\n"
      "skip(_)->{skip,unexplained_probe_skip}.\n"
      "gap()->[{require,probe_service}].\ngap(_)->ok.\n"
      "cleanup(_)->ok.\nend_per_testcase(cleanup,_)->erlang:error(expected_cleanup_failure);\n"
      "end_per_testcase(_,_) -> ok.\n"),
    Helper = otp_ct_metadata_helper,
    HelperSource = filename:join(Stage, atom_to_list(Helper) ++ ".erl"),
    HelperBeam = filename:join(Stage, atom_to_list(Helper) ++ code:objfile_extension()),
    ok = file:write_file(HelperSource,
        "-module(otp_ct_metadata_helper).\n-export([all/0,groups/0]).\n"
        "-include(\"probe_metadata.hrl\").\n"
        "all()->[pass,{group,?OTP_CT_REPEAT_GROUP}].\n"
        "groups()->[{?OTP_CT_REPEAT_GROUP,[{repeat,?OTP_CT_REPEAT_COUNT}],[repeated]},"
        "{broken_cleanup,[],[pass]},{foreign,[],[{otp_ct_probe_subordinate,all}]}].\n"),
    ok = file:write_file(filename:join(Stage, "probe_metadata.hrl"),
                        "-define(OTP_CT_REPEAT_GROUP,repetition).\n"),
    ok = file:write_file(filename:join(Stage, "Emakefile"),
                        "{'*',[debug_info,{i,\".\"},{d,'OTP_CT_REPEAT_COUNT',2}]}.\n"),
    ok=file:write_file(filename:join(Stage,"otp_ct_probe_subordinate.erl"),
        "-module(otp_ct_probe_subordinate).\n-export([all/0,external/1]).\nall()->[external].\nexternal(_)->ok.\n"),
    probe_configs(Stage),
    Spec = filename:join(Stage, "probe.spec"),
    ok = file:write_file(Spec, io_lib:format("{suites,~tp,[~p]}.~n{probe_custom,marker}.~n", [Stage, Suite])),
    Product=filename:dirname(filename:dirname(filename:dirname(filename:absname(?FILE)))),
    {RuntimeCtx,RuntimeCopy}=otp_ct_support:prepare_runtime(#{source_root=>Product,
        candidate_prefix=>code:root_dir(),work_root=>Work}),
    Synthetic = synthetic_identity(),
    Identity = Synthetic#{<<"candidate">>=>(maps:get(<<"candidate">>,Synthetic))#{
        <<"tree_sha256">>=>maps:get(producer_tree_sha256,RuntimeCopy)}},
    Fixture = source_fixture(Work,Identity,Stage,Spec,#{Suite=>authored}),
    P = (maps:get(prepared,Fixture))#{server_dir=>Stage,batch=>#{}},
    Session=#{format=>1,id=>list_to_binary(lists:duplicate(32,$a)),
        started=>list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second),[{offset,"Z"}]))},
    Base = RuntimeCtx#{domain=>eunit,profile=>full,identity=>Identity,session=>Session,
                      runtime_installation_copy=>RuntimeCopy,runtime_snapshot_root=>Work},
    FullCtx = Base#{work_root=>filename:join(Work,"full")},
    FullPlan = otp_ct_evidence:plan(FullCtx,P),
    Full = execute(FullCtx,P,FullPlan,Fixture),
    %% Direct CT can request exported cases outside all/0; our controller rejects
    %% those as unselected. Use original native specs for accounting negatives.
    Runs = [begin
        NativeSpec = filename:join(Stage, atom_to_list(Case) ++ ".spec"),
        ok=file:write_file(NativeSpec,io_lib:format("{cases,~tp,~p,[~p]}.~n",[Stage,Suite,Case])),
        Ctx = Base#{work_root=>filename:join(Work,atom_to_list(Case))},
        Prepared = P#{spec=>NativeSpec}, Plan = otp_ct_evidence:plan(Ctx,Prepared),
        {Case,execute(Ctx,Prepared,Plan,Fixture)}
    end || Case <- [fail,skip,gap,cleanup]],
    FocusCtx = Base#{profile=>suite,suite=>Suite,testcase=>pass,
                     ct_options=>[{config,[filename:join(Stage,"selected.config")]}],
                     work_root=>filename:join(Work,"suite")},
    _ = code:purge(Helper), _ = code:delete(Helper), _ = code:purge(Helper),
    false = code:is_loaded(Helper),
    ok = file:delete(HelperBeam),
    HelperWasUncompiled = not filelib:is_regular(HelperBeam),
    FocusPlan = otp_ct_evidence:plan(FocusCtx,P),
    Focus = execute(FocusCtx,P,FocusPlan,Fixture),
    GroupCtx = Base#{profile=>suite,suite=>Suite,group=>repetition,
                     work_root=>filename:join(Work,"group")},
    GroupPlan = otp_ct_evidence:plan(GroupCtx,P),
    Group = execute(GroupCtx,P,GroupPlan,Fixture),
    ForeignCtx=GroupCtx#{group=>foreign,work_root=>filename:join(Work,"foreign-module")},
    Foreign=execute(ForeignCtx,P,otp_ct_evidence:plan(ForeignCtx,P),Fixture),
    BrokenCtx = Base#{profile=>suite,suite=>Suite,group=>broken_cleanup,
                      work_root=>filename:join(Work,"broken-group")},
    BrokenPlan = otp_ct_evidence:plan(BrokenCtx,P),
    Broken = execute(BrokenCtx,P,BrokenPlan,Fixture),
    AuthoredSpec = filename:join(Stage,"authored-skip.spec"),
    ok=file:write_file(AuthoredSpec,io_lib:format(
        "{cases,~tp,~p,[pass,skip]}.~n{skip_cases,~tp,~p,[skip],unexplained_probe_skip}.~n",
        [Stage,Suite,Stage,Suite])),
    AuthoredCtx=Base#{work_root=>filename:join(Work,"authored")},
    AuthoredFixture=source_fixture(filename:join(Work,"authored-fixture"),Identity,Stage,AuthoredSpec,#{Suite=>authored}),
    AuthoredP=(maps:get(prepared,AuthoredFixture))#{server_dir=>Stage,batch=>#{}},
    AuthoredPlan=otp_ct_evidence:plan(AuthoredCtx,AuthoredP),
    Authored=execute(AuthoredCtx,AuthoredP,AuthoredPlan,AuthoredFixture),
    EmptyModule=otp_ct_empty_probe_SUITE,
    EmptyStage=filename:join(Work,"empty-suites"),ok=filelib:ensure_path(EmptyStage),
    ok=file:write_file(filename:join(EmptyStage,atom_to_list(EmptyModule)++".erl"),
        "-module(otp_ct_empty_probe_SUITE).\n-export([all/0]).\nall()->[].\n"),
    EmptySpec=filename:join(EmptyStage,"empty.spec"),
    probe_configs(EmptyStage),
    ok=file:write_file(EmptySpec,io_lib:format("{suites,~tp,[~p]}.~n",[EmptyStage,EmptyModule])),
    ZeroCtx=Base#{work_root=>filename:join(Work,"zero")},
    ZeroFixture=source_fixture(filename:join(Work,"zero-fixture"),Identity,EmptyStage,EmptySpec,#{EmptyModule=>authored}),
    ZeroP=(maps:get(prepared,ZeroFixture))#{server_dir=>EmptyStage,batch=>#{}},
    Zero=execute(ZeroCtx,ZeroP,otp_ct_evidence:plan(ZeroCtx,ZeroP),ZeroFixture),
    InvalidGroup = rejects(fun()->otp_ct_evidence:plan(GroupCtx#{group=>absent_group},P) end),
    InvalidCase = rejects(fun()->otp_ct_evidence:plan(FocusCtx#{testcase=>absent_case},P) end),
    OutsideSelection=rejects(fun()->otp_ct_evidence:plan(FocusCtx#{testcase=>fail},P) end),
    Empty = rejects(fun()->otp_ct_evidence:plan(FocusCtx#{testcase=>[]},P) end),
    EmptyGroup=rejects(fun()->otp_ct_evidence:plan(GroupCtx#{group=>[]},P) end),
    EmptySuite = rejects(fun()->otp_ct_evidence:plan(FocusCtx#{suite=>[]},P) end),
    NoSuite = rejects(fun()->otp_ct_evidence:plan(maps:remove(suite,FocusCtx),P) end),
    EventPath = maps:get(event_file,Full),
    {ok, Raw} = file:read_file(EventPath),
    Truncated = filename:join(Work,"truncated.jsonl"),
    ok=file:write_file(Truncated,binary:part(Raw,0,byte_size(Raw)-3)),
    TruncResult=otp_ct_evidence:assess(FullCtx,P,FullPlan,{3,0,{0,0}},Truncated),
    WrongStats=otp_ct_evidence:assess(FullCtx,P,FullPlan,{4,0,{0,0}},EventPath),
    Rows=[json:decode(L)||L<-binary:split(Raw,<<"\n">>,[global]),L=/=<<>>],
    NoDone=altered(Work,"missing-done",Rows,fun(Es)->[E||E<-Es,maps:get(<<"event">>,E)=/=<<"test_done">>] end),
    NoStats=altered(Work,"missing-stats",Rows,fun(Es)->[E||E<-Es,maps:get(<<"event">>,E)=/=<<"test_stats">>] end),
    Severe=altered(Work,"severe",Rows,fun(Es)->Es++[#{<<"event">>=><<"severe_error">>,<<"node">>=><<"nonode@nohost">>,<<"data">>=><<"probe">>}] end),
    Unknown=altered(Work,"unknown-result",Rows,fun(Es)->[case E of
        #{<<"event">>:=<<"tc_done">>,<<"data">>:=[S,<<"pass">>,_]}->E#{<<"data">>=>[S,<<"pass">>,<<"unknown_probe_result">>]};
        _->E end||E<-Es] end),
    MissingDone=otp_ct_evidence:assess(FullCtx,P,FullPlan,{3,0,{0,0}},NoDone),
    MissingStats=otp_ct_evidence:assess(FullCtx,P,FullPlan,{3,0,{0,0}},NoStats),
    SevereResult=otp_ct_evidence:assess(FullCtx,P,FullPlan,{3,0,{0,0}},Severe),
    UnknownResult=otp_ct_evidence:assess(FullCtx,P,FullPlan,{3,0,{0,0}},Unknown),
    EmptyLog=filename:join(Work,"empty-events.jsonl"),ok=file:write_file(EmptyLog,<<>>),
    EmptyEvents=otp_ct_evidence:assess(FullCtx,P,FullPlan,{0,0,{0,0}},EmptyLog),
    InvalidResult=otp_ct_evidence:assess(FullCtx,P,FullPlan,{error,probe_error},EventPath),
    WrongFocus=otp_ct_evidence:assess(FocusCtx,P,FocusPlan#{testcase=>[repeated]},
        {1,0,{0,0}},maps:get(event_file,Focus)),
    FullPath=filename:join(Work,"full.json"),
    FocusPath=filename:join(Work,"suite.json"),
    ok=otp_ct_support:write_json(FullPath,Full),
    ok=otp_ct_support:write_json(FocusPath,Focus),
    Reconciled=otp_ct_evidence:reconcile([FullPath],[eunit],filename:join(Work,"reconciled.json")),
    Duplicate=otp_ct_evidence:reconcile([FullPath,FullPath],[eunit],filename:join(Work,"duplicate.json")),
    Focused=otp_ct_evidence:reconcile([FocusPath],[eunit],filename:join(Work,"suite-reconcile.json")),
    Missing=otp_ct_evidence:reconcile([FullPath],[eunit,crypto],filename:join(Work,"missing.json")),
    TamperedPath=filename:join(Work,"tampered-counts.json"),
    ok=otp_ct_support:write_json(TamperedPath,Full#{raw_counts=>[4,0,[0,0]]}),
    Tampered=otp_ct_evidence:reconcile([TamperedPath],[eunit],filename:join(Work,"tampered-reconcile.json")),
    CleanupPath=filename:join(Work,"concealed-cleanup.json"),
    Cleanup=proplists:get_value(cleanup,Runs),
    ok=otp_ct_support:write_json(CleanupPath,Cleanup#{status=><<"passed">>,errors=>[],failed_events=>[]}),
    Concealed=otp_ct_evidence:reconcile([CleanupPath],[eunit],filename:join(Work,"concealed-reconcile.json")),
    SkipPath=filename:join(Work,"relabeled-skip.json"),SkipReport=proplists:get_value(skip,Runs),
    FakeSkips=[S#{classification=><<"not-applicable">>}||S<-maps:get(skips,SkipReport)],
    ok=otp_ct_support:write_json(SkipPath,SkipReport#{status=><<"passed">>,errors=>[],skips=>FakeSkips}),
    Relabeled=otp_ct_evidence:reconcile([SkipPath],[eunit],filename:join(Work,"relabeled-reconcile.json")),
    AuthoredPath=filename:join(Work,"authored.json"),ok=otp_ct_support:write_json(AuthoredPath,Authored),
    AuthoredMatrix=otp_ct_evidence:reconcile([AuthoredPath],[eunit],filename:join(Work,"authored-reconcile.json")),
    OtherPath=filename:join(Work,"other-session.json"),
    ok=otp_ct_support:write_json(OtherPath,Full#{domain=>crypto,
        selection=>(maps:get(selection,Full))#{<<"domain">>=><<"crypto">>},session=>#{id=><<"other">>}}),
    Mixed=otp_ct_evidence:reconcile([FullPath,OtherPath],[eunit,crypto],filename:join(Work,"mixed-session.json")),
    OtherIdentity=(maps:get(identity,Full))#{<<"other_epoch">>=>true},
    ok=otp_ct_support:write_json(OtherPath,Full#{domain=>crypto,
        selection=>(maps:get(selection,Full))#{<<"domain">>=><<"crypto">>},
        identity=>OtherIdentity,epoch=>otp_ct_support:hash(OtherIdentity)}),
    MixedEpoch=otp_ct_evidence:reconcile([FullPath,OtherPath],[eunit,crypto],filename:join(Work,"mixed-epoch.json")),
    DuplicateJson=filename:join(Work,"duplicate-keys.json"),
    ok=file:write_file(DuplicateJson,<<"{\"format\":3,\"format\":3}\n">>),
    InvalidJson=otp_ct_evidence:reconcile([DuplicateJson],[eunit],filename:join(Work,"duplicate-keys-reconcile.json")),
    NoSDK=identity_negative(Work,"missing-sdk",Full,maps:remove(<<"sdk">>,Identity)),
    NoCandidate=identity_negative(Work,"missing-candidate",Full,maps:remove(<<"candidate">>,Identity)),
    Sparse=identity_negative(Work,"sparse-identity",Full,#{<<"probe">>=>true}),
    NoFinish=filename:join(Work,"missing-finish.json"),
    ok=otp_ct_support:write_json(NoFinish,maps:without([identity_at_finish,inputs_changed_during_run],Full)),
    Unfinished=otp_ct_evidence:reconcile([NoFinish],[eunit],filename:join(Work,"missing-finish-reconcile.json")),
    NoSession=filename:join(Work,"missing-session.json"),
    ok=otp_ct_support:write_json(NoSession,maps:remove(session,Full)),
    MissingSession=otp_ct_evidence:reconcile([NoSession],[eunit],filename:join(Work,"missing-session-reconcile.json")),
    {GeneratedChecks,GeneratedReport}=generated_contract_probe(Work,Base),
    PlatformChecks=platform_schema_probes(Work,Full,Identity),
    LiveChecks=live_reconciliation_checks(Work,Full,Identity,Session),
    {ok, HelperBytes} = file:read_file(HelperSource),
    {ok, BeforeHelperFailure} = file:get_cwd(),
    ok = file:delete(HelperBeam),
    BrokenHelper = try
        ok = file:write_file(HelperSource, "-module(otp_ct_metadata_helper).\nbroken syntax.\n"),
        rejects_reason(fun()->otp_ct_evidence:plan(FocusCtx,P) end, focus_helper_compile_failed)
    after
        ok = file:write_file(HelperSource, HelperBytes)
    end,
    {ok, AfterHelperFailure} = file:get_cwd(),
    Checks0=#{full=>passed(Full),repeated_groups=>maps:get(raw_counts,Full)=:=[3,0,[0,0]],
        uncompiled_metadata_helper_prepared=>HelperWasUncompiled andalso passed(Focus),
        broken_metadata_helper_rejected=>BrokenHelper,
        helper_compile_failure_restores_directory=>BeforeHelperFailure=:=AfterHelperFailure,
        original_ct_configs_default=>ct_option(config,Full)=:=[list_to_binary(filename:join(Stage,F))||F<-["ts.config","ts.unix.config"]],
        original_timetrap_scaling=>ct_option(scale_timetraps,Full)=:=true,
        selected_ct_config_replaces_defaults=>ct_option(config,Focus)=:=[list_to_binary(filename:join(Stage,"selected.config"))],
        native_unknown_total=>lists:any(fun([_,_,N])->N=:=<<"unknown">> end,maps:get(start_info,Full)),
        suite=>passed(Focus),suite_group=>passed(Group),native_subordinate_group=>passed(Foreign),
        group_cleanup_failure=>failed(Broken),
        authored_native_skip=>passed(Authored),authored_skip_reconcile=>maps:get(complete,AuthoredMatrix),
        zero_execution=>failed(Zero),empty_events=>failed(EmptyEvents),
        failure=>failed(proplists:get_value(fail,Runs)),
        unexplained_skip=>failed(proplists:get_value(skip,Runs)),
        missing_prerequisite=>maps:get(status,proplists:get_value(gap,Runs))=:=<<"blocked">>,
        cleanup_failure=>failed(proplists:get_value(cleanup,Runs)),
        unknown_group=>InvalidGroup,unknown_case=>InvalidCase,empty_case=>Empty,empty_group=>EmptyGroup,
        exported_case_outside_original_selection=>OutsideSelection,
        empty_suite=>EmptySuite,missing_suite=>NoSuite,truncated_events=>failed(TruncResult),
        mismatched_statistics=>failed(WrongStats),missing_statistics=>failed(MissingStats),
        missing_done=>failed(MissingDone),severe_error=>failed(SevereResult),unknown_outcome=>failed(UnknownResult),
        invalid_return=>failed(InvalidResult),wrong_suite_selection=>failed(WrongFocus),
        full_reconcile=>maps:get(complete,Reconciled),tampered_counts_rejected=>not maps:get(complete,Tampered),
        concealed_cleanup_rejected=>not maps:get(complete,Concealed),
        relabeled_unknown_skip_rejected=>not maps:get(complete,Relabeled),
        mixed_sessions_rejected=>not maps:get(complete,Mixed),
        mixed_epochs_rejected=>not maps:get(complete,MixedEpoch),
        duplicate_json_keys_rejected=>not maps:get(complete,InvalidJson),
        missing_sdk_identity_rejected=>has_error(NoSDK,<<"invalid_recorded_sdk_identity">>),
        missing_candidate_identity_rejected=>has_error(NoCandidate,<<"invalid_recorded_candidate_identity">>),
        sparse_identity_rejected=>has_error(Sparse,<<"invalid_recorded_source_identity">>) andalso
            has_error(Sparse,<<"invalid_recorded_sdk_identity">>) andalso
            has_error(Sparse,<<"invalid_recorded_candidate_identity">>),
        missing_finish_receipt_rejected=>not maps:get(complete,Unfinished),
        missing_session_rejected=>has_error(MissingSession,<<"mixed_or_missing_sessions">>),
        duplicate_rejected=>not maps:get(complete,Duplicate),
        suite_rejected=>not maps:get(complete,Focused),missing_domain_rejected=>not maps:get(complete,Missing)},
    NativeChecks=native_controller_checks(Work,Full),
    RuntimeChanges=otp_ct_support:finish_runtime(RuntimeCtx),
    Checks=maps:merge(maps:merge(maps:merge(maps:merge(Checks0,GeneratedChecks),PlatformChecks),LiveChecks),NativeChecks),
    Summary=#{scope=><<"project-controller-probe-with-synthetic-identities">>,
              status=>case lists:all(fun(X)->X=:=true end,maps:values(Checks)) of
                         true->passed;false->failed end,
              runtime_copy=>RuntimeCopy,runtime_changes=>RuntimeChanges,
              checks=>Checks,runs=>maps:from_list(Runs++[{full,Full},{suite,Focus},{group,Group},
                  {broken_group,Broken},{authored_skip,Authored},{zero,Zero},{foreign_module,Foreign},
                  {generated_complete,GeneratedReport}])},
    ok=otp_ct_support:write_json(filename:join(Work,"selftest.json"),Summary),
    Summary.

native_controller_checks(Work,Full)->
    Native=maps:get(native_execution,Full),
    Initial=otp_ct_support:read_json(maps:get(<<"path">>,maps:get(<<"initial_runtime">>,Native))),
    Final=otp_ct_support:read_json(maps:get(<<"path">>,maps:get(<<"final_runtime">>,Native))),
    CountsPath=filename:join(Work,"changed-native-totals.json"),
    BadTotals=(maps:get(<<"totals">>,Native))#{<<"sha256">>=>list_to_binary(lists:duplicate(64,$0))},
    ok=otp_ct_support:write_json(CountsPath,Full#{native_execution=>Native#{<<"totals">>=>BadTotals}}),
    BadCounts=otp_ct_evidence:reconcile([CountsPath],[eunit],undefined),
    MissingPath=filename:join(Work,"missing-native-completion.json"),
    ok=otp_ct_support:write_json(MissingPath,Full#{native_execution=>maps:remove(<<"final_runtime">>,Native)}),
    Missing=otp_ct_evidence:reconcile([MissingPath],[eunit],undefined),
    WrongRootPath=filename:join(Work,"wrong-native-runtime.json"),
    ok=otp_ct_support:write_json(WrongRootPath,Full#{native_execution=>Native#{<<"runtime_prefix">>=><<"/wrong/runtime">>}}),
    WrongRoot=otp_ct_evidence:reconcile([WrongRootPath],[eunit],undefined),
    NonzeroPath=filename:join(Work,"native-nonzero.json"),
    ok=otp_ct_support:write_json(NonzeroPath,Full#{native_execution=>Native#{<<"command">>=>(maps:get(<<"command">>,Native))#{<<"exit_status">>=>1}}}),
    Nonzero=otp_ct_evidence:reconcile([NonzeroPath],[eunit],undefined),
    #{fresh_original_ct_controller=>maps:get(<<"node">>,Initial)=/=atom_to_binary(node()) andalso
        maps:get(<<"node">>,Initial)=:=maps:get(<<"node">>,Final),
      actual_disposable_runtime=>maps:get(<<"root_dir">>,Initial)=:=maps:get(<<"runtime_prefix">>,Native),
      native_totals_tampering_rejected=>not maps:get(complete,BadCounts),
      native_completion_receipt_required=>not maps:get(complete,Missing),
      native_runtime_mismatch_rejected=>not maps:get(complete,WrongRoot),
      native_nonzero_exit_rejected=>not maps:get(complete,Nonzero)}.
rejects(Fun)->try Fun(),false catch _:_ ->true end.
passed(R)->maps:get(status,R)=:=<<"passed">>.
failed(R)->maps:get(status,R)=:=<<"failed">>.
altered(Work,Name,Rows,Fun)->
    Path=filename:join(Work,Name++".jsonl"),
    ok=file:write_file(Path,[[json:encode(E),$\n]||E<-Fun(Rows)]),Path.

execute(Ctx,Prepared,Plan,Fixture)->
    Report=otp_ct_evidence:execute(Ctx,Prepared,Plan),
    Changes=otp_ct_support:finish_runtime(Ctx#{work_root=>maps:get(runtime_snapshot_root,Ctx)}),
    Report#{identity_at_finish=>maps:get(identity,Report),inputs_changed_during_run=>false,
            runtime_installation=>#{copy=>maps:get(runtime_installation_copy,Ctx),changes=>Changes},
            preparation=>maps:get(preparation,Fixture),
            source_integrity=>otp_ct_prepare:verify(maps:get(verify,Fixture))}.

identity_negative(Work,Name,Full,Identity)->
    Path=filename:join(Work,Name++".json"),
    ok=otp_ct_support:write_json(Path,Full#{identity=>Identity,identity_at_finish=>Identity,
        epoch=>otp_ct_support:hash(Identity)}),
    otp_ct_evidence:reconcile([Path],[eunit],filename:join(Work,Name++"-reconcile.json")).
has_error(R,E)->not maps:get(complete,R) andalso lists:member(E,maps:get(errors,R)).

%% Identity shape is synthetic and portable. Raw CT and receipt files are real
%% task-owned evidence; these reports cannot match the entry point's real epoch.
synthetic_identity()->
    H=list_to_binary(lists:duplicate(64,$a)),
    Adapters=[<<"otp_ct.escript">>,<<"otp_ct_support.erl">>,<<"otp_ct_prepare.erl">>,
        <<"otp_ct_evidence.erl">>,<<"otp_ct_yielding.erl">>,<<"otp_ct_event.erl">>],
    Files=[<<"bin/erl">>,<<"bin/erlc">>,<<"bin/escript">>,<<"erts-17.0/bin/beam.smp">>,
        <<"erts-17.0/bin/erl_child_setup">>,<<"erts-17.0/bin/epmd">>],
    otp_ct_support:json(#{configuration=>[<<"Linux">>,<<"x86_64">>,<<"emu">>,<<"Release">>],
        runtime_configuration=>#{schedulers=>2,dirty_cpu_schedulers=>1,dirty_io_schedulers=>1},
        source=>#{source_commit=><<"550d7b7898706c7822362c42e7b93120c1d1f29a">>,
            manifest=>H,yielding_input_registry=>H,adapter=>maps:from_list([{N,H}||N<-Adapters])},
        sdk=>(maps:from_list([{K,H}||K<-[selection_sha256,manifest_sha256,source_id,build_id,toolchain_id]]))#{host_triple=><<"x86_64-pc-linux-gnu">>},
        candidate=>#{root=>list_to_binary(code:root_dir()),erts=><<"17.0">>,flavor=><<"emu">>,
            build_type=><<"Release">>,files=>maps:from_list([{N,#{kind=>regular,mode=>8#755,sha256=>H}}||N<-Files])},
        tools=>maps:from_list([{N,#{path=>list_to_binary("/synthetic/"++atom_to_list(N)),sha256=>H}}||N<-[make,cc,cxx,git,tar]]),
        configured_make=>maps:from_list([{N,H}||N<-[<<"make/make_emakefile">>,<<"make/output.mk">>,
            <<"make/x86_64-pc-linux-gnu/otp.mk">>]]),inputs=>#{}}).

source_fixture(Work,Identity,Stage,Spec,Origins)->
    Source=filename:join(Work,"immutable-source"),Input=filename:join(Source,"original-input"),
    ok=filelib:ensure_dir(Input),ok=file:write_file(Input,<<"project-owned immutable probe input\n">>),
    ok=file:change_mode(Input,8#644),
    Inventory=filename:join(Work,"source-inputs.json"),
    ok=otp_ct_support:write_json(Inventory,#{<<"original-input">>=>#{type=>regular,
        sha256=>otp_ct_support:sha(Input),executable=>false}}),
    Original=#{path=>Inventory,sha256=>otp_ct_support:sha(Inventory)},
    SuiteInventory=maps:from_list([begin
        Path=filename:join(Stage,atom_to_list(Name)++".erl"),
        {atom_to_binary(Name),#{path=>Path,sha256=>otp_ct_support:sha(Path),origin=>Origin,
                                emakefile_options=>[debug_info]}}
    end||{Name,Origin}<-maps:to_list(Origins)]),
    StageReceipt=entry_receipt(filename:join(Work,"staged-inputs.json"),
        [F||F<-filelib:wildcard(filename:join(Stage,"*")),filelib:is_regular(F),
            filename:extension(F)=/=code:objfile_extension()]),
    Retained=entry_receipt(filename:join(Work,"retained-inputs.json"),[Input]),
    GeneratedPaths=[begin
        File=atom_to_list(Name)++".erl",Target=filename:join(Source,File),
        {ok,Data}=file:read_file(filename:join(Stage,File)),ok=file:write_file(Target,Data),Target
    end||{Name,Origin}<-maps:to_list(Origins),Origin=/=authored],
    Generated=entry_receipt(filename:join(Work,"generated-inputs.json"),GeneratedPaths),
    SourceIdentity=maps:get(<<"source">>,Identity),
    Prepared0=#{domain=>eunit,profile=>full,source_dir=>Source,original_inventory=>Original,
        platform=>linux,target=>maps:get(<<"host_triple">>,maps:get(<<"sdk">>,Identity)),
        stage_dir=>Stage,server_dir=>Stage,spec=>Spec,original_spec=>Spec,suites=>maps:keys(Origins),
        preparation_contract=><<"original-make-inputs-v2">>,staged_suite_inventory=>SuiteInventory,
        stage_input_inventory=>StageReceipt,retained_input_inventory=>Retained,
        source_generated_inventory=>Generated,
        source_commit=>maps:get(<<"source_commit">>,SourceIdentity),
        manifest=>#{path=>filename:join(Work,"synthetic-manifest"),sha256=>maps:get(<<"manifest">>,SourceIdentity)},
        source_archive=>#{path=>Input,sha256=>otp_ct_support:sha(Input)}},
    InputReceipt=filename:join(Work,"preparation-inputs.json"),
    ReceiptKeys=[domain,profile,platform,target,source_commit,manifest,source_archive,preparation_contract,
        original_inventory,staged_suite_inventory,stage_input_inventory,retained_input_inventory,
        source_generated_inventory],
    ok=otp_ct_support:write_json(InputReceipt,maps:with(ReceiptKeys,Prepared0)),
    InputIdentity=#{path=>InputReceipt,sha256=>otp_ct_support:sha(InputReceipt)},
    Preparation=filename:join(Work,"preparation.json"),
    ok=otp_ct_support:write_json(Preparation,Prepared0#{input_identity=>InputIdentity}),
    Sealed=Prepared0#{input_identity=>InputIdentity},
    #{input_identity=>InputIdentity,preparation=>#{path=>Preparation,sha256=>otp_ct_support:sha(Preparation)},
      prepared=>Sealed,verify=>Sealed}.

entry_receipt(Path,Files)->
    ok=otp_ct_support:write_json(Path,maps:from_list([{list_to_binary(F),#{type=>regular,
        sha256=>otp_ct_support:sha(F),executable=>false}}||F<-Files])),
    #{path=>Path,sha256=>otp_ct_support:sha(Path)}.

generated_contract_probe(Work,Base)->
    Root=filename:join(Work,"generated-contract"),Stage=filename:join(Root,"suites"),
    ok=filelib:ensure_path(Stage),
    Authored=otp_ct_generated_base_SUITE,Variant=otp_ct_generated_variant_SUITE,
    lists:foreach(fun({Module,Case})->
        Path=filename:join(Stage,atom_to_list(Module)++".erl"),
        ok=file:write_file(Path,io_lib:format(
            "-module(~p).~n-export([all/0,~p/1]).~nall()->[~p].~n~p(_)->ok.~n",
            [Module,Case,Case,Case]))
    end,[{Authored,base},{Variant,generated}]),
    ok=file:write_file(filename:join(Stage,"Emakefile"),"{'*',[debug_info]}.\n"),
    probe_configs(Stage),
    Spec=filename:join(Stage,"generated.spec"),
    ok=file:write_file(Spec,io_lib:format("{suites,~tp,all}.~n",[Stage])),
    Fixture=source_fixture(filename:join(Root,"fixture"),maps:get(identity,Base),Stage,Spec,
        #{Authored=>authored,Variant=>variant}),
    P=(maps:get(prepared,Fixture))#{server_dir=>Stage,batch=>#{}},
    Ctx=Base#{work_root=>filename:join(Root,"full")},Plan=otp_ct_evidence:plan(Ctx,P),
    Report=execute(Ctx,P,Plan,Fixture),
    VPath=filename:join(Stage,atom_to_list(Variant)++".erl"),
    Backup=filename:join(Root,"variant.saved"),
    ok=file:rename(VPath,Backup),
    Missing=try rejects_reason(fun()->otp_ct_evidence:plan(Ctx#{work_root=>filename:join(Root,"missing")},P) end,
                               missing_or_changed_staged_suite)
            after ok=file:rename(Backup,VPath) end,
    {ok,Original}=file:read_file(VPath),
    ok=file:write_file(VPath,[Original,"\n%% changed generated output\n"]),
    {Altered,VerifyAltered}=try
        {rejects_reason(fun()->otp_ct_evidence:plan(Ctx#{work_root=>filename:join(Root,"altered")},P) end,
                        missing_or_changed_staged_suite),
         maps:get(status,otp_ct_prepare:verify(P))=:=failed}
        after ok=file:write_file(VPath,Original) end,
    Extra=filename:join(Stage,"otp_ct_unexpected_SUITE.erl"),ok=file:write_file(Extra,<<"% unexpected discovery input\n">>),
    ExtraRejected=try rejects_reason(fun()->otp_ct_evidence:plan(Ctx#{work_root=>filename:join(Root,"extra")},P) end,
                                    staged_suite_discovery_mismatch)
                  after ok=file:delete(Extra) end,
    Names=lists:sort([atom_to_binary(Authored),atom_to_binary(Variant)]),
    Complete=lists:sort(maps:get(selected_suites,Plan))=:=Names andalso
        lists:sort(maps:keys(maps:get(staged_suite_inventory,Plan)))=:=Names,
    NarrowPlan=#{run=>[[list_to_binary(Stage),atom_to_binary(Authored),<<"all">>]],skip=>[]},
    Narrowed=Report#{native_plan=>NarrowPlan,native_plan_sha256=>otp_ct_support:hash(NarrowPlan),
        selection=>(maps:get(selection,Report))#{<<"selected_suites">>=>[atom_to_binary(Authored)]}},
    NPath=filename:join(Root,"narrowed.json"),ok=otp_ct_support:write_json(NPath,Narrowed),
    Matrix=otp_ct_evidence:reconcile([NPath],[eunit],filename:join(Root,"narrowed-reconcile.json")),
    GoodPath=filename:join(Root,"complete.json"),ok=otp_ct_support:write_json(GoodPath,Report),
    Good=otp_ct_evidence:reconcile([GoodPath],[eunit],filename:join(Root,"complete-reconcile.json")),
    {#{generated_full_execution=>passed(Report) andalso maps:get(raw_counts,Report)=:=[2,0,[0,0]],
       full_selection_inventory_consistent=>Complete,missing_generated_suite_rejected=>Missing,
       altered_generated_suite_rejected=>Altered,altered_generated_closure_rejected=>VerifyAltered,
       extra_discovered_suite_rejected=>ExtraRejected,generated_full_reconcile=>maps:get(complete,Good),
       narrowed_full_native_plan_rejected=>has_error(Matrix,<<"full_native_specification_mismatch">>)},Report}.

rejects_reason(Fun,Expected)->
    try Fun(),false catch error:{invalid_selection_or_evidence,Expected}->true;_:_->false end.

%% Exercise portable identity shapes, without claiming a foreign-host CT run.
%% The Linux preparation receipt must still prevent relabeling that evidence.
platform_schema_probes(Work,Full,Identity)->
    Cases=[{linux_aarch64_identity,<<"Linux">>,<<"aarch64">>,<<"Release">>,linux},
        {darwin_arm64_identity,<<"Darwin">>,<<"arm64">>,<<"Release">>,darwin},
        {darwin_x86_64_debug_identity,<<"Darwin">>,<<"x86_64">>,<<"Debug">>,darwin},
        {windows_release_identity,<<"Windows">>,<<"x86_64">>,<<"Release">>,win32},
        {windows_debug_identity,<<"Windows">>,<<"x86_64">>,<<"Debug">>,win32}],
    maps:from_list([begin
        I=platform_identity(Identity,System,Arch,Type),
        R=Full#{identity=>I,identity_at_finish=>I,epoch=>otp_ct_support:hash(I),
            selection=>(maps:get(selection,Full))#{<<"platform">>=>atom_to_binary(Platform)}},
        Path=filename:join(Work,atom_to_list(Name)++".json"),ok=otp_ct_support:write_json(Path,R),
        M=otp_ct_evidence:reconcile([Path],[eunit],filename:join(Work,atom_to_list(Name)++"-reconcile.json")),
        Bad=[<<"invalid_recorded_configuration">>,<<"invalid_recorded_sdk_identity">>,
             <<"invalid_recorded_candidate_identity">>,<<"invalid_recorded_make_identity">>],
        {Name,not lists:any(fun(E)->lists:member(E,maps:get(errors,M)) end,Bad) andalso
              has_error(M,<<"preparation_identity_mismatch">>)}
    end||{Name,System,Arch,Type,Platform}<-Cases]).

platform_identity(I,System,Arch,Type)->
    H=list_to_binary(lists:duplicate(64,$a)),Target = <<"synthetic-target">>,
    Windows=System=:=<<"Windows">>,
    Beam=case {Windows,Type} of {true,<<"Debug">>}-><<"beam.debug.smp.dll">>;
        {true,_}-><<"beam.smp.dll">>;_-><<"beam.smp">> end,
    Commands=case Windows of true->[<<"bin/erl.exe">>,<<"bin/erlc.exe">>,<<"bin/escript.exe">>,
        <<"erts-17.0/bin/erlexec.dll">>,<<"erts-17.0/bin/epmd.exe">>];
        false->[<<"bin/erl">>,<<"bin/erlc">>,<<"bin/escript">>,<<"erts-17.0/bin/erl_child_setup">>,
            <<"erts-17.0/bin/epmd">>] end,
    Files=Commands++[<<"erts-17.0/bin/",Beam/binary>>]++case {Windows,Type} of
        {false,<<"Debug">>}->[<<"erts-17.0/bin/erl_child_setup.debug">>];_->[] end,
    C=(maps:get(<<"candidate">>,I))#{<<"root">>=>case Windows of true-><<"C:/synthetic/otp">>;false-><<"/synthetic/otp">> end,
        <<"build_type">>=>Type,<<"files">>=>maps:from_list([{F,#{<<"kind">>=><<"regular">>,<<"mode">>=>8#755,
            <<"sha256">>=>H}}||F<-Files])},
    I#{<<"configuration">>=>[System,Arch,<<"emu">>,Type],<<"candidate">>=>C,
       <<"sdk">>=>(maps:get(<<"sdk">>,I))#{<<"host_triple">>=>Target},
       <<"configured_make">>=>maps:from_list([{P,H}||P<-[<<"make/make_emakefile">>,<<"make/output.mk">>,
           <<"make/",Target/binary,"/otp.mk">>]])}.

probe_configs(Stage)->lists:foreach(fun(F)->ok=file:write_file(filename:join(Stage,F),<<"% project probe config\n">>) end,
    ["ts.config","ts.unix.config","ts.win32.config","selected.config"]).
ct_option(Key,Report)->
    case [V||[K,V]<-maps:get(ct_options,Report,[]),K=:=atom_to_binary(Key)] of [V]->V;_->undefined end.

%% Use a real scratch dependency to exercise a changed live epoch. No selected
%% SDK, candidate, source extraction or reference files are modified.
live_reconciliation_checks(Work,Full,Identity,Session)->
    ArrayRow=#{<<"data">>=>[[2026,11,16],[8,42,32]]},
    ArrayPath=filename:join(Work,"json-array.json"),
    ok=otp_ct_support:write_json(ArrayPath,#{raw=>ArrayRow}),
    ArrayReport=otp_ct_support:read_json(ArrayPath),
    Dependency=filename:join(Work,"live-dependency.txt"),
    ok=file:write_file(Dependency,<<"captured dependency\n">>),
    Capture=fun()->Identity#{<<"inputs">>=>#{<<"dependency">>=>#{
        <<"path">>=>list_to_binary(Dependency),<<"sha256">>=>otp_ct_support:sha(Dependency)}}} end,
    Before=Capture(),Path=filename:join(Work,"live-component.json"),
    ok=otp_ct_support:write_json(Path,Full#{identity=>Before,identity_at_finish=>Before,
        epoch=>otp_ct_support:hash(Before)}),
    {ok,FilesBefore}=file:list_dir(Work),
    Matrix=otp_ct_evidence:reconcile([Path],[eunit],undefined),
    {ok,FilesAfter}=file:list_dir(Work),
    Matched=otp_ct_evidence:bind_current(Matrix,Before,Session),
    ok=otp_ct_support:write_json(filename:join(Work,"live-matched.json"),Matched),
    ok=file:write_file(Dependency,<<"changed dependency\n">>),
    Drift=otp_ct_evidence:bind_current(Matrix,Capture(),Session),
    ok=otp_ct_support:write_json(filename:join(Work,"live-drift.json"),Drift),
    OtherSession=Session#{id=>list_to_binary(lists:duplicate(32,$b))},
    Stale=otp_ct_evidence:bind_current(Matrix,Before,OtherSession),
    ok=otp_ct_support:write_json(filename:join(Work,"live-stale-session.json"),Stale),
    #{decoded_json_arrays_preserved=>maps:get(<<"raw">>,ArrayReport)=:=ArrayRow,
      matching_live_identity=>maps:get(complete,Matched),
      changed_live_dependency_rejected=>has_error(Drift,<<"reports_do_not_match_current_identity">>),
      stale_live_session_rejected=>has_error(Stale,<<"reports_do_not_belong_to_current_session">>),
      reconciliation_defers_publication=>maps:get(complete,Matrix) andalso
          lists:sort(FilesBefore)=:=lists:sort(FilesAfter)}.
