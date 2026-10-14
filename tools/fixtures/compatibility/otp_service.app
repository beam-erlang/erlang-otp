{application, otp_service,
 [{description, "TCP, file and compression compatibility example"},
  {vsn, "1.0"},
  {modules, [otp_services, otp_service_app, otp_service_sup, otp_service]},
  {registered, [otp_service_sup, otp_service]},
  {applications, [kernel, stdlib]},
  {mod, {otp_service_app, []}},
  {env, [{backend, inet}]}]}.
