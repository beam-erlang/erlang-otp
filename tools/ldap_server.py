#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run a command with an explicitly selected, disposable OpenLDAP dependency."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import time


def quoted(path):
    return '"' + str(path).replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    root, work = args.root.resolve(), args.work.resolve()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('a command is required')
    server = work / 'ldap-server'
    server.mkdir()
    database = server / 'database'
    database.mkdir()
    key, cert = server / 'key.pem', server / 'cert.pem'
    ca_key, ca_cert, request = server / 'ca-key.pem', server / 'ca.pem', server / 'request.pem'
    extensions = server / 'server.ext'
    extensions.write_text("basicConstraints=critical,CA:FALSE\n"
                          "keyUsage=critical,digitalSignature,keyEncipherment\n"
                          "extendedKeyUsage=serverAuth\n"
                          "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:0:0:0:0:0:0:0:1\n")
    with (server / 'certificate.log').open('w') as output:
        commands = [
            ['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
             '-days', '1', '-subj', '/CN=OTP LDAP test CA',
             '-addext', 'basicConstraints=critical,CA:TRUE',
             '-addext', 'keyUsage=critical,keyCertSign,cRLSign',
             '-keyout', str(ca_key), '-out', str(ca_cert)],
            ['openssl', 'req', '-new', '-newkey', 'rsa:2048', '-nodes',
             '-subj', '/CN=localhost', '-keyout', str(key), '-out', str(request)],
            ['openssl', 'x509', '-req', '-in', str(request), '-CA', str(ca_cert),
             '-CAkey', str(ca_key), '-CAcreateserial', '-days', '1',
             '-extfile', str(extensions), '-out', str(cert)]
        ]
        for command_line in commands:
            subprocess.run(command_line, stdout=output, stderr=subprocess.STDOUT, check=True)
    key.chmod(0o600)
    ca_key.chmod(0o600)
    configuration = server / 'slapd.conf'
    configuration.write_text('\n'.join([
        'include ' + quoted(root / 'etc/ldap/schema/core.schema'),
        'modulepath ' + quoted(root / 'usr/lib/ldap'),
        'moduleload back_mdb.so',
        'pidfile ' + quoted(server / 'slapd.pid'),
        'argsfile ' + quoted(server / 'slapd.args'),
        'TLSCertificateFile ' + quoted(cert),
        'TLSCertificateKeyFile ' + quoted(key),
        'TLSCACertificateFile ' + quoted(ca_cert),
        'database mdb',
        'maxsize 10485760',
        'suffix "dc=ericsson,dc=se"',
        'rootdn "cn=Manager,dc=ericsson,dc=se"',
        'rootpw hejsan',
        'directory ' + quoted(database),
        'index objectClass eq',
        'access to attrs=userPassword by self write by anonymous auth '
        'by dn.base="cn=Manager,dc=ericsson,dc=se" write by * none',
        'access to * by self write by dn.base="cn=Manager,dc=ericsson,dc=se" write by * read',
        ''
    ]))
    # Only the external daemon needs the extracted package's libslapi. Never
    # propagate a loader override into the candidate OTP command or its peers.
    server_env = dict(os.environ)
    server_env['LD_LIBRARY_PATH'] = str(root / 'usr/lib/x86_64-linux-gnu')
    with (server / 'server.log').open('w') as output:
        daemon = subprocess.Popen([str(root / 'usr/sbin/slapd'), '-d', '0', '-f', str(configuration),
                                   '-h', 'ldap://127.0.0.1:9876 ldaps://127.0.0.1:9877'],
                                  env=server_env, stdout=output, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 10
            while True:
                if daemon.poll() is not None:
                    raise RuntimeError(f'OpenLDAP exited; inspect {server / "server.log"}')
                try:
                    with socket.create_connection(('127.0.0.1', 9876), timeout=0.2):
                        break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise RuntimeError('OpenLDAP did not listen')
                    time.sleep(0.05)
            # Certificate location is explicit input to the independent product
            # probe. The unchanged upstream suite chooses its own TLS options.
            environment = dict(os.environ, OTP_LDAP_CERT=str(ca_cert))
            status = subprocess.run(command, env=environment).returncode
        finally:
            daemon.terminate()
            try:
                daemon.wait(timeout=5)
            except subprocess.TimeoutExpired:
                daemon.kill()
                daemon.wait()
    raise SystemExit(status)


if __name__ == '__main__':
    main()
