#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Supply a disposable PostgreSQL database inside the test's private namespace."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


def driver_version(library, connection):
    """Read SQL_DRIVER_VER from the actual private DSN through public ODBC."""
    api = ctypes.CDLL(str(library))
    handle = ctypes.c_void_p
    short = ctypes.c_short
    api.SQLAllocHandle.argtypes = [short, handle, ctypes.POINTER(handle)]
    api.SQLSetEnvAttr.argtypes = [handle, ctypes.c_int, handle, ctypes.c_int]
    api.SQLDriverConnect.argtypes = [handle, handle, ctypes.c_char_p, short,
                                    handle, short, ctypes.POINTER(short), ctypes.c_ushort]
    api.SQLGetInfo.argtypes = [handle, ctypes.c_ushort, handle, short, ctypes.POINTER(short)]
    api.SQLDisconnect.argtypes = [handle]
    api.SQLFreeHandle.argtypes = [short, handle]
    for name in ('SQLAllocHandle','SQLSetEnvAttr','SQLDriverConnect','SQLGetInfo',
                 'SQLDisconnect','SQLFreeHandle'):
        getattr(api,name).restype = short
    def check(status, operation):
        if status not in (0,1):
            raise RuntimeError(f'ODBC driver-version preparation failed: {operation}: {status}')
    environment, database = handle(), handle()
    connected = False
    try:
        check(api.SQLAllocHandle(1,None,ctypes.byref(environment)),'allocate environment')
        check(api.SQLSetEnvAttr(environment,200,handle(3),0),'select ODBC 3')
        check(api.SQLAllocHandle(2,environment,ctypes.byref(database)),'allocate connection')
        buffer, length = ctypes.create_string_buffer(1024), short()
        check(api.SQLDriverConnect(database,None,connection.encode(),-3,buffer,len(buffer),
                                   ctypes.byref(length),0),'connect selected DSN')
        connected = True
        check(api.SQLGetInfo(database,7,buffer,len(buffer),ctypes.byref(length)),'SQL_DRIVER_VER')
        version = buffer.value.decode('ascii')
        if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',version):
            raise RuntimeError('Unexpected SQL_DRIVER_VER: ' + repr(version))
        return version
    finally:
        if connected:
            check(api.SQLDisconnect(database),'disconnect')
        if database.value:
            check(api.SQLFreeHandle(2,database),'free connection')
        if environment.value:
            check(api.SQLFreeHandle(1,environment),'free environment')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--prefix', type=Path, required=True)
    parser.add_argument('--probe', type=Path, required=True)
    parser.add_argument('--odbc-library', type=Path, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('a command is required')
    root, work = args.root.resolve(), args.work.resolve()
    binaries = root / 'usr/lib/postgresql/18/bin'
    server = work / 'postgres-server'
    server.mkdir()
    database = server / 'database'
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(('PG', 'ODBC'))}
    environment.update(PGHOST='127.0.0.1', PGPORT='5432', PGUSER='odbctest',
                       PGDATABASE='postgres')
    with (server / 'setup.log').open('w') as log:
        def utility(name, *arguments):
            subprocess.run([str(binaries / name), *map(str, arguments)],
                           env=environment, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=60)
        utility('initdb', '-D', database, '-L', root / 'usr/share/postgresql/18',
                '--auth=trust', '--no-locale', '--encoding=UTF8', '--no-sync', '-U', 'odbctest')
        # Fixed ports and trust authentication are confined to the caller's
        # private network namespace; no host database or service is modified.
        options = shlex.join(['-h', '127.0.0.1', '-p', '5432', '-k', '/tmp',
                              '-c', 'max_connections=30', '-c', 'shared_buffers=16MB'])
        utility('pg_ctl', '-D', database, '-l', server / 'server.log', '-o', options, '-w', 'start')
        try:
            utility('createdb', 'odbctestdb')
            driver = root / 'usr/lib/x86_64-linux-gnu/odbc/psqlodbcw.so'
            configuration = work / '.odbc.ini'
            configuration.write_text(''.join(
                f'[{dsn}]\nDriver={driver}\nServername=127.0.0.1\nPort=5432\n'
                'Database=odbctestdb\nUsername=odbctest\n\n'
                for dsn in ('PostgresLinux64Ubuntu', 'PostgresLinux64')))
            environment.update(ODBCINI=str(configuration), ODBCSYSINI=str(work),
                               OTP_ODBC_CONNECTION='DSN=PostgresLinux64Ubuntu;UID=odbctest')
            # Driver-manager configuration is process-global. Select only this
            # namespace's disposable DSN before loading the read-only library.
            os.environ.update({key:environment[key] for key in ('ODBCINI','ODBCSYSINI')})
            version = driver_version(args.odbc_library,environment['OTP_ODBC_CONNECTION'])
            parts = ','.join(str(int(part)) for part in version.split('.'))
            (work/'odbc-driver.config').write_text('{odbc_driver_version,{' + parts + '}}.\n')
            (work/'odbc-driver.json').write_text(json.dumps({'driver_version':version,
                'driver_sha256':hashlib.sha256(driver.read_bytes()).hexdigest(),
                'manager_path':str(args.odbc_library),
                'manager_sha256':hashlib.sha256(args.odbc_library.read_bytes()).hexdigest()},indent=2)+'\n')
            for backend in ('inet', 'socket'):
                environment['OTP_ODBC_STATE'] = str(server / f'{backend}-restart')
                subprocess.run([str(args.prefix / 'bin/erl'), '+S2', '-noshell',
                                '-kernel', 'inet_backend', backend,
                                '-pa', str(args.probe), '-s', 'otp_odbc_probe', 'run'],
                               env=environment, check=True, timeout=90)
            status = subprocess.run(command, env=environment).returncode
        finally:
            utility('pg_ctl', '-D', database, '-m', 'fast', '-w', 'stop')
    raise SystemExit(status)


if __name__ == '__main__':
    main()
