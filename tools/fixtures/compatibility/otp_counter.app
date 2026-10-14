{application, otp_counter,
 [{description, "Supervised counter compatibility example"},
  {vsn, "1.0"},
  {modules, [otp_supervision, otp_counter_app, otp_counter_sup, otp_counter]},
  {registered, [otp_counter_sup, otp_counter]},
  {applications, [kernel, stdlib]},
  {mod, {otp_counter_app, []}},
  {env, [{initial_count, 41}]}]}.
