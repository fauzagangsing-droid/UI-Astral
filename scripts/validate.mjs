import { promises as fs } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { ARTIFACT, LIBRARY_DIR, PROJECT_ROOT, build, luaFiles, scanLua } from './build.mjs';

export const COMPONENTS = Object.freeze([
  'Button', 'ColorPicker', 'Divider', 'Dropdown', 'Keybind', 'Label',
  'MultiDropdown', 'Notification', 'Paragraph', 'ProgressBar', 'SearchBox',
  'Section', 'Slider', 'TextBox', 'Toggle',
]);
const forbidden = new Set([
  'loadstring', 'loadfile', 'dofile', 'getgenv', 'getrenv', 'getsenv', 'gethui',
  'getexecutorname', 'identifyexecutor', 'syn', 'fluxus', 'http_request',
  'request', 'HttpGet', 'HttpGetAsync', 'HttpPost', 'HttpPostAsync',
  'readfile', 'writefile', 'appendfile', 'hookfunction', 'hookmetamethod',
  'getrawmetatable', 'setreadonly', 'checkcaller', 'newcclosure',
  'queue_on_teleport', 'getconnections',
]);
function ensure(condition, message) {
  if (!condition) throw new Error(message);
}
const strings = (tokens) => tokens.filter((token) => token.kind === 'string').map((token) => token.value.slice(1, -1));
const hasSequence = (tokens, sequence) => tokens.some((_, i) => sequence.every((value, j) => tokens[i + j]?.value === value));

export function checkForbidden(source, filename) {
  for (const token of scanLua(source, filename)) {
    if (token.kind === 'identifier' && forbidden.has(token.value)) {
      throw new Error(`${filename}: Forbidden runtime API ${token.value}`);
    }
  }
}

async function checkMapping(root, result) {
  const project = JSON.parse(await fs.readFile(path.join(root, 'default.project.json'), 'utf8'));
  const tree = project.tree;
  ensure(tree?.$className === 'DataModel', 'Rojo root must be a DataModel');
  ensure(tree.ReplicatedStorage?.UILibrary?.$path === LIBRARY_DIR, 'Rojo must map ReplicatedStorage.UILibrary to the library directory');
  ensure(tree.StarterPlayer?.StarterPlayerScripts?.$path === 'src/client', 'Rojo must map StarterPlayer.StarterPlayerScripts to src/client');
  const paths = [];
  function walk(node) {
    if (!node || typeof node !== 'object') return;
    if ('$path' in node) paths.push(node.$path);
    for (const [key, child] of Object.entries(node)) if (!key.startsWith('$')) walk(child);
  }
  walk(tree);
  ensure(paths.length === 2 && paths.every((item) => item === LIBRARY_DIR || item === 'src/client'), 'Rojo must map only library and client sources (not archive, dist or tests)');
  let map;
  try { map = JSON.parse(await fs.readFile(path.join(root, 'build/sourcemap.json'), 'utf8')); }
  catch (error) { if (error.code === 'ENOENT') return; throw error; }
  function child(node, name) { return node?.children?.find((item) => item.name === name); }
  const library = child(child(map, 'ReplicatedStorage'), 'UILibrary');
  const main = child(child(child(map, 'StarterPlayer'), 'StarterPlayerScripts'), 'Main');
  ensure(library?.className === 'ModuleScript', 'Sourcemap UILibrary must be a ModuleScript');
  ensure(main?.className === 'LocalScript' && main.filePaths?.includes('src/client/Main.client.lua'), 'Sourcemap Main mapping is missing/incorrect');
  const mapped = new Map();
  function collect(node, parent = '') {
    for (const file of node.filePaths ?? []) {
      const normalized = file.replace(/\\/g, '/');
      ensure(!path.isAbsolute(file) && !/^[A-Za-z]:/.test(file), 'Sourcemap paths must be project-relative');
      ensure(normalized === 'default.project.json' || normalized.startsWith('src/'), `Unexpected sourcemap source: ${normalized}`);
      if (normalized.endsWith('.lua')) {
        ensure(!mapped.has(normalized), `Duplicate sourcemap source: ${normalized}`);
        mapped.set(normalized, { node, location: parent });
      }
    }
    for (const item of node.children ?? []) collect(item, parent ? `${parent}/${item.name}` : item.name);
  }
  collect(map);
  for (const module of result.modules.values()) {
    const file = `${LIBRARY_DIR}/${module.file}`;
    const expected = `ReplicatedStorage/UILibrary${module.node ? `/${module.node}` : ''}`;
    const record = mapped.get(file);
    ensure(record?.node.className === 'ModuleScript' && record.location === expected, `Sourcemap is stale/incorrect for ${file}; regenerate it with Rojo`);
  }
  ensure(mapped.size === result.modules.size + 1, 'Sourcemap has unexpected Lua sources');
}

async function checkAPI(root, result) {
  const entry = result.modules.get('init.lua').tokens;
  const registry = result.modules.get('Components/init.lua');
  ensure(registry, 'Missing Components/init.lua registry');
  const registered = [];
  for (let i = 0; i < registry.tokens.length; i++) {
    if (registry.tokens[i].kind === 'identifier' && registry.tokens[i + 1]?.value === '=' && registry.tokens[i + 2]?.value === 'require') registered.push(registry.tokens[i].value);
  }
  ensure(registered.length === 15 && new Set(registered).size === 15 && COMPONENTS.every((name) => registered.includes(name)), 'Component registry must contain exactly the 15 public factories');
  for (const name of COMPONENTS) {
    const index = registry.tokens.findIndex((token, i) => token.value === name && registry.tokens[i + 1]?.value === '=' && registry.tokens[i + 2]?.value === 'require');
    const call = registry.calls.find((item) => item.start === registry.tokens[index + 2]?.start);
    ensure(call?.target === `Components/${name}.lua`, `Registry ${name} must require its matching module`);
  }
  ensure(hasSequence(entry, ['function', 'UILibrary', '.', 'new', '(']), 'Missing UILibrary.new public API');
  ensure(hasSequence(entry, ['function', 'UILibrary', '.', 'CreateWindow', '(']) || hasSequence(entry, ['function', 'UILibrary', ':', 'CreateWindow', '(']), 'Missing UILibrary.CreateWindow public API');
  ensure(hasSequence(entry, ['function', 'UI', '.', 'CreateNotification', '(']), 'Missing UI.CreateNotification public API');
  ensure(hasSequence(entry, ['function', 'UI', '.', 'Destroy', '(']), 'Missing UI.Destroy public API');
  ensure(hasSequence(entry, ['UI', '[', '"Create"', '..', 'kind', ']']) || hasSequence(entry, ['UI', '[', "'Create'", '..', 'kind', ']']), 'Missing generated UI.CreateX public API');
  ensure(hasSequence(entry, ['for', 'kind', 'in', 'pairs', '(', 'Components', ')']), 'CreateX factories must enumerate Components');
  const main = scanLua(await fs.readFile(path.join(root, 'src/client/Main.client.lua'), 'utf8'), 'Main.client.lua');
  ensure(hasSequence(main, [':', 'CreateWindow', '(']) || hasSequence(main, ['.', 'CreateWindow', '(']), 'Main must use CreateWindow');
  ensure(hasSequence(main, [':', 'CreateTab', '(']) || hasSequence(main, ['.', 'CreateTab', '(']), 'Main must create its tabs');
  for (const token of main) ensure(token.kind !== 'identifier' || !COMPONENTS.some((name) => token.value === `Create${name}`), 'Main must not auto-create demo components');
  const mainStrings = strings(main);
  ensure(!mainStrings.some((value) => COMPONENTS.some((name) => value === `Create${name}`)) && !hasSequence(main, ['[', '"Create"', '..']) && !hasSequence(main, ['[', "'Create'", '..']), 'Main must not dynamically auto-create components');
  for (const name of ['Home', 'Combat', 'Teleport', 'Player', 'Visuals', 'World', 'Misc', 'Settings']) ensure(mainStrings.includes(name), `Main is missing the ${name} tab`);
  const testFiles = (await luaFiles(path.join(root, 'tests'))).filter((file) => !file.includes('/'));
  ensure(testFiles.length > 0, 'No Lua tests found');
  const testTokens = [];
  for (const file of testFiles) testTokens.push(...scanLua(await fs.readFile(path.join(root, 'tests', file), 'utf8'), `tests/${file}`));
  const testStrings = strings(testTokens);
  for (const name of COMPONENTS) ensure(testStrings.includes(name) || testTokens.some((token) => token.value === `Create${name}`), `Lua tests do not cover ${name}`);
  for (const method of ['Destroy', 'GetValue', 'SetValue']) ensure(testTokens.some((token) => token.value === method) || testStrings.includes(method), `Lua tests lack ${method} coverage`);
  const bundle = scanLua(result.code, ARTIFACT);
  ensure(!bundle.some((token, i) => token.kind === 'identifier' && ['script', 'require'].includes(token.value) && !['.', ':'].includes(bundle[i - 1]?.value) && !(['{', ','].includes(bundle[i - 1]?.value) && bundle[i + 1]?.value === '=')), 'Bundle contains unresolved script/require tokens');
}

export async function checkDocs(root) {
  const files = [];
  async function walk(dir) {
    for (const entry of await fs.readdir(path.join(root, dir), { withFileTypes: true })) {
      const relative = path.posix.join(dir, entry.name);
      if (entry.isDirectory()) await walk(relative);
      else if (entry.isFile() && entry.name.endsWith('.md')) files.push(relative);
    }
  }
  for (const entry of await fs.readdir(root, { withFileTypes: true })) if (entry.isFile() && entry.name.endsWith('.md')) files.push(entry.name);
  await walk('docs');
  await walk('tests');
  for (const file of files) {
    const markdown = (await fs.readFile(path.join(root, file), 'utf8')).replace(/```[^\n]*\n[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '');
    const targets = [...markdown.matchAll(/\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+["'][^\n]*?["'])?\s*\)/g)].map((match) => match[1]);
    targets.push(...[...markdown.matchAll(/^\s{0,3}\[[^\]]+\]:\s*(<[^>]+>|\S+)/gm)].map((match) => match[1]));
    for (let target of targets) {
      target = target.replace(/^<|>$/g, '');
      if (/^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(target)) continue;
      target = decodeURIComponent(target.split(/[?#]/)[0]);
      if (!target) continue;
      const resolved = path.resolve(path.dirname(path.join(root, file)), target);
      const relative = path.relative(root, resolved);
      ensure(relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative), `${file}: Local link escapes project: ${target}`);
      try { await fs.access(resolved); }
      catch { throw new Error(`${file}: Broken local link: ${target}`); }
    }
  }
}

export async function compileSources(root, compiler) {
  const executable = path.resolve(root, compiler);
  await fs.access(executable);
  const files = (await luaFiles(path.join(root, 'src'))).map((file) => `src/${file}`);
  files.push(...(await luaFiles(path.join(root, 'tests'))).filter((file) => !file.includes('/')).map((file) => `tests/${file}`), ARTIFACT);
  for (const file of files) {
    const child = spawnSync(executable, ['--null', file], { cwd: root, shell: false, encoding: 'utf8', timeout: 30_000, windowsHide: true });
    if (child.error) throw new Error(`Compiler failed for ${file}: ${child.error.message}`);
    ensure(child.status === 0, `Compiler rejected ${file}:\n${child.stderr || child.stdout || `exit ${child.status}, signal ${child.signal}`}`);
  }
  return files.length;
}

export async function validate({ root = PROJECT_ROOT, compiler = process.env.LUAU_COMPILER } = {}) {
  const result = await build({ root, check: true });
  await checkMapping(root, result);
  await checkAPI(root, result);
  for (const file of await luaFiles(path.join(root, 'src'))) checkForbidden(await fs.readFile(path.join(root, 'src', file), 'utf8'), `src/${file}`);
  checkForbidden(result.code, ARTIFACT);
  await checkDocs(root);
  const compiled = compiler ? await compileSources(root, compiler) : 0;
  return { modules: result.order.length, compiled };
}

export async function main(args = process.argv.slice(2)) {
  ensure(args.length <= 1 && args.every((arg) => arg.startsWith('--compiler=') && arg.length > '--compiler='.length), 'Usage: node scripts/validate.mjs [--compiler=path/to/luau-compile]');
  const compiler = args[0]?.slice('--compiler='.length) ?? process.env.LUAU_COMPILER;
  const result = await validate({ compiler });
  console.log(`Validated ${result.modules} bundled modules, 15 factories, Rojo mapping, Lua test coverage and local documentation links.`);
  console.log(compiler ? `Compiled ${result.compiled} Lua files with the supplied compiler.` : 'Compiler not requested; syntax compilation skipped (use --compiler=... or LUAU_COMPILER).');
  console.log('Static checks do not execute Roblox/Studio UI tests.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
