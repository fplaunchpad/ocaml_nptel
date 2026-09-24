/* Local-file transport for the existing x-ocaml and v86 runtimes. */
(function () {
  'use strict';
  const root = new URL('../../', document.currentScript.src);
  const workers = new Map();
  const pending = new Map();
  function bytes(encoded) {
    const raw = atob(encoded);
    const result = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) result[i] = raw.charCodeAt(i);
    return result;
  }
  function key(url) {
    const resolved = new URL(url, document.baseURI);
    resolved.search = '';
    resolved.hash = '';
    if (!resolved.href.startsWith(root.href)) throw new Error('Resource outside book: ' + url);
    return decodeURIComponent(resolved.href.slice(root.href.length));
  }
  function read(url) {
    const name = key(url);
    if (pending.has(name)) return pending.get(name).promise;
    const script = document.createElement('script');
    const entry = {};
    entry.promise = new Promise((resolve, reject) => {
      entry.resolve = resolve;
      entry.reject = reject;
    });
    pending.set(name, entry);
    script.src = new URL(name + '.js', root).href;
    script.onerror = () => entry.reject(new Error('Cannot load bundled resource: ' + name));
    script.onload = () => {
      if (!entry.received) entry.reject(new Error('Empty bundled resource: ' + name));
    };
    document.head.appendChild(script);
    return entry.promise.finally(() => { script.remove(); pending.delete(name); });
  }
  window.NptelOffline = {
    addWorker(name, encoded) {
      workers.set(name, new Blob([bytes(encoded)], {type: 'text/javascript'}));
    },
    createWorker(url, extra) {
      const sources = [url, extra].filter(Boolean).map(resource => {
        const source = workers.get(key(resource));
        if (!source) throw new Error('Missing bundled OCaml worker: ' + resource);
        return source;
      });
      const workerURL = URL.createObjectURL(new Blob(sources.flatMap(source => [source, '\n']),
        {type: 'text/javascript'}));
      const worker = new Worker(workerURL);
      // The URL remains valid while the worker starts. The browser releases
      // all document-owned blob URLs when the reader leaves the page.
      return worker;
    },
    register(name, encoded) {
      const entry = pending.get(name);
      if (!entry) throw new Error('Unexpected bundled resource: ' + name);
      entry.received = true;
      entry.resolve(bytes(encoded));
    },
    async loadVM(url, options) {
      if (options.signal?.aborted) return;
      let data = await read(url);
      if (options.signal?.aborted) return;
      if (options.range) data = data.slice(options.range.start,
        options.range.start + options.range.length);
      const request = {status: options.range ? 206 : 200, getResponseHeader: () => null};
      options.progress?.({lengthComputable: true, loaded: data.length, total: data.length,
        target: request});
      const response = options.as_json ? JSON.parse(new TextDecoder().decode(data)) : data.buffer;
      options.done?.(response, request);
    }
  };
})();
