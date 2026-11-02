import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { ARTIFACT, MANIFEST, LIBRARY_DIR, PROJECT_ROOT, analyzeModule, build, bundleSources, scanLua } from '../scripts/build.mjs';
import { COMPONENTS, checkDocs, checkForbidden, compileSources, validate as validateProject } from '../scripts/validate.mjs';
const validate = (options) => validateProject({ compiler: '', ...options });

const entry = (body = '', version = '2.0.0') => `local UILibrary = {}\nUILibrary.Version = '${version}'\n${body}\nreturn UILibrary\n`;
const fixture = () => ({
  'init.lua': entry('UILibrary.A = require(script.A)\nUILibrary.B = require(script.B)'),
  'A.lua': 'return require(script.Parent.Shared)\n',
  'B.lua': 'return require(script.Parent.Shared)\n',
  'Shared.lua': 'return {}\n',
});

async function withProject(run) {
  // Stay inside the worktree so tests also work in restricted filesystem sandboxes.
  const root = await fs.mkdtemp(path.join(PROJECT_ROOT, '.build-test-'));
  try {
    const writeSources = async (sources) => {
      for (const [file, source] of Object.entries(sources)) {
        const destination = path.join(root, LIBRARY_DIR, file);
        await fs.mkdir(path.dirname(destination), { recursive: true });
        await fs.writeFile(destination, source);
      }
    };
    await run(root, writeSources);
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
}

function cli(script, args = []) {
  return spawnSync(process.execPath, [path.join(PROJECT_ROOT, script), ...args], {
    cwd: PROJECT_ROOT, encoding: 'utf8', timeout: 10_000, shell: false,
  });
}

test('scanner ignores line/long comments and all non-interpolated strings', () => {
  const source = [
    '-- require(script.Bad) script loadstring',
    '--[=[ require(script.Bad) ]=]',
    'local a = "require(script.Bad) \\\" script"',
    "local b = 'script \\\' require(script.Bad)'",
    'local c = [==[ require(script.Bad) script ]=] ]==]',
    'local d = "escaped\\\nscript"',
    'local e = "space\\z\n  script"',
    'return require -- comment\n ( script --[=[ comment ]=] . Good )',
  ].join('\n');
  const analysis = analyzeModule(source);
  assert.equal(analysis.calls.length, 1);
  assert.deepEqual(analysis.calls[0].segments, ['Good']);
  assert.equal(source.slice(analysis.calls[0].start, analysis.calls[0].end), 'require -- comment\n ( script --[=[ comment ]=] . Good )');
  assert.equal(analysis.tokens.filter((token) => token.kind === 'string').length, 5);
});

test('replacements preserve inert source contents byte-for-byte', () => {
  const prefix = '-- require(script.Missing)\nlocal s = [=[require(script.Missing) script]=]\n';
  const result = bundleSources({ 'init.lua': entry(prefix + 'UILibrary.A = require(script.A)'), 'A.lua': 'return {}' });
  assert.ok(result.code.includes(prefix));
  assert.ok(result.code.includes('UILibrary.A = __require("A.lua")'));
  assert.equal(result.code.match(/__factories\["A.lua"\] =/g).length, 1);
});

test('scanner distinguishes identifier tokens, properties, fields, and concatenation', () => {
  const analysis = analyzeModule('local description = "script"\nlocal t = {script = 1, require = 2}\nlocal x = obj.script\nlocal y = obj:require()\nreturn t');
  assert.deepEqual(analysis.calls, []);
  const values = scanLua('a..script.X ~= b').map((token) => token.value);
  assert.deepEqual(values, ['a', '..', 'script', '.', 'X', '~=', 'b']);
  assert.throws(() => analyzeModule('return "x" .. script.Name'), /free script reference/);
});

test('scanner fails clearly on unterminated literals and interpolation', () => {
  for (const source of ['local x = "unfinished', "local x = 'unfinished\n", '[=[unfinished', '--[==[unfinished']) {
    assert.throws(() => scanLua(source, 'Bad.lua'), /Bad.lua:1: Unterminated/);
  }
  assert.throws(() => analyzeModule('return `value {require(script.Hidden)}`'), /Interpolated strings/);
});

test('only static script/Parent paths are accepted; require aliases fail closed', () => {
  for (const expression of [
    'require(123)', 'require("module")', 'require(variable)',
    'require(script[name])', 'require(script:WaitForChild("A"))',
    'require(script.A .. suffix)', 'require(script.A, 1)',
    'require((script.A))', 'require(script.A())', 'require "module"',
    'local alias = require', 'local require = other',
  ]) assert.throws(() => analyzeModule(expression, 'Dynamic.lua'), /Dynamic.lua:1: Unsupported\/dynamic require/);
  for (const source of ['return script', 'local alias = script', 'return script.Parent', 'return { [script] = true }']) {
    assert.throws(() => analyzeModule(source), /free script reference/);
  }
  assert.throws(() => analyzeModule('return __require("A")'), /Reserved bundle identifier/);
});

test('Rojo init children, plain module parents, folder parents, and ancestor paths resolve', () => {
  const result = bundleSources({
    'init.lua': entry('UILibrary.Components = require(script.Components)\nUILibrary.Window = require(script.Core.Window)'),
    'Components/init.lua': 'return { Toggle = require(script.Toggle) }',
    'Components/Toggle.lua': 'return require(script.Parent.Parent.Theme)',
    'Core/Window.lua': 'return require(script.Parent.Parent.Theme)',
    'Theme.lua': 'return {}',
  });
  assert.deepEqual(result.order, ['Theme.lua', 'Components/Toggle.lua', 'Components/init.lua', 'Core/Window.lua', 'init.lua']);
  assert.ok(result.code.includes('Toggle = __require("Components/Toggle.lua")'));
  assert.equal(result.modules.get('Core/Window.lua').dependencies[0], 'Theme.lua');
});

test('plain module Parent is its containing folder module, not its own node', () => {
  assert.throws(() => bundleSources({
    'init.lua': entry('UILibrary.C = require(script.C)'),
    'C/init.lua': 'return require(script.Leaf)',
    'C/Leaf.lua': 'return require(script.Parent)',
  }), /Dependency cycle: C\/init.lua -> C\/Leaf.lua -> C\/init.lua/);
});

test('deterministic sorted DFS puts shared dependencies first exactly once', () => {
  const sources = fixture();
  const a = bundleSources(sources);
  const b = bundleSources(new Map(Object.entries(sources).reverse()));
  assert.deepEqual(a.order, ['Shared.lua', 'A.lua', 'B.lua', 'init.lua']);
  assert.equal(a.code, b.code);
  assert.equal(a.manifestText, b.manifestText);
  assert.equal(a.code.match(/__factories\["Shared.lua"\] =/g).length, 1);
  assert.ok(a.code.indexOf('__factories["Shared.lua"]') < a.code.indexOf('__factories["A.lua"]'));
  assert.ok(!a.code.includes(PROJECT_ROOT));
  assert.equal(a.manifest.artifactSha256, createHash('sha256').update(a.code).digest('hex'));
  assert.equal(a.manifest.sourceSha256, createHash('sha256').update(JSON.stringify(a.manifest.sources)).digest('hex'));
});

test('source normalization makes CRLF/BOM builds identical; content/path changes affect hashes', () => {
  const sources = fixture();
  const a = bundleSources(sources);
  const windows = Object.fromEntries(Object.entries(sources).map(([file, source]) => [file, '\uFEFF' + source.replace(/\n/g, '\r\n')]));
  assert.equal(a.code, bundleSources(windows).code);
  assert.equal(a.manifestText, bundleSources(windows).manifestText);
  assert.notEqual(a.manifest.sourceSha256, bundleSources({ ...sources, 'Shared.lua': 'return { Changed = true }' }).manifest.sourceSha256);
  const renamed = { ...sources, 'Renamed.lua': sources['Shared.lua'], 'A.lua': 'return require(script.Parent.Renamed)', 'B.lua': 'return require(script.Parent.Renamed)' };
  delete renamed['Shared.lua'];
  assert.notEqual(a.manifest.sourceSha256, bundleSources(renamed).manifest.sourceSha256);
});

test('missing entry, missing modules, folders, and escaping Parent are rejected', () => {
  assert.throws(() => bundleSources({}), /Missing library entry/);
  assert.throws(() => bundleSources({ 'init.lua': entry('require(script.Absent)') }), /init.lua: Missing dependency script.Absent/);
  assert.throws(() => bundleSources({ 'init.lua': entry('require(script.Parent.Other)') }), /outside library or missing node/);
  assert.throws(() => bundleSources({ 'init.lua': entry('require(script.Core)'), 'Core/Window.lua': 'return {}' }), /folder, not a ModuleScript/);
});

test('cycles report the chain including self cycles', () => {
  assert.throws(() => bundleSources({ 'init.lua': entry('require(script)') }), /Dependency cycle: init.lua -> init.lua/);
  assert.throws(() => bundleSources({
    'init.lua': entry('require(script.A)'), 'A.lua': 'return require(script.Parent.B)', 'B.lua': 'return require(script.Parent.A)',
  }), /Dependency cycle: A.lua -> B.lua -> A.lua/);
});

test('all Lua files must be reachable and ambiguous Rojo nodes fail', () => {
  assert.throws(() => bundleSources({ 'init.lua': entry(), 'Core/Window.lua': 'return {}' }), /Unreferenced library Lua files: Core\/Window.lua/);
  assert.throws(() => bundleSources({ 'init.lua': entry(), 'A.lua': 'return {}', 'A/init.lua': 'return {}' }), /Ambiguous Rojo module node/);
  assert.throws(() => bundleSources({ 'init.lua': entry(), 'A.client.lua': 'return {}' }), /must be a ModuleScript/);
  assert.throws(() => bundleSources({ '../init.lua': entry() }), /Invalid relative Lua path/);
});

test('version must come from exactly one literal entry assignment', () => {
  for (const source of ['return {}', '-- UILibrary.Version = "2.0.0"\nreturn {}', 'UILibrary.Version = getVersion()\nreturn {}', entry('', 'not-a-version'), entry() + '\nUILibrary.Version = "3.0.0"', 'UILibrary.Version = "2.0.0" .. suffix\nreturn {}', 'UILibrary.Version = "2.0.0"\n .. suffix\nreturn {}']) {
    assert.throws(() => bundleSources({ 'init.lua': source }), /Version/);
  }
  assert.equal(bundleSources({ 'init.lua': entry('', '2.1.0-rc.1+local') }).manifest.version, '2.1.0-rc.1+local');
});

test('runtime is lazy, cached, handles false, guards loading, and clears failed loads (static inspection only)', () => {
  const { code } = bundleSources(fixture());
  const runtime = code.slice(code.indexOf('local function __require(id)'));
  assert.ok(code.includes('= function(__require)\n'));
  assert.ok(runtime.includes('if __cache[id] ~= nil then return __cache[id] end'));
  assert.ok(runtime.includes('if __loading[id] then error('));
  assert.ok(runtime.includes('local ok, result = pcall(factory, __require)'));
  assert.ok(runtime.indexOf('__loading[id] = nil') < runtime.indexOf('if not ok then'));
  assert.ok(runtime.includes('__cache[id] = result'));
  assert.ok(runtime.includes('if result == nil then error('));
  assert.ok(code.endsWith('return __require("init.lua")\n'));
  assert.ok(!scanLua(code).some((token) => token.kind === 'identifier' && ['require', 'loadstring'].includes(token.value)));
});

test('filesystem build creates dist, checks exact bytes, and preserves valid outputs after source failure', async () => {
  await withProject(async (root, write) => {
    await write(fixture());
    await assert.rejects(build({ root, check: true }), /Stale or missing dist/);
    const result = await build({ root });
    assert.equal(await fs.readFile(path.join(root, ARTIFACT), 'utf8'), result.code);
    assert.equal(await fs.readFile(path.join(root, MANIFEST), 'utf8'), result.manifestText);
    await build({ root, check: true });
    await build({ root }); // Atomic replacement of existing outputs, including Windows.
    assert.deepEqual((await fs.readdir(path.join(root, 'dist'))).sort(), ['AstralLite.lua', 'AstralLite.manifest.json']);
    await write({ 'A.lua': 'return require(dynamic)' });
    await assert.rejects(build({ root }), /dynamic require/);
    assert.equal(await fs.readFile(path.join(root, ARTIFACT), 'utf8'), result.code);
    assert.equal(await fs.readFile(path.join(root, MANIFEST), 'utf8'), result.manifestText);
  });
});

test('stale artifact, manifest, source and missing manifest all fail check without writes', async () => {
  await withProject(async (root, write) => {
    await write(fixture());
    await build({ root });
    const artifact = path.join(root, ARTIFACT);
    const manifest = path.join(root, MANIFEST);
    const original = await fs.readFile(artifact);
    await fs.appendFile(artifact, '\n');
    await assert.rejects(build({ root, check: true }), /Stale or missing dist\/AstralLite.lua/);
    assert.equal((await fs.readFile(artifact)).length, original.length + 1);
    await build({ root });
    await fs.appendFile(manifest, ' ');
    await assert.rejects(build({ root, check: true }), /Stale or missing dist\/AstralLite.manifest.json/);
    await build({ root });
    await fs.rm(manifest);
    await assert.rejects(build({ root, check: true }), /Stale or missing dist\/AstralLite.manifest.json/);
    await build({ root });
    await write({ 'Shared.lua': 'return { changed = true }' });
    await assert.rejects(build({ root, check: true }), /Stale or missing/);
    assert.deepEqual(await fs.readFile(artifact), original);
  });
});

test('forbidden API checks ignore comments and assertion/documentation strings', () => {
  checkForbidden('-- loadstring getgenv\nassert(true, "No loadstring or executor APIs")\nlocal text = [=[syn.request]=]', 'Safe.lua');
  for (const source of ['loadstring("bad")', 'getgenv()', 'syn.request({})', 'game:HttpGet("url")']) assert.throws(() => checkForbidden(source, 'Bad.lua'), /Forbidden runtime API/);
});

test('documentation local links resolve relative to their file, skip web/code, and report missing targets', async () => {
  await withProject(async (root) => {
    await fs.mkdir(path.join(root, 'docs'));
    await fs.mkdir(path.join(root, 'tests'));
    await fs.writeFile(path.join(root, 'README.md'), '[Doc](docs/API.md#usage) [web](https://example.invalid)\n```lua\n[x](not-a-link)\n```\n');
    await fs.writeFile(path.join(root, 'docs/API.md'), '[Root](../README.md)\n[ref]: ../README.md\n');
    await checkDocs(root);
    await fs.appendFile(path.join(root, 'docs/API.md'), '[Missing](missing.md)\n');
    await assert.rejects(checkDocs(root), /docs\/API.md: Broken local link: missing.md/);
  });
});

test('CLI guards allow importing without output and reject unknown options', () => {
  for (const script of ['scripts/build.mjs', 'scripts/validate.mjs']) {
    const imported = spawnSync(process.execPath, ['--input-type=module', '-e', `await import(${JSON.stringify('./' + script)})`], { cwd: PROJECT_ROOT, encoding: 'utf8', timeout: 10_000 });
    assert.equal(imported.status, 0, imported.stderr);
    assert.equal(imported.stdout, '');
    const invalid = cli(script, ['--unknown']);
    assert.equal(invalid.status, 1);
    assert.match(invalid.stderr, /Usage:/);
  }
});

async function validatorProject(root, write) {
  await write({
    'init.lua': entry([
      'local Components = require(script.Components)',
      'local Window = require(script.Core.Window)',
      'function UILibrary.new() end',
      'function UILibrary.CreateWindow() return Window end',
      'local UI = {}',
      'for kind in pairs(Components) do UI["Create" .. kind] = Components[kind] end',
      'function UI.CreateNotification() end',
      'function UI.Destroy() end',
    ].join('\n')),
    'Components/init.lua': `return {\n${COMPONENTS.map((name) => `${name} = require(script.${name}),`).join('\n')}\n}`,
    'Core/Window.lua': 'return function() end',
    ...Object.fromEntries(COMPONENTS.map((name) => [`Components/${name}.lua`, 'return function() end'])),
  });
  await fs.mkdir(path.join(root, 'src/client'), { recursive: true });
  await fs.mkdir(path.join(root, 'tests'));
  await fs.mkdir(path.join(root, 'docs'));
  const main = 'local window = UILibrary:CreateWindow()\nwindow:CreateTab({})\nlocal tabs = {"Home", "Combat", "Teleport", "Player", "Visuals", "World", "Misc", "Settings"}\n';
  await fs.writeFile(path.join(root, 'src/client/Main.client.lua'), main);
  await fs.writeFile(path.join(root, 'tests/Components.spec.lua'), `return { ${COMPONENTS.map((name) => `"${name}"`).join(', ')}, "Destroy", "GetValue", "SetValue" }`);
  const project = { tree: { $className: 'DataModel', ReplicatedStorage: { UILibrary: { $path: LIBRARY_DIR } }, StarterPlayer: { StarterPlayerScripts: { $path: 'src/client' } } } };
  await fs.writeFile(path.join(root, 'default.project.json'), JSON.stringify(project));
  await build({ root });
  return { main, project };
}

test('validator passes a complete project and detects mapping, API, test coverage and Main regressions', async () => {
  await withProject(async (root, write) => {
    const { main, project } = await validatorProject(root, write);
    assert.deepEqual(await validate({ root, compiler: '' }), { modules: 18, compiled: 0 });
    await fs.appendFile(path.join(root, 'src/client/Main.client.lua'), 'UI:CreateToggle(panel, {})');
    await assert.rejects(validate({ root }), /must not auto-create/);
    await fs.writeFile(path.join(root, 'src/client/Main.client.lua'), main);
    await fs.appendFile(path.join(root, 'src/client/Main.client.lua'), 'local x = loadstring("bad")');
    await assert.rejects(validate({ root }), /Forbidden runtime API loadstring/);
    await fs.writeFile(path.join(root, 'src/client/Main.client.lua'), main);
    const tests = path.join(root, 'tests/Components.spec.lua');
    const originalTests = await fs.readFile(tests, 'utf8');
    await fs.writeFile(tests, originalTests.replace('"Toggle"', '"Absent"'));
    await assert.rejects(validate({ root }), /Lua tests do not cover Toggle/);
    await fs.writeFile(tests, originalTests);
    const source = path.join(root, LIBRARY_DIR, 'init.lua');
    const originalSource = await fs.readFile(source, 'utf8');
    await fs.writeFile(source, originalSource.replace('function UILibrary.CreateWindow', 'function UILibrary.MissingWindow'));
    await build({ root });
    await assert.rejects(validate({ root }), /Missing UILibrary.CreateWindow/);
    await fs.writeFile(source, originalSource);
    await build({ root });
    project.tree.Archive = { $path: 'ui.lua' };
    await fs.writeFile(path.join(root, 'default.project.json'), JSON.stringify(project));
    await assert.rejects(validate({ root }), /Rojo must map only/);
  });
});

test('optional sourcemap is inspected for module classes, paths and Rojo node hierarchy', async () => {
  await withProject(async (root, write) => {
    await validatorProject(root, write);
    const result = await build({ root });
    const library = { name: 'UILibrary', className: 'ModuleScript', filePaths: [`${LIBRARY_DIR}/init.lua`], children: [] };
    for (const module of result.modules.values()) {
      if (!module.node) continue;
      const segments = module.node.split('/');
      let parent = library;
      for (const [index, segment] of segments.entries()) {
        let child = parent.children.find((item) => item.name === segment);
        if (!child) { child = { name: segment, className: 'Folder', children: [] }; parent.children.push(child); }
        if (index === segments.length - 1) { child.className = 'ModuleScript'; child.filePaths = [`${LIBRARY_DIR}/${module.file}`]; }
        parent = child;
      }
    }
    const map = { name: 'AstralLite', className: 'DataModel', filePaths: ['default.project.json'], children: [
      { name: 'ReplicatedStorage', children: [library] },
      { name: 'StarterPlayer', children: [{ name: 'StarterPlayerScripts', children: [{ name: 'Main', className: 'LocalScript', filePaths: ['src/client/Main.client.lua'] }] }] },
    ] };
    await fs.mkdir(path.join(root, 'build'));
    const destination = path.join(root, 'build/sourcemap.json');
    await fs.writeFile(destination, JSON.stringify(map));
    await validate({ root });
    library.children.find((node) => node.name === 'Core').children = [];
    await fs.writeFile(destination, JSON.stringify(map));
    await assert.rejects(validate({ root }), /Sourcemap is stale\/incorrect for .*Core\/Window.lua/);
  });
});

test('failed manifest publication leaves the previous Lua artifact intact', async () => {
  await withProject(async (root, write) => {
    await write(fixture());
    const original = await build({ root });
    await write({ 'Shared.lua': 'return { changed = true }' });
    const manifest = path.join(root, MANIFEST);
    await fs.rm(manifest);
    await fs.mkdir(manifest);
    await assert.rejects(build({ root }));
    assert.equal(await fs.readFile(path.join(root, ARTIFACT), 'utf8'), original.code);
    assert.ok(!(await fs.readdir(path.join(root, 'dist'))).some((file) => file.endsWith('.tmp')));
  });
});

test('optional official compiler accepts all fixture sources and the generated bundle', { skip: !process.env.LUAU_COMPILER }, async () => {
  await withProject(async (root, write) => {
    await validatorProject(root, write);
    const compiler = path.resolve(PROJECT_ROOT, process.env.LUAU_COMPILER);
    const result = await validate({ root, compiler });
    assert.equal(result.compiled, 21);
  });
});

test('compiler failures are surfaced and no executable is downloaded', async () => {
  await withProject(async (root) => {
    await assert.rejects(compileSources(root, 'missing-compiler'), /ENOENT/);
  });
});
