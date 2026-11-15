"""Provision pinned portable Windows CI inputs without system installation.

Load the selected x64 MSVC/Windows SDK environment before invoking this script.
Reusable archives stay in downloads; extracted sources and builds stay in tmp.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fetch(record,downloads):
    output=downloads/record['file']
    output.parent.mkdir(parents=True,exist_ok=True)
    if not output.is_file():
        temporary=output.with_name(output.name+'.download')
        with urllib.request.urlopen(record['url']) as response,temporary.open('wb') as stream:
            shutil.copyfileobj(response,stream)
        if digest(temporary)!=record['sha256']:
            temporary.unlink()
            raise RuntimeError('Downloaded input hash mismatch: '+record['file'])
        temporary.replace(output)
    if digest(output)!=record['sha256']:
        raise RuntimeError('Cached input hash mismatch: '+record['file'])
    return output


def extract(archive,destination):
    if destination.exists():
        raise RuntimeError('CI extraction requires a fresh task-owned directory: '+str(destination))
    destination.mkdir(parents=True)
    if archive.name.endswith('.zip'):
        with zipfile.ZipFile(archive) as handle:
            for item in handle.infolist():
                target=(destination/item.filename).resolve()
                if not target.is_relative_to(destination.resolve()):
                    raise RuntimeError('Archive entry escapes its source directory')
            handle.extractall(destination)
    else:
        with tarfile.open(archive) as handle:
            handle.extractall(destination,filter='data')
    return destination


def unique(root,pattern):
    matches=list(root.rglob(pattern))
    if len(matches)!=1:raise RuntimeError('Expected one '+pattern+' below '+str(root))
    return matches[0]


def run(arguments,cwd,logs,label):
    with (logs/(label+'.log')).open('wb') as stream:
        result=subprocess.run(list(map(str,arguments)),cwd=cwd,stdout=stream,stderr=subprocess.STDOUT)
    if result.returncode:
        print((logs/(label+'.log')).read_text(errors='replace', encoding="utf-8")[-20000:])
        raise RuntimeError(label+' failed: '+str(result.returncode))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace',required=True,type=Path)
    parser.add_argument('--build-type',required=True,choices=('Release','Debug'))
    parser.add_argument('--github-env',type=Path)
    parser.add_argument('--check-inputs',action='store_true')
    args=parser.parse_args()
    workspace=args.workspace.resolve()
    downloads=workspace/'downloads/windows-ci'
    records=json.loads(Path(__file__).with_name('windows_inputs.json').read_text(encoding="utf-8"))
    inputs={record['file']:fetch(record,downloads) for record in records}
    if args.check_inputs:
        print(json.dumps({'status':'verified','inputs':records},indent=2))
        return
    if os.name!='nt' or not shutil.which('cl.exe'):
        raise RuntimeError('A selected native x64 MSVC environment is required')
    root=workspace/'tmp'/('windows-ci-dependencies-'+args.build_type)
    if root.exists():raise RuntimeError('Use a fresh task work root for CI dependency outputs')
    root.mkdir(parents=True)
    if shutil.disk_usage(root).free<12*1024**3:raise RuntimeError('Native dependency build requires 12 GiB free')
    logs=root/'logs';logs.mkdir()
    openssl=extract(inputs['openssl-3.5.9.tar.gz'],root/'openssl-source')/'openssl-3.5.9'
    wx_extract=extract(inputs['wxWidgets-3.2.6.zip'],root/'wx-source')
    wx=unique(wx_extract,'wx-config.in').parent
    webview=extract(inputs['webview2-1.0.705.50.zip'],root/'webview-source')
    shutil.copytree(webview,wx/'3rdparty/webview2',dirs_exist_ok=True)
    flex=unique(extract(inputs['win_flex_bison-2.5.25.zip'],root/'flex'),'win_flex.exe')
    nsis=unique(extract(inputs['nsis-3.11.zip'],root/'nsis'),'makensis.exe')
    jom=unique(extract(inputs['jom_1_1_4.zip'],root/'jom'),'jom.exe')
    if digest(jom)!='93eb6b9df1a61b75f8d279578b200706a98096d85773ae3a09bbefea365cc2e8':
        raise RuntimeError('Pinned jom executable hash mismatch')
    crypto_prefix=root/'openssl-install'
    crypto_build=root/'openssl-build';crypto_build.mkdir()
    options=['perl',openssl/'Configure','VC-WIN64A','no-shared','no-asm','--libdir=lib',
             '-MDd' if args.build_type=='Debug' else '-MD','-Z7',
             '--prefix='+str(crypto_prefix),'--openssldir='+str(crypto_prefix/'ssl')]
    if args.build_type=='Debug':options.append('--debug')
    run(options,crypto_build,logs,'openssl-configure')
    run([jom,'/NOLOGO','/J','6','build_libs'],crypto_build,logs,'openssl-build')
    run([jom,'/NOLOGO','/J','3','install_dev'],crypto_build,logs,'openssl-install')
    wx_prefix=root/'wx-install';wx_build=root/'wx-build'
    run(['cmake','-S',wx,'-B',wx_build,'-G','Ninja','-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
         '-DCMAKE_BUILD_TYPE='+args.build_type,'-DCMAKE_INSTALL_PREFIX='+str(wx_prefix),
         '-DwxBUILD_SHARED=OFF','-DwxBUILD_USE_STATIC_RUNTIME=OFF','-DwxBUILD_INSTALL=ON',
         '-DwxBUILD_SAMPLES=OFF','-DwxBUILD_DEMOS=OFF','-DwxBUILD_TESTS=OFF',
         '-DwxUSE_POSTSCRIPT=ON','-DwxUSE_WEBVIEW=ON','-DwxUSE_WEBVIEW_EDGE=ON',
         '-DwxUSE_WEBVIEW_EDGE_STATIC=OFF','-DwxBUILD_COMPATIBILITY=3.0'],root,logs,'wx-configure')
    run(['cmake','--build',wx_build,'--parallel','3'],root,logs,'wx-build')
    run(['cmake','--install',wx_build],root,logs,'wx-install')
    redist=Path(os.environ['VCToolsRedistDir'])
    runtime=[]
    if args.build_type=='Release':
        crt=list((redist/'x64').glob('*.CRT'))
        if len(crt)!=1:raise RuntimeError('Select one matching x64 Release MSVC CRT directory')
        runtime+=list(crt[0].glob('*.dll'))
    loader=[path for path in webview.rglob('WebView2Loader.dll') if '/x64/' in path.as_posix().lower()]
    if len(loader)!=1:raise RuntimeError('Select one pinned x64 WebView2 loader')
    runtime+=loader
    installers=list(redist.parent.rglob('vc_redist.x64.exe'))
    if not installers:raise RuntimeError('The selected MSVC deployment installation lacks its redistributable installer')
    selected={'OPENSSL_ROOT_DIR':str(crypto_prefix),'OTP_WX_ROOT':str(wx_prefix),
              'FLEX_EXECUTABLE':str(flex),
              'OTP_NSIS_EXECUTABLE':str(nsis),'OTP_VC_REDIST_EXECUTABLE':str(sorted(installers)[-1]),
              'OTP_WINDOWS_RUNTIME_DLLS':';'.join(map(str,runtime))}
    sdk=Path(os.environ['WindowsSdkDir'])
    sdk_version=os.environ['WindowsSDKVersion'].rstrip('\\/')
    selected.update(ODBC_INCLUDE_DIR=str(sdk/'Include'/sdk_version/'um'),
                    ODBC_LIBRARY=str(sdk/'Lib'/sdk_version/'um/x64/odbc32.lib'))
    receipt={'inputs':records,'build_type':args.build_type,'selectors':selected,
             'runtime_hashes':{str(path):digest(path) for path in runtime},
             'system_packages_installed':False}
    (root/'receipt.json').write_text(json.dumps(receipt,indent=2))
    if args.github_env:
        with args.github_env.open('a',encoding='utf-8') as stream:
            for key,value in selected.items():stream.write(key+'='+value+'\n')
    print(json.dumps(receipt,indent=2))


if __name__=='__main__':
    main()
