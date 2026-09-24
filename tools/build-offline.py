#!/usr/bin/env python3
"""Build a tar.gz containing the book and browser runtimes that open directly via file://."""
import argparse
import base64
import re
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import tempfile

REPO = Path(__file__).resolve().parent.parent


def vm_chunks(vm):
    """Check every regular file in the v86 manifest before packaging."""
    for name in ('ocaml-fs.json', 'ocaml-state.bin.zst'):
        if not (vm / name).is_file():
            raise ValueError('Missing VM file: ' + str(vm / name))
    manifest = json.loads((vm / 'ocaml-fs.json').read_text())
    chunks = set()

    def walk(entries):
        for entry in entries:
            mode, content = entry[3], entry[6]
            if stat.S_ISDIR(mode):
                walk(content)
            elif stat.S_ISREG(mode):
                if not isinstance(content, str) or Path(content).name != content:
                    raise ValueError('Invalid VM chunk name: ' + repr(content))
                path = vm / 'ocaml-rootfs-flat' / content
                if not path.is_file():
                    raise ValueError('Missing VM chunk: ' + str(path))
                chunks.add(content)

    walk(manifest['fsroot'])
    if not chunks:
        raise ValueError('VM manifest contains no file chunks')
    return chunks


def replace_once(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise ValueError('Offline adapter no longer matches ' + str(path))
    path.write_text(text.replace(old, new))


def binary_script(source, target, key, method='register'):
    target.parent.mkdir(parents=True, exist_ok=True)
    encoded = base64.b64encode(source.read_bytes()).decode('ascii')
    target.write_text('NptelOffline.{}({}, {});\n'.format(
        method, json.dumps(key), json.dumps(encoded)))


def make_file_bundle(site, vm, chunks):
    offline = site / 'assets/offline'
    offline.mkdir()
    shutil.copyfile(REPO / 'tools/offline/runtime.js', offline / 'runtime.js')
    # Classic scripts load from file://; modules and fetch do not. Keep the
    # existing runtime logic and adapt only its resource transport.
    for bundle in ('x-ocaml', 'x-oxcaml'):
        host = site / 'assets' / bundle / 'x-ocaml.js'
        replace_once(host, 'function make(extra_load, url$1){',
                     'function make(extra_load, url$1){\n'
                     'return window.NptelOffline.createWorker(caml_jsstring_of_string(url$1), '
                     'extra_load ? caml_jsstring_of_string(extra_load[1]) : null);')
    for path in (site / 'assets').glob('*/**/*.js'):
        if path.name not in ('x-ocaml.worker.js', 'm09-extras.js', 'portable.js'):
            continue
        key = path.relative_to(site).as_posix()
        binary_script(path, Path(str(path) + '.bundle.js'), key, 'addWorker')
        path.unlink()
    replace_once(site / 'assets/vm/libv86.js',
                 'else pa=async function(a,b,c){',
                 'else pa=async function(a,b,c){return window.NptelOffline.loadVM(a,b);')
    # WebKit can still be loading a Blob worker when its constructor returns.
    # Keep the scheduler URL alive until the worker has actually responded.
    replace_once(site / 'assets/vm/libv86.js',
                 'this.worker.onmessage=c=>this.yield_callback(c.data);URL.revokeObjectURL(b)',
                 'this.worker.onmessage=c=>{URL.revokeObjectURL(b);this.yield_callback(c.data)}')
    replace_once(site / 'assets/vm/vm-terminal.js',
                 '"https://fplaunchpad.org/ocaml-browser-vm/current"',
                 'new URL("data", document.currentScript.src).href')
    for name in ('v86.wasm', 'seabios.bin', 'vgabios.bin'):
        source = site / 'assets/vm' / name
        binary_script(source, Path(str(source) + '.js'), 'assets/vm/' + name)
        source.unlink()
    for name in ('ocaml-fs.json', 'ocaml-state.bin.zst'):
        key = 'assets/vm/data/' + name
        binary_script(vm / name, site / (key + '.js'), key)
    for name in sorted(chunks):
        key = 'assets/vm/data/ocaml-rootfs-flat/' + name
        binary_script(vm / 'ocaml-rootfs-flat' / name, site / (key + '.js'), key)
    index = (site / 'search-index.json').read_text()
    (offline / 'search-index.js').write_text('window.NptelSearchIndex = ' + index + ';\n')
    for page in site.rglob('*.html'):
        text = page.read_text()
        prefix = os.path.relpath(site, page.parent).replace(os.sep, '/')
        text = text.replace('/assets/', prefix + '/assets/')
        text = text.replace('<script type="module">', '<script>')
        text = re.sub(r"    import Reveal from '[^']*/reveal.esm.js';", '', text)
        scripts = ['assets/offline/runtime.js', 'assets/reveal/dist/reveal.js']
        for resource in re.findall(r'src-(?:worker|load)="([^"?]+)(?:[^"\n]*)"', text):
            scripts.append(resource[len(prefix) + 1:] + '.bundle.js')
        if page.name == 'index.html':
            scripts.append('assets/offline/search-index.js')
            text = text.replace("fetch('search-index.json')\n            .then(function (r) { return r.json(); })",
                                'Promise.resolve(window.NptelSearchIndex)')
        tags = ''.join('<script src="' + prefix + '/' + src + '"></script>\n' for src in scripts)
        text = text.replace('</title>', '</title>\n' + tags, 1)
        page.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path,
                        default=REPO / 'dist' / 'ocaml-nptel-offline.tar.gz')
    parser.add_argument('--vm-dir', type=Path,
                        default=REPO / '_vm-prototype' / 'images-v6',
                        help='directory containing matching ocaml-fs.json, '
                             'ocaml-state.bin.zst, and ocaml-rootfs-flat/')
    args = parser.parse_args()
    vm = args.vm_dir.resolve()
    try:
        chunks = vm_chunks(vm)
    except (ValueError, OSError, KeyError, IndexError, TypeError) as exc:
        parser.error('{}\nSupply --vm-dir with a complete course VM image '
                     '(see tools/vm-image/README.md).'.format(exc))
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Build in isolation so stale preview pages never enter the archive and
    # a failed build leaves both the preview and any previous archive intact.
    with tempfile.TemporaryDirectory(prefix='nptel-offline-') as tmp:
        package = Path(tmp) / 'ocaml-nptel-offline'
        site = package
        env = dict(os.environ, SITE_DIR=str(site), ASSET_ROOT='', COPY_ASSETS='1')
        subprocess.run(['bash', str(REPO / 'tools/build-site.sh')],
                       cwd=REPO, env=env, check=True)
        make_file_bundle(site, vm, chunks)
        shutil.copyfile(REPO / 'tools/offline/README.txt', package / 'README.txt')
        for name in ('LICENSE', 'LICENSES.md'):
            shutil.copyfile(REPO / name, package / name)
        # The development fixture is not part of the book.
        shutil.rmtree(site / 'test')
        with tempfile.NamedTemporaryFile(dir=output.parent, suffix='.tar.gz',
                                         delete=False) as f:
            pending = Path(f.name)
        try:
            with tarfile.open(pending, 'w:gz') as archive:
                archive.add(package, arcname=package.name,
                            filter=lambda member: None if member.name.endswith('.DS_Store') else member)
            pending.replace(output)
        finally:
            pending.unlink(missing_ok=True)
    print('Built {} ({:.1f} MiB; {} VM chunks)'.format(
        output, output.stat().st_size / 1024**2, len(chunks)))


if __name__ == '__main__':
    main()
