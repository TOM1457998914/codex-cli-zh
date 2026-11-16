import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
const version = JSON.parse(read('version.json'));
assert.equal(version.project, 'codex-cli-zh');
assert.match(version.upstreamCommit, /^[a-f0-9]{40}$/);
assert.match(version.releaseTag, /^v\d+\.\d+\.\d+-zh\.\d+$/);
const patch = fs.readFileSync(path.join(root, version.patch));
assert.equal(crypto.createHash('sha256').update(patch).digest('hex'), version.patchSha256, 'Patch SHA-256 mismatch');
const diffs = [...patch.toString('utf8').matchAll(/^diff --git a\/(.+) b\/(.+)$/gm)];
assert(diffs.length > 100, 'Expected a complete source overlay');
for (const [, before, after] of diffs) {
  for (const file of [before, after]) {
    assert(file.startsWith('codex-rs/') && !file.split('/').includes('..'), `Unexpected patch path: ${file}`);
  }
}
const verification = JSON.parse(read('docs/verification.json'));
assert.equal(verification.upstreamCommit, version.upstreamCommit);
assert.equal(verification.revision, version.revision, 'Verification belongs to another revision');
assert.equal(verification.uiTests.failed, 0);
assert.equal(verification.uiTests.snapshotAutoUpdate, false, 'Release tests must pass without updating snapshots');
if (Number(version.revision.slice(1)) >= 7) {
  for (const name of ['cliTests','cloudTests','execTests']) {
    assert(verification[name]?.passed > 0, `Missing ${name} result`);
    assert.equal(verification[name].failed, 0, `${name} failed`);
    assert.equal(verification[name].snapshotAutoUpdate, false, `${name} updated snapshots`);
  }
  for (const name of ['indirectIdentifiersChecked','permissionClassifierUnchanged','voiceTelemetryUnchanged','statusLookupKeysUnchanged','doctorMachineReportUnchanged','pluginJsonPoliciesUnchanged']) {
    assert.equal(verification.contracts[name], true, `Missing contract guard: ${name}`);
  }
  assert.equal(verification.contracts.passed, true, 'Contract audit failed');
}
assert.equal(verification.allUiTranslated, false);
const ignored = new Set(['.git', '.work', 'artifacts', 'node_modules', 'target']);
let files = 0;
function visit(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) { visit(full); continue; }
    const relative = path.relative(root, full);
    assert(!/^(auth\.json|config\.toml)$|\.(exe|dll|log|zip|pending-snap|snap\.new)$/i.test(entry.name), `Private or generated file: ${relative}`);
    const text = fs.readFileSync(full, 'utf8').replace(/^\uFEFF/, '');
    if (entry.name.endsWith('.json')) JSON.parse(text);
    assert(!/gh[pousr]_[A-Za-z0-9_]{30,}/.test(text), `Possible credential: ${relative}`);
    assert(!/sk-[A-Za-z0-9]{35,}/.test(text), `Possible credential: ${relative}`);
    assert(!/C:[\\/]+Users[\\/]+(?!example|test|User|USERNAME|[^\\/]*\$)[A-Za-z0-9_-]+[\\/]+(?:AppData|Desktop|\.codex)/i.test(text), `Machine-specific user path: ${relative}`);
    files++;
  }
}
visit(root);
const tips = read('locales/tooltips-r5.zh-CN.txt').split(/\r?\n/).filter(line => line && !line.startsWith('#'));
assert.equal(tips.length, 44);
assert(tips.every(line => /\p{Script=Han}/u.test(line)));
console.log(JSON.stringify({ result: 'passed', projectFiles: files, patchedFiles: diffs.length, patchSha256: version.patchSha256, chineseTips: tips.length }, null, 2));
