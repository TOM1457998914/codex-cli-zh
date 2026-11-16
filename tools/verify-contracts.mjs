import fs from 'node:fs';
import path from 'node:path';
import cp from 'node:child_process';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.resolve(process.argv[2] ?? path.join(project, '.work/source'));
const binary = path.resolve(process.argv[3] ?? path.join(project, '.work/contracts-target/debug', process.platform === 'win32' ? 'codex-zh-contracts.exe' : 'codex-zh-contracts'));
const version = JSON.parse(fs.readFileSync(path.join(project, 'version.json'), 'utf8'));
const allowlistPath = path.join(project, 'tools/contract-allowlist.json');
const approved = fs.existsSync(allowlistPath) ? JSON.parse(fs.readFileSync(allowlistPath, 'utf8')) : {changes:[]};
assert.equal(approved.baseline, version.upstreamCommit, 'Allowlist baseline changed');
assert.equal(approved.reviewedFor, version.revision, 'Allowlist revision needs review');
const git = args => cp.execFileSync('git', ['-c', 'core.safecrlf=false', ...args], { cwd: source, encoding: 'utf8', maxBuffer: 16e6, stdio: ['ignore','pipe','pipe'] });
assert.equal(git(['rev-parse','HEAD']).trim(), version.upstreamCommit, 'Unexpected upstream commit');
const files = git(['diff','--name-only',version.upstreamCommit,'--','codex-rs']).trim().split(/\r?\n/).filter(f => f.endsWith('.rs') && !/tests|snapshots/.test(f));
assert(files.length > 100, 'Expected a prepared localized source tree');
const output = path.join(project, '.work/contract-audit');
fs.mkdirSync(output, { recursive:true });
const reference = path.join(output, 'upstream-reference.rs');
const extract = file => JSON.parse(cp.execFileSync(binary, [file], {encoding:'utf8',maxBuffer:12e6}));
fs.writeFileSync(reference,'fn audit_probe(value: &str) { let _ = matches!(value, "disable" | "hide" | "off" | "none"); let (context, action) = (KeymapContext::Composer, "submit"); let key = "leader f24"; }');
const probe=extract(reference);
const macroProbe=probe.filter(entry=>entry.kind==='pattern').map(entry=>entry.text);
assert.deepEqual(macroProbe,['disable','hide','off','none'],'The audit binary must support matches! patterns; rebuild tools/Cargo.toml');
assert.deepEqual(probe.filter(entry=>entry.kind==='keymap-action').map(entry=>entry.text),['submit'],'The audit binary must inspect indirect action lookups');
assert.deepEqual(probe.filter(entry=>entry.kind==='local:key').map(entry=>entry.text),['leader f24'],'The audit binary must inspect canonical key strings');
const changes=[];
for (const file of files) {
  fs.writeFileSync(reference, git(['show',version.upstreamCommit+':'+file]));
  const before=extract(reference), after=extract(path.join(source,file));
  const key=e=>e.function+'|'+e.kind;
  for (const group of new Set([...before.map(key),...after.map(key)])) {
    const a=before.filter(e=>key(e)===group).map(e=>e.text);
    const b=after.filter(e=>key(e)===group).map(e=>e.text);
    if (JSON.stringify(a)!==JSON.stringify(b)) changes.push({file,group,before:a,after:b});
  }
}
function keymapInventory(text) {
  const catalog=text.split('define_keymap_actions! {')[1]?.split('pub(crate) fn action_label')[0];
  assert(catalog,'Keymap catalog not found');
  let context='';const rows=[];
  for(const line of catalog.split(/\r?\n/)) {
    const group=line.match(/^\s*(\w+)\s+"[^"\n]+"\s*\{/);if(group)context=group[1];
    const action=line.match(/^\s*(\w+)(?:\s*\[([^\]]+)\])?\s*=>/);if(action)rows.push([context,action[1],action[2]??null]);
  }
  return rows;
}
const current=file=>fs.readFileSync(path.join(source,file),'utf8').replace(/\r\n/g,'\n');
const original=file=>git(['show',version.upstreamCommit+':'+file]).replace(/\r\n/g,'\n');
// These tuple keys feed compose_model_display; translating them hides model details.
const statusKeys=text=>{
  const block=text.match(/let mut config_entries = vec!\[([\s\S]*?)let \(model_name, model_details\) = compose_model_display/);
  assert(block,'Status configuration map not found');
  return [...block[1].matchAll(/"(?:\\.|[^"\\])*"/g)].map(match=>match[0]);
};
const statusCard='codex-rs/tui/src/status/card.rs';
assert.deepEqual(statusKeys(current(statusCard)),statusKeys(original(statusCard)),'Status model lookup keys changed');
const functionBlock=(text,name)=>{
  const start=text.indexOf('fn '+name+'('),end=text.indexOf('\n}\n',start)+3;
  assert(start>=0&&end>start,'Function not found: '+name);
  return text.slice(start,end);
};
assert.equal(functionBlock(current(statusCard),'status_permission_summary'),functionBlock(original(statusCard),'status_permission_summary'),'Permission classification values changed before display');
const voiceMetrics='codex-rs/tui/src/chatwidget/realtime/failure_metrics.rs';
assert.equal(current(voiceMetrics),original(voiceMetrics),'Voice telemetry dimensions changed');
for(const file of ['background.rs','filesystem_paths.rs','updates.rs']) {
  const producer='codex-rs/cli/src/doctor/'+file;
  assert.equal(current(producer),original(producer),'Doctor machine-report producer changed: '+file);
}
const pluginPolicies=text=>['install_policy_label','auth_policy_label'].map(name=>{
  const block=text.match(new RegExp('fn '+name+'[\\s\\S]*?\\n\\}'));
  assert(block,'Plugin policy formatter not found');
  return [...block[0].matchAll(/"(?:\\.|[^"\\])*"/g)].map(match=>match[0]);
});
const plugin='codex-rs/cli/src/plugin_cmd.rs';
assert.deepEqual(pluginPolicies(current(plugin)),pluginPolicies(original(plugin)),'Plugin JSON policy values changed');
const keymap='codex-rs/tui/src/keymap_setup/actions.rs';
assert.deepEqual(keymapInventory(current(keymap)),keymapInventory(original(keymap)),'Keymap IDs or feature gates changed');
const slash='codex-rs/tui/src/slash_command.rs';
assert.equal(current(slash).split('impl SlashCommand {')[0],original(slash).split('impl SlashCommand {')[0],'Slash command names or aliases changed');
const dispatch=text=>text.slice(text.indexOf('/// Command string'));
assert.equal(dispatch(current(slash)),dispatch(original(slash)),'Slash dispatch or availability changed');
for(const [file,name] of [['codex-rs/tui/src/bottom_pane/status_line_setup.rs','StatusLineItem'],['codex-rs/tui/src/bottom_pane/title_setup.rs','TerminalTitleItem']]) {
  const extract=text=>{const match=new RegExp('enum '+name+'\\s*\\{([\\s\\S]*?)\\n\\}').exec(text);assert(match,'Enum not found');return match[1].replace(/\/\/\/[^\n]*/g,'').replace(/\s+/g,'');};
  assert.equal(extract(current(file)),extract(original(file)),name+' serialized values changed');
}
const tipTokens=text=>[...text.matchAll(/\{key:[^}]+\}|`[^`\n]+`|https:\/\/[^)\s`]+/g)].map(match=>match[0]).sort();
const tips='codex-rs/tui/assets/tooltips.txt';
assert.deepEqual(tipTokens(current(tips)),tipTokens(original(tips)),'Tooltip commands, links or shortcut references changed');
const equal=(a,b)=>JSON.stringify([a.file,a.group,a.before,a.after])===JSON.stringify([b.file,b.group,b.before,b.after]);
fs.writeFileSync(path.join(output,'proposal.json'),JSON.stringify({changes},null,2)+'\n');
const unexpected=changes.filter(change=>!approved.changes.some(entry=>equal(change,entry)));
const stale=approved.changes.filter(entry=>!changes.some(change=>equal(change,entry)));
const report={checkedFiles:files.length,keymapActions:keymapInventory(current(keymap)).length,indirectIdentifiersChecked:true,statusLookupKeysUnchanged:true,permissionClassifierUnchanged:true,voiceTelemetryUnchanged:true,doctorMachineReportUnchanged:true,pluginJsonPoliciesUnchanged:true,slashDispatchUnchanged:true,serializedStatusItemsUnchanged:true,tooltipTokensUnchanged:true,reviewedChanges:changes.length,unexpected,stale,passed:!unexpected.length&&!stale.length};
fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
if (!report.passed) process.exitCode=1;
