import { createHash, randomUUID } from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const PROJECT_ROOT = fileURLToPath(new URL('../', import.meta.url));
export const LIBRARY_DIR = 'src/shared/UILibrary';
export const ARTIFACT = 'dist/AstralLite.lua';
export const MANIFEST = 'dist/AstralLite.manifest.json';
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const hash = (text) => createHash('sha256').update(text).digest('hex');
const normalize = (text) => text.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n');

/** Lex only; offsets always refer to the original string. Comments are omitted. */
export function scanLua(source, filename = '<source>') {
  const tokens = [];
  let i = 0;
  const fail = (message, offset = i) => {
    const line = source.slice(0, offset).split('\n').length;
    throw new Error(`${filename}:${line}: ${message}`);
  };
  const longOpen = (at) => /^\[(=*)\[/.exec(source.slice(at));
  const longEnd = (at, open) => {
    const end = source.indexOf(`]${open[1]}]`, at + open[0].length);
    if (end < 0) fail('Unterminated long string/comment', at);
    return end + open[1].length + 2;
  };
  while (i < source.length) {
    if (/\s/.test(source[i])) { i++; continue; }
    if (source.startsWith('--', i)) {
      const open = longOpen(i + 2);
      if (open) i = longEnd(i + 2, open);
      else {
        const end = source.indexOf('\n', i + 2);
        i = end < 0 ? source.length : end;
      }
      continue;
    }
    const start = i;
    const quote = source[i];
    if (quote === '"' || quote === "'") {
      i++;
      let closed = false;
      while (i < source.length) {
        if (source[i] === '\\') {
          i++;
          if (source[i] === 'z') {
            i++;
            while (i < source.length && /\s/.test(source[i])) i++;
          } else if (source[i] === '\r' && source[i + 1] === '\n') i += 2;
          else i++;
        } else if (source[i] === quote) { i++; closed = true; break; }
        else if (source[i] === '\n' || source[i] === '\r') fail('Unterminated short string', start);
        else i++;
      }
      if (!closed) fail('Unterminated short string', start);
      tokens.push({ kind: 'string', value: source.slice(start, i), start, end: i });
      continue;
    }
    const open = longOpen(i);
    if (open) {
      i = longEnd(i, open);
      tokens.push({ kind: 'string', value: source.slice(start, i), start, end: i });
      continue;
    }
    // Interpolation can contain executable expressions. Fail closed rather than
    // accidentally treating those expressions as inert string contents.
    if (quote === '`') fail('Interpolated strings are not supported by the static bundler');
    const identifier = /^[A-Za-z_][A-Za-z0-9_]*/.exec(source.slice(i));
    if (identifier) {
      i += identifier[0].length;
      tokens.push({ kind: 'identifier', value: identifier[0], start, end: i });
    } else {
      const operator = ['...', '..', '::', '==', '~=', '<=', '>=', '+=', '-=', '*=', '/=', '//', '->'].find((op) => source.startsWith(op, i));
      i += operator?.length ?? 1;
      tokens.push({ kind: 'symbol', value: source.slice(start, i), start, end: i });
    }
  }
  return tokens;
}

const property = (tokens, i) => ['.', ':'].includes(tokens[i - 1]?.value);
const namedField = (tokens, i) => ['{', ','].includes(tokens[i - 1]?.value) && tokens[i + 1]?.value === '=';

/** Reject aliases as well as dynamic calls: the runtime has no external require. */
export function analyzeModule(source, filename = '<source>') {
  const tokens = scanLua(source, filename);
  const calls = [];
  const consumed = new Set();
  const fail = (token, message) => {
    throw new Error(`${filename}:${source.slice(0, token.start).split('\n').length}: ${message}`);
  };
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token.value !== 'require' || token.kind !== 'identifier' || property(tokens, i) || namedField(tokens, i)) continue;
    let j = i + 1;
    if (tokens[j++]?.value !== '(' || tokens[j]?.value !== 'script') {
      fail(token, 'Unsupported/dynamic require; expected require(script.Child) with a static dot path');
    }
    consumed.add(j++);
    const segments = [];
    while (tokens[j]?.value === '.' && tokens[j + 1]?.kind === 'identifier') {
      segments.push(tokens[j + 1].value);
      consumed.add(j + 1);
      j += 2;
    }
    if (tokens[j]?.value !== ')') fail(token, 'Unsupported/dynamic require; only script child/Parent dot paths are allowed');
    calls.push({ start: token.start, end: tokens[j].end, segments });
    i = j;
  }
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].kind === 'identifier' && tokens[i].value === 'script' && !consumed.has(i) && !property(tokens, i) && !namedField(tokens, i)) {
      fail(tokens[i], 'Unresolved free script reference outside a static require');
    }
    if (tokens[i].kind === 'identifier' && ['__require', '__factories', '__cache', '__loading'].includes(tokens[i].value)) {
      fail(tokens[i], `Reserved bundle identifier ${tokens[i].value}`);
    }
  }
  return { tokens, calls };
}

export async function luaFiles(directory) {
  const files = [];
  async function walk(dir, prefix) {
    const entries = (await fs.readdir(dir, { withFileTypes: true })).sort((a, b) => compare(a.name, b.name));
    for (const entry of entries) {
      const relative = prefix + entry.name;
      if (entry.isSymbolicLink()) throw new Error(`Symlinks are not supported: ${relative}`);
      if (entry.isDirectory()) await walk(path.join(dir, entry.name), `${relative}/`);
      else if (entry.isFile() && entry.name.endsWith('.lua')) files.push(relative);
    }
  }
  await walk(directory, '');
  return files.sort(compare);
}

function versionFrom(source) {
  const tokens = scanLua(source, `${LIBRARY_DIR}/init.lua`);
  const values = [];
  for (let i = 0; i < tokens.length - 4; i++) {
    if (tokens[i].value === 'UILibrary' && tokens[i + 1].value === '.' && tokens[i + 2].value === 'Version' && tokens[i + 3].value === '=') {
      const literal = tokens[i + 4];
      if (literal.kind !== 'string' || !/^["'][0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?["']$/.test(literal.value)) {
        throw new Error('UILibrary.Version must be a literal semantic version string');
      }
      const next = tokens[i + 5];
      const gap = source.slice(literal.end, next?.start ?? source.length);
      const continuation = new Set(['..', '+', '-', '*', '/', '//', '%', '^', 'and', 'or', '==', '~=', '<', '>', '<=', '>=', ':', '::', '[', '(']);
      if (next && (continuation.has(next.value) || (next.value !== ';' && !gap.includes('\n')))) throw new Error('UILibrary.Version must be a standalone literal assignment');
      values.push(literal.value.slice(1, -1));
    }
  }
  if (values.length !== 1) throw new Error('Entry must declare exactly one literal UILibrary.Version assignment');
  return values[0];
}

/** Pure graph/render step. Keys are relative Lua paths, including init.lua. */
export function bundleSources(input) {
  const entries = input instanceof Map ? [...input] : Object.entries(input);
  entries.sort(([a], [b]) => compare(a, b));
  const modules = new Map();
  const nodes = new Map([['', { parent: null }]]);
  for (const [file, raw] of entries) {
    if (file.includes('\\') || file.startsWith('/') || file.split('/').some((part) => !part || part === '.' || part === '..') || !file.endsWith('.lua')) {
      throw new Error(`Invalid relative Lua path: ${file}`);
    }
    if (file.endsWith('.client.lua') || file.endsWith('.server.lua')) throw new Error(`Library source must be a ModuleScript: ${file}`);
    const parts = file.split('/');
    const basename = parts.pop();
    let parent = '';
    for (const part of parts) {
      const id = parent ? `${parent}/${part}` : part;
      if (!nodes.has(id)) nodes.set(id, { parent });
      parent = id;
    }
    const id = basename === 'init.lua' ? parent : (parent ? `${parent}/` : '') + basename.slice(0, -4);
    if (!nodes.has(id)) nodes.set(id, { parent });
    const node = nodes.get(id);
    if (node.module) throw new Error(`Ambiguous Rojo module node: ${file} and ${node.module.file}`);
    const source = normalize(raw);
    const module = { id: file, file, node: id, source, ...analyzeModule(source, file), dependencies: [] };
    node.module = module;
    modules.set(file, module);
  }
  const entry = modules.get('init.lua');
  if (!entry) throw new Error('Missing library entry init.lua');
  for (const module of modules.values()) {
    for (const call of module.calls) {
      let node = nodes.get(module.node);
      let id = module.node;
      for (const segment of call.segments) {
        id = segment === 'Parent' ? node.parent : (id ? `${id}/${segment}` : segment);
        node = nodes.get(id);
        if (!node) throw new Error(`${module.file}: Missing dependency script.${call.segments.join('.')} (outside library or missing node)`);
      }
      if (!node.module) throw new Error(`${module.file}: Dependency script.${call.segments.join('.')} resolves to a folder, not a ModuleScript`);
      call.target = node.module.id;
      module.dependencies.push(call.target);
    }
    module.dependencies = [...new Set(module.dependencies)].sort(compare);
  }
  const order = [];
  const state = new Map();
  const stack = [];
  function visit(id) {
    if (state.get(id) === 'done') return;
    if (state.get(id) === 'loading') throw new Error(`Dependency cycle: ${[...stack.slice(stack.indexOf(id)), id].join(' -> ')}`);
    state.set(id, 'loading');
    stack.push(id);
    for (const dependency of modules.get(id).dependencies) visit(dependency);
    stack.pop();
    state.set(id, 'done');
    order.push(id);
  }
  visit(entry.id);
  const unreachable = [...modules.keys()].filter((id) => !state.has(id));
  if (unreachable.length) throw new Error(`Unreferenced library Lua files: ${unreachable.join(', ')}`);
  const version = versionFrom(entry.source);
  const sources = [...modules.values()].map((module) => ({ path: `${LIBRARY_DIR}/${module.file}`, sha256: hash(module.source) }));
  const sourceSha256 = hash(JSON.stringify(sources));
  const header = [`-- AstralLite ${version} | generated by scripts/build.mjs`, `-- Source SHA256: ${sourceSha256}`, ...sources.map((item) => `-- ${item.path} SHA256 ${item.sha256}`)].join('\n');
  const factories = order.map((id) => {
    const module = modules.get(id);
    let source = module.source;
    for (const call of [...module.calls].reverse()) {
      source = source.slice(0, call.start) + `__require(${JSON.stringify(call.target)})` + source.slice(call.end);
    }
    return `__factories[${JSON.stringify(id)}] = function(__require)\n${source}\nend`;
  }).join('\n\n');
  const code = `${header}\n\nlocal __factories = {}\nlocal __cache = {}\nlocal __loading = {}\n\n${factories}\n\nlocal function __require(id)\n\tif __loading[id] then error("Circular module load: " .. id, 2) end\n\tif __cache[id] ~= nil then return __cache[id] end\n\tlocal factory = __factories[id]\n\tif not factory then error("Unknown bundled module: " .. id, 2) end\n\t__loading[id] = true\n\tlocal ok, result = pcall(factory, __require)\n\t__loading[id] = nil\n\tif not ok then error(result, 0) end\n\tif result == nil then error("Bundled module returned nil: " .. id, 2) end\n\t__cache[id] = result\n\treturn result\nend\n\nreturn __require("init.lua")\n`;
  const manifest = { version, entry: `${LIBRARY_DIR}/init.lua`, sourceSha256, artifactSha256: hash(code), sources, modules: order };
  return { code, manifest, manifestText: `${JSON.stringify(manifest, null, 2)}\n`, modules, order };
}

export async function generateBuild({ root = PROJECT_ROOT } = {}) {
  const directory = path.join(root, LIBRARY_DIR);
  const files = await luaFiles(directory);
  const sources = new Map(await Promise.all(files.map(async (file) => [file, await fs.readFile(path.join(directory, file), 'utf8')])));
  return bundleSources(sources);
}

async function atomicReplace(temporary, destination) {
  for (let attempt = 0; ; attempt++) {
    try { await fs.rename(temporary, destination); return; }
    catch (error) {
      // Windows indexers/antivirus can briefly lock a just-read destination.
      // Retry the atomic rename; never unlink a valid artifact as a fallback.
      if (process.platform !== 'win32' || !['EPERM', 'EACCES', 'EBUSY'].includes(error.code) || attempt >= 5) throw error;
      await new Promise((resolve) => setTimeout(resolve, 50 * (attempt + 1)));
    }
  }
}

export async function build({ root = PROJECT_ROOT, check = false } = {}) {
  // Finish all scanning, resolution and rendering before touching dist.
  const result = await generateBuild({ root });
  const outputs = [[ARTIFACT, result.code], [MANIFEST, result.manifestText]];
  if (check) {
    for (const [file, expected] of outputs) {
      let actual;
      try { actual = await fs.readFile(path.join(root, file)); }
      catch (error) { if (error.code !== 'ENOENT') throw error; }
      if (!actual?.equals(Buffer.from(expected))) throw new Error(`Stale or missing ${file}; run node scripts/build.mjs`);
    }
  } else {
    await fs.mkdir(path.join(root, 'dist'), { recursive: true });
    const staged = [];
    try {
      for (const [file, content] of outputs) {
        const destination = path.join(root, file);
        const temporary = `${destination}.${randomUUID()}.tmp`;
        staged.push([temporary, destination]);
        await fs.writeFile(temporary, content, { flag: 'wx' });
      }
      // Publish Lua last: a failed manifest replacement cannot overwrite the
      // previous valid bundle. Each rename is atomic; --check detects an
      // interrupted pair. No partial Lua file is ever published.
      for (const [temporary, destination] of [...staged].reverse()) await atomicReplace(temporary, destination);
    } finally {
      await Promise.all(staged.map(([temporary]) => fs.rm(temporary, { force: true })));
    }
  }
  return result;
}

export async function main(args = process.argv.slice(2)) {
  if (args.some((arg) => arg !== '--check') || args.length > 1) throw new Error('Usage: node scripts/build.mjs [--check]');
  const result = await build({ check: args.includes('--check') });
  console.log(`${args.includes('--check') ? 'Checked' : 'Built'} ${ARTIFACT}: ${result.order.length} modules, v${result.manifest.version}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
