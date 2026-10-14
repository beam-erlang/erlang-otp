# Installed OTP application and service acceptance

These ten Erlang modules and two application resources transfer the existing
BEAM distribution's OTP compatibility fixture to the OTP product. The behavior
assertions preserve ordinary I/O, application environment, supervised worker
replacement, readiness/shutdown acknowledgements, repeated application/resource
lifetimes, TCP with both backends, files and compression.

`otp_fixture.erl` checks this product's installed layout and VM mapping instead
of the former BEAM OTP asset layout and C embedding launcher. All other Erlang
and application files retain their transferred contents. This fixture does not
claim full OTP compatibility.

`tools/check_compatibility.py` compiles these sources using installed `erlc` and
runs them with installed `erl` in fresh, relocated and isolated prefixes. The
old BEAM fixture remains until replacement acceptance and command migration
complete. The migration record is in the workspace development documents.
