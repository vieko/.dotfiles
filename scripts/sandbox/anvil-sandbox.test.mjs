import test from 'node:test';
import assert from 'node:assert/strict';
import fsNative from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { runController, validateRequest, anvilBucket, hostGit, credentialExpiryMessage } from './anvil-sandbox.mjs';

// snapshotId and ghStsPolicy are optional (anvil#63); their own tests live below this loop.
const keys=['repoUrl','forkSha','specPath','gate','scopes','contracts','model','teamId','projectId','vcpus','timeoutMs','localRepo','dispatchId'];
const OIDC='OIDC_TOKEN_marker';
const GH='GH_STS_TOKEN_marker';
const sha='a'.repeat(40);
const execFileAsync=promisify(execFile);
const SUMMONER=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../.scripts/summon-golem.sh');
async function fixture(options={}) {
  const root=await fsNative.mkdtemp(path.join(os.tmpdir(),'anvil-sandbox-test-'));
  const home=path.join(root,'home'); await fsNative.mkdir(home);
  const repo=path.join(root,'repo'); await fsNative.mkdir(repo);
  const req={repoUrl:'https://github.com/acme/repo.git',forkSha:sha,specPath:'spec.md',gate:['npm test'],scopes:['src/**'],contracts:[],model:'luna',snapshotId:'snapshot-approved',teamId:'team-test',projectId:'project-test',ghStsPolicy:'vieko-golem-sandbox-development',vcpus:2,timeoutMs:600000,localRepo:repo,dispatchId:'dispatch-123',summonerAddress:'session-address',...(options.req??{})};
  await fsNative.writeFile(path.join(root,'spec.md'),'spec contents\n');
  const request=path.join(root,'request.json'); await fsNative.writeFile(request,JSON.stringify(req));
  const calls=[]; let runNumber=0; let interruptedNow=false;
  const sandbox={name:'sandbox-test'};
  const sdk={
    async create(opts){calls.push(['create',opts]);return sandbox;},
    async runCommand(sb,opts){calls.push(['remote',opts]);runNumber++;
      if(opts.cmd==='anvil' && options.interrupted) interruptedNow=true;
      if(opts.cmd==='anvil' && options.throwRun) throw new Error('simulated run failure');
      let stdout='',stderr='',exitCode=0;
      const line=opts.args?.at(-1)||'';
      if(opts.cmd==='git' && opts.args?.includes('--porcelain')) stdout=runNumber>(options.anvilRunNumber??6)?'worktree /vercel/repo\nHEAD aaa\n\nworktree /vercel/repo-anvil/anvil-spec-x\nHEAD bbb\nbranch refs/heads/anvil/spec/x\n':'worktree /vercel/repo\nHEAD aaa\n';
      else if(opts.cmd==='bash' && line.includes('GITHUB_BLOCKED')) stdout='GITHUB_BLOCKED REGISTRY_BLOCKED GATEWAY_OK';
      else if(opts.cmd==='bash' && line.includes('/opt/anvil-snapshot')) stdout=options.lockMismatch?'bad-hash':`${sha}\n`;
      else if(opts.cmd==='bash' && line.includes('GATEWAY_OK')) stdout=options.setupContradiction==='github'?'GATEWAY_OK':options.setupContradiction?'':'GATEWAY_OKGITHUB_OK';
      else if(opts.cmd==='anvil') {stdout=JSON.stringify({passed:options.verdict==='red'?false:options.verdict==='void'?null:true,attempts:1,branch:'remote-branch'});stderr='agent log';exitCode=options.verdict==='red'?1:0;}
      const result={exitCode,output:async stream=>stream==='stdout'?stdout:stream==='stderr'?stderr:`${stdout}${stderr}`};
      return result;
    },
    async setNetworkPolicy(sb,policy){calls.push(['policy',policy]);},
    async writeFiles(sb,files){calls.push(['writeFiles',files]);},
    async readFileToBuffer(sb,{path:remote}){calls.push(['read',remote]);if(options.retrieveFailure&&remote==='/tmp/golem.patch')throw new Error('transfer failed');return Buffer.from(remote==='/tmp/golem.patch'?(options.patch??''):remote==='/tmp/anvil-state.tgz'?'fake archive':remote==='/tmp/anvil.log'?'remote log':remote==='/tmp/anvil-result.json'?'{}':'{}');},
    async stop(sb){calls.push(['stop']);if(options.stopFailure)throw new Error('stop failed');},
  };
  const fs={...fsNative,exists:async p=>{try{await fsNative.lstat(p);return true}catch{return false}}};
  const git={
    async assertClean(){calls.push(['clean']);}, async refuseCollision(){calls.push(['collision']);}, async worktreeAdd(){calls.push(['worktree']);},
    async lockfileHash(){return sha;}, async applyCheck(){calls.push(['apply-check']);if(options.applyCheckFailure)throw new Error('patch rejected');},
    async apply(){calls.push(['apply']);}, async verifyImported(repo,id){calls.push(['verify-imported',id]);if(options.verifyFailure)throw new Error('status missing dispatch');},
  };
  const exec={async run(cmd,args,opts={}){calls.push(['exec',cmd,args]); if(args[0]==='-tzf')return{stdout:options.archivePath??'.anvil/--vercel-repo--/runs/run.json'};if(args[0]==='-tvzf')return{stdout:options.archiveVerbose??''};if(args[0]==='-xzf'){const target=path.join(opts.cwd,'.anvil','--vercel-repo--','runs','run.json');await fsNative.mkdir(path.dirname(target),{recursive:true});await fsNative.writeFile(target,JSON.stringify(options.archiveRecord??{branch:'remote',pid:123}));if(options.sessionDir){const sess=path.join(opts.cwd,'.anvil','--vercel-repo--','sessions','--vercel-repo-anvil-x--');await fsNative.mkdir(sess,{recursive:true});await fsNative.writeFile(path.join(sess,'t.jsonl'),'{}\n');}}return{stdout:''};}};
  const logs=[];
  const credentials={
    async getOidcToken(){calls.push(['oidc']);return OIDC;},
    async fetch(url,requestOptions){
      calls.push(['mint',url,requestOptions]);
      const status=options.stsStatus??(options.denied?403:options.failed?500:200);
      return {ok:status>=200&&status<300,status,text:async()=>options.denied?'POLICY_DENIED: policy does not allow this identity':'upstream failure',json:async()=>({token:GH,expires_at:options.expiresAt??'2026-01-01T00:20:00.000Z'})};
    },
  };
  const clock={homeDir:home,env:{VERCEL_TOKEN:'V_TOKEN_marker',AI_GATEWAY_API_KEY:'AI_KEY_marker',VERCEL_TEAM_ID:'team-test',VERCEL_PROJECT_ID:'project-test',ANVIL_SANDBOX_SNAPSHOT_ID:'snapshot-approved'},now:()=>new Date('2026-01-01T00:00:00Z'),isInterrupted:()=>interruptedNow};
  const secrets=['V_TOKEN_marker',OIDC,GH,'AI_KEY_marker'];
  const old=Object.fromEntries(['VERCEL_TOKEN','AI_GATEWAY_API_KEY'].map(k=>[k,process.env[k]]));
  [process.env.VERCEL_TOKEN,process.env.AI_GATEWAY_API_KEY]=[secrets[0],secrets[3]];
  const snapshots=options.registry?{async list(){return options.registry;},async currentAnvilSha(){return options.currentAnvilSha??null;},async build(args){calls.push(['build',args]);return options.built??{snapshotId:'snapshot-rebuilt',lockfileHash:sha};}}:undefined;
  return {root,home,repo,req,request,calls,sdk,fs,git,exec,credentials,logs,clock,secrets,old,async run(){try{return await runController(request,{sdk,fs,git,exec,credentials,clock,snapshots,log:m=>logs.push(m)});}finally{for(const k of ['VERCEL_TOKEN','AI_GATEWAY_API_KEY']){if(old[k]===undefined)delete process.env[k];else process.env[k]=old[k];}}},async clean(){await fsNative.rm(root,{recursive:true,force:true});}};
}

for (const missing of keys) test(`request validation missing ${missing} has no create`,async()=>{
  const f=await fixture(); delete f.req[missing]; await fsNative.writeFile(f.request,JSON.stringify(f.req));
  const r=await f.run(); assert.equal(r.exitCode,4); assert.equal(f.calls.some(c=>c[0]==='create'),false); await f.clean();
});

const baseRequest={repoUrl:'https://github.com/acme/repo.git',forkSha:sha,specPath:'spec.md',gate:['npm test'],scopes:['src/**'],contracts:[],model:'luna',snapshotId:'snapshot-approved',teamId:'team-test',projectId:'project-test',ghStsPolicy:'vieko-golem-sandbox-development',vcpus:2,timeoutMs:600000,localRepo:'/tmp/repo',dispatchId:'dispatch-123',summonerAddress:'session-address'};
test('validateRequest accepts a request missing snapshotId, ghStsPolicy, or both (anvil#63)',async()=>{
  for(const drop of [['snapshotId'],['ghStsPolicy'],['snapshotId','ghStsPolicy']]){
    const r={...baseRequest};for(const k of drop)delete r[k];
    const validated=validateRequest(r,'/tmp/request.json');
    for(const k of drop)assert.equal(k in validated,false);
  }
});
test('validateRequest rejects empty optional strings rather than treating them as absent',async()=>{
  for(const k of ['snapshotId','ghStsPolicy','summonerAddress'])assert.throws(()=>validateRequest({...baseRequest,[k]:''},'/tmp/request.json'),/non-empty string/);
});
test('pinned snapshot errors distinguish an unset controller pin from a different pin',async()=>{
  for(const [envValue,expected] of [[undefined,/not set in the controller's environment/],['different-pin',/differs from ANVIL_SANDBOX_SNAPSHOT_ID different-pin/]]){
    const f=await fixture();
    if(envValue===undefined)delete f.clock.env.ANVIL_SANDBOX_SNAPSHOT_ID;else f.clock.env.ANVIL_SANDBOX_SNAPSHOT_ID=envValue;
    const result=await f.run();
    assert.equal(result.exitCode,4);assert.ok(f.logs.some(line=>expected.test(line)));assert.equal(f.calls.some(call=>call[0]==='create'),false);
    await f.clean();
  }
});
test('request rejects bad SHA, empty gate, --link, traversal, unknown keys before allocation',async()=>{
  for(const mutate of [r=>r.forkSha='bad',r=>r.gate=[],r=>r.gate=['anvil run --link'],r=>r.specPath='../outside',r=>r.extra=true]){
    const f=await fixture();mutate(f.req);await fsNative.writeFile(f.request,JSON.stringify(f.req));const out=await f.run();assert.equal(out.exitCode,4);assert.equal(f.calls.some(c=>c[0]==='create'),false);await f.clean();
  }
});
test('symlinked request inputs are rejected before sandbox creation',async()=>{const f=await fixture();await fsNative.unlink(path.join(f.root,'spec.md'));await fsNative.symlink(path.join(f.root,'outside.md'),path.join(f.root,'spec.md'));await fsNative.writeFile(path.join(f.root,'outside.md'),'spec');const r=await f.run();assert.equal(r.exitCode,4);assert.equal(f.calls.some(c=>c[0]==='create'),false);await f.clean();});
test('policies have fetch-only GitHub matchers, gateway-only agent policy, no wildcard',async()=>{
  const f=await fixture();const r=await f.run();if(r.exitCode!==0)console.error(f.logs,f.calls);assert.equal(r.exitCode,0);const create=f.calls.find(c=>c[0]==='create')[1];const p=create.networkPolicy;
  const mintCalls=f.calls.filter(c=>c[0]==='mint');assert.equal(mintCalls.length,1);assert.equal(f.calls.filter(c=>c[0]==='oidc').length,1);assert.equal(mintCalls[0][1],'https://gh-sts.vercel-infra.com/token');assert.equal(mintCalls[0][2].method,'POST');assert.equal(mintCalls[0][2].headers.Authorization,`Bearer ${OIDC}`);assert.deepEqual(JSON.parse(mintCalls[0][2].body),{owner:'acme',repo:'repo',permissions:{contents:'read'},policy:f.req.ghStsPolicy});
  const ghHeaders=p.allow['github.com'].map(rule=>rule.transform[0].headers.Authorization);const ghBasic=`Basic ${Buffer.from(`x-access-token:${GH}`).toString('base64')}`;assert.deepEqual(ghHeaders,[ghBasic,ghBasic]);const createJson=JSON.stringify(create);assert.equal(createJson.split(ghBasic).length-1,2);assert.equal(createJson.includes(GH),false);assert.equal(JSON.stringify(f.calls.filter(c=>c[0]!=='create')).includes(GH),false);assert.equal(JSON.stringify(f.calls.filter(c=>c[0]!=='create')).includes(Buffer.from(GH).toString('base64')),false);
  assert.deepEqual(Object.keys(p.allow).sort(),['ai-gateway.vercel.sh','github.com']);assert.deepEqual(f.calls.find(c=>c[0]==='create')[1].source,{type:'snapshot',snapshotId:'snapshot-approved'});assert.equal(p.allow['github.com'].length,2);assert.equal(p.allow['*'],undefined);
  assert.deepEqual(Object.keys(f.calls.find(c=>c[0]==='policy')[1].allow),['ai-gateway.vercel.sh']);
  assert.deepEqual(p.allow['github.com'][0].match.path,{exact:'/acme/repo.git/info/refs'});assert.deepEqual(p.allow['github.com'][0].match.method,['GET']);assert.deepEqual(p.allow['github.com'][1].match.method,['POST']);
  const order=f.calls.map(c=>c[0]);assert.ok(order.indexOf('read')<order.indexOf('stop'));const command=f.calls.find(c=>c[0]==='remote'&&c[1].cmd==='anvil')[1].args;assert.equal(command[0],'run');assert.ok(command.includes('--from'));assert.ok(command.includes(sha));assert.ok(command.includes('--gate-timeout'));assert.ok(command.includes('600s'));assert.ok(command.includes('--verify'));await f.clean();
});
test('gh-sts policy denial exits 4 once before any sandbox call and logs the policy',async()=>{const f=await fixture({denied:true});const r=await f.run();assert.equal(r.exitCode,4);assert.equal(f.calls.filter(c=>c[0]==='mint').length,1);assert.equal(f.calls.some(c=>c[0]==='create'||c[0]==='remote'),false);assert.ok(f.logs.some(line=>line.includes(f.req.ghStsPolicy)&&line.includes('403')&&line.includes('POLICY_DENIED')));await f.clean();});
test('gh-sts server error exits 4 without retry or sandbox creation',async()=>{const f=await fixture({failed:true});const r=await f.run();assert.equal(r.exitCode,4);assert.equal(f.calls.filter(c=>c[0]==='mint').length,1);assert.equal(f.calls.some(c=>c[0]==='create'),false);await f.clean();});
test('gh-sts token below the 10-minute setup budget is refused',async()=>{const f=await fixture({expiresAt:'2026-01-01T00:09:59.999Z'});const r=await f.run();assert.equal(r.exitCode,4);assert.equal(f.calls.filter(c=>c[0]==='mint').length,1);assert.equal(f.calls.some(c=>c[0]==='create'),false);await f.clean();});
test('no ghStsPolicy: public repo dispatches with no gh-sts request and a plain github.com allow',async()=>{
 const f=await fixture();delete f.req.ghStsPolicy;await fsNative.writeFile(f.request,JSON.stringify(f.req));const r=await f.run();if(r.exitCode!==0)console.error(f.logs,f.calls);assert.equal(r.exitCode,0);
 assert.equal(f.calls.some(c=>c[0]==='mint'),false);
 const create=f.calls.find(c=>c[0]==='create')[1];const p=create.networkPolicy;
 assert.deepEqual(p.allow['github.com'],[]);
 assert.deepEqual(p.allow['ai-gateway.vercel.sh'][0].transform[0].headers,{Authorization:`Bearer AI_KEY_marker`});
 await f.clean();
});
test('no ghStsPolicy: an anonymously unreachable repo names the credential gap (anvil#63)',async()=>{
 const f=await fixture({setupContradiction:'github'});delete f.req.ghStsPolicy;await fsNative.writeFile(f.request,JSON.stringify(f.req));const r=await f.run();assert.equal(r.exitCode,4);
 assert.ok(f.logs.some(l=>l.includes('not reachable anonymously')&&l.includes('vercel/*')&&l.includes('anvil#63')));
 await f.clean();
});
test('policy contradiction aborts before anvil, still collects and stops',async()=>{const f=await fixture({setupContradiction:true});const r=await f.run();assert.equal(r.exitCode,4);assert.equal(f.calls.some(c=>c[0]==='remote'&&c[1].cmd==='anvil'),false);assert.ok(f.calls.some(c=>c[0]==='read'));assert.equal(f.calls.at(-1)[0],'stop');await f.clean();});
test('OIDC and minted secrets never enter remote env/args, written files, logs, or manifest',async()=>{
 const f=await fixture();const result=await f.run();const ghBasic=Buffer.from(`x-access-token:${GH}`).toString('base64');const basic=`Basic ${ghBasic}`;const sensitive=[...f.secrets,...f.secrets.map(s=>Buffer.from(s).toString('base64')),ghBasic,basic];const serialized=JSON.stringify(f.calls.filter(c=>['remote','writeFiles'].includes(c[0])));for(const s of sensitive)assert.equal(serialized.includes(s),false);for(const line of f.logs)for(const s of sensitive)assert.equal(line.includes(s),false);const manifest=await fsNative.readFile(path.join(result.artifactDir,'manifest.json'),'utf8');for(const s of sensitive)assert.equal(manifest.includes(s),false);const files=await fsNative.readdir(result.artifactDir);for(const name of files){const file=path.join(result.artifactDir,name);if((await fsNative.lstat(file)).isFile()){const text=await fsNative.readFile(file);for(const s of sensitive)assert.equal(text.includes(s),false);}}await f.clean();
});
for(const [name,opts,code] of [['green',{},0],['red',{verdict:'red'},1],['void',{verdict:'void'},2],['thrown run',{throwRun:true},2],['SIGTERM',{interrupted:true},2]]) test(`collection precedes stop for ${name}`,async()=>{
 const f=await fixture(opts);const r=await f.run();assert.equal(r.exitCode,code);assert.ok(f.calls.some(c=>c[0]==='read'));assert.ok(f.calls.findIndex(c=>c[0]==='read')<f.calls.findIndex(c=>c[0]==='stop'));await f.clean();
});
test('retrieval failure after green is exit 3 and stops',async()=>{const f=await fixture({retrieveFailure:true});const r=await f.run();assert.equal(r.exitCode,3);assert.equal(f.calls.at(-1)[0],'stop');assert.equal(r.retrievalStatus.startsWith('failed'),true);assert.equal(await fsNative.readFile(path.join(r.artifactDir,'anvil.log'),'utf8'),'remote log');await f.clean();});
test('lockfile mismatch aborts before policy switch',async()=>{const f=await fixture({lockMismatch:true});const r=await f.run();assert.equal(r.exitCode,4);assert.equal(f.calls.some(c=>c[0]==='policy'),false);assert.equal(f.calls.at(-1)[0],'stop');await f.clean();});
test('unsafe patch and apply-check failure are refused',async()=>{
 for(const opts of [{patch:'diff --git a/../escape b/../escape\n--- a/../escape\n+++ b/../escape\n'},{patch:'diff --git a/link b/link\nnew file mode 120000\n--- /dev/null\n+++ b/link\n+target\n'},{applyCheckFailure:true}]){const f=await fixture(opts);const r=await f.run();assert.equal(r.exitCode,3);assert.equal(f.calls.some(c=>c[0]==='apply'),false);await f.clean();}
});
test('record import rewrites branch, removes pid, and annotates sandbox',async()=>{
 const f=await fixture({archivePath:'.anvil/--vercel-repo--/runs/run.json',archiveRecord:{branch:'remote',pid:123,note:'original'}});const r=await f.run();assert.equal(r.exitCode,0);const imported=JSON.parse(await fsNative.readFile(path.join(f.home,'.anvil',anvilBucket(f.repo),'runs','run.json'),'utf8'));assert.equal(imported.branch,'golem/dispatch-123');assert.equal('pid' in imported,false);assert.match(imported.note,/sandbox-test/);assert.equal(r.importStatus,'complete');await f.clean();
});
test('unsafe archive paths and archive symlinks are refused',async()=>{
 for(const opts of [{archivePath:'.anvil/--vercel-repo--/runs/../escape.json'},{archiveVerbose:'lrwxrwxrwx user/group 0 link -> /tmp/out'}]){const f=await fixture(opts);const r=await f.run();assert.equal(r.exitCode,3);assert.equal(f.calls.some(c=>c[0]==='exec'&&c[2][0]==='-xzf'),false);await f.clean();}
});
test('local status verification failure blocks green handoff',async()=>{const f=await fixture({verifyFailure:true});const r=await f.run();assert.equal(r.exitCode,3);assert.match(r.importStatus,/status missing dispatch/);await f.clean();});
test('record collision refuses import without overwriting local record',async()=>{
 const f=await fixture({archivePath:'.anvil/--vercel-repo--/runs/run.json',archiveRecord:{branch:'remote',pid:123}});const target=path.join(f.home,'.anvil',anvilBucket(f.repo),'runs','run.json');await fsNative.mkdir(path.dirname(target),{recursive:true});await fsNative.writeFile(target,'local');const r=await f.run();assert.equal(r.exitCode,3);assert.equal(await fsNative.readFile(target,'utf8'),'local');await f.clean();
});

test('collection runs in the worktree anvil created under the sandbox home, excluding the contract seed',async()=>{
 const f=await fixture();const r=await f.run();assert.equal(r.exitCode,0);
 const collect=f.calls.find(c=>c[0]==='remote'&&c[1].cmd==='bash'&&String(c[1].args.at(-1)).includes('/tmp/golem.patch'));
 assert.ok(collect,'collection command present');const line=collect[1].args.at(-1);
 assert.ok(line.includes("cd '/vercel/repo-anvil/anvil-spec-x'"),line.slice(0,200));assert.ok(line.includes(":!.anvil-input"));
 await f.clean();});

test('session transcripts import as a directory per session under the local bucket',async()=>{
 const f=await fixture({archivePath:'.anvil/--vercel-repo--/runs/run.json',sessionDir:true});const r=await f.run();assert.equal(r.exitCode,0);
 const copied=await fsNative.readFile(path.join(f.home,'.anvil',anvilBucket(f.repo),'sessions','--vercel-repo-anvil-x--','t.jsonl'),'utf8');assert.equal(copied,'{}\n');
 await f.clean();});

test('registry: an approved snapshot with a stale lockfile gives way to a registered match',async()=>{
 const f=await fixture({registry:[{snapshotId:'snapshot-approved',repo:'acme/repo',lockfileHash:'old',builtAt:'2026-01-01'},{snapshotId:'snapshot-fresh',repo:'acme/repo',lockfileHash:sha,builtAt:'2026-01-02'},{snapshotId:'snapshot-other-repo',repo:'acme/other',lockfileHash:sha,builtAt:'2026-01-03'}]});
 const r=await f.run();assert.equal(r.exitCode,0);assert.equal(f.calls.find(c=>c[0]==='create')[1].source.snapshotId,'snapshot-fresh');
 const handoff=JSON.parse(await fsNative.readFile(path.join(f.home,'scratch','logs','golem-repo-dispatch-123','handoff-result.json'),'utf8'));assert.equal(handoff.provenance.snapshotId,'snapshot-fresh');
 await f.clean();});
test('registry: a stale snapshot with no match and no rebuild approval stops before any sandbox is created',async()=>{
 const f=await fixture({registry:[{snapshotId:'snapshot-approved',repo:'acme/repo',lockfileHash:'old',builtAt:'2026-01-01'}]});
 const r=await f.run();assert.equal(r.exitCode,4);assert.ok(!f.calls.some(c=>c[0]==='create'));assert.ok(!f.calls.some(c=>c[0]==='build'));assert.ok(f.logs.some(l=>l.includes('rebuildSnapshot: true')));
 await f.clean();});
test('registry: rebuildSnapshot builds at the fork sha and dispatches on the new snapshot',async()=>{
 const f=await fixture({registry:[{snapshotId:'snapshot-approved',repo:'acme/repo',lockfileHash:'old',builtAt:'2026-01-01'}],req:{rebuildSnapshot:true}});
 const r=await f.run();assert.equal(r.exitCode,0);assert.deepEqual(f.calls.find(c=>c[0]==='build')[1],{repo:f.repo,ref:sha});assert.equal(f.calls.find(c=>c[0]==='create')[1].source.snapshotId,'snapshot-rebuilt');
 await f.clean();});
test('registry: a rebuild that does not match the fork lockfile is refused',async()=>{
 const f=await fixture({registry:[{snapshotId:'snapshot-approved',repo:'acme/repo',lockfileHash:'old',builtAt:'2026-01-01'}],req:{rebuildSnapshot:true},built:{snapshotId:'snapshot-wrong',lockfileHash:'other'}});
 const r=await f.run();assert.equal(r.exitCode,4);assert.ok(!f.calls.some(c=>c[0]==='create'));
 await f.clean();});
test('registry: an unknown approved snapshot keeps the in-sandbox hash check as the only guard',async()=>{
 const f=await fixture({registry:[{snapshotId:'something-else',repo:'acme/repo',lockfileHash:'old',builtAt:'2026-01-01'}]});
 const r=await f.run();assert.equal(r.exitCode,0);assert.equal(f.calls.find(c=>c[0]==='create')[1].source.snapshotId,'snapshot-approved');
 await f.clean();});

test('registry: no snapshotId in the request selects the registered match for the repo and lockfile',async()=>{
 const f=await fixture({req:{snapshotId:undefined},registry:[{snapshotId:'snapshot-other-repo',repo:'acme/other',lockfileHash:sha,builtAt:'2026-01-01'},{snapshotId:'snapshot-match',repo:'acme/repo',lockfileHash:sha,builtAt:'2026-01-02'}]});
 const r=await f.run();if(r.exitCode!==0)console.error(f.logs,f.calls);assert.equal(r.exitCode,0);assert.equal(f.calls.find(c=>c[0]==='create')[1].source.snapshotId,'snapshot-match');
 await f.clean();});
test('registry: no snapshotId and no match with rebuildSnapshot builds at the fork sha',async()=>{
 const f=await fixture({req:{snapshotId:undefined,rebuildSnapshot:true},registry:[{snapshotId:'snapshot-other-repo',repo:'acme/other',lockfileHash:sha,builtAt:'2026-01-01'}]});
 const r=await f.run();assert.equal(r.exitCode,0);assert.deepEqual(f.calls.find(c=>c[0]==='build')[1],{repo:f.repo,ref:sha});assert.equal(f.calls.find(c=>c[0]==='create')[1].source.snapshotId,'snapshot-rebuilt');
 await f.clean();});
test('registry: no snapshotId, no match, no rebuild stops before any sandbox is created',async()=>{
 const f=await fixture({req:{snapshotId:undefined},registry:[{snapshotId:'snapshot-other-repo',repo:'acme/other',lockfileHash:sha,builtAt:'2026-01-01'}]});
 const r=await f.run();assert.equal(r.exitCode,4);assert.ok(!f.calls.some(c=>c[0]==='create'));assert.ok(f.logs.some(l=>l.includes('acme/repo')&&l.includes('rebuildSnapshot: true')));
 await f.clean();});

test('hostGit clean guard ignores untracked files but refuses staged and unstaged tracked changes', async () => {
  const root = await fsNative.mkdtemp(path.join(os.tmpdir(), 'host-git-clean-'));
  const run = (args) => execFileAsync('git', args, { cwd: root });
  const fs = { exists: async p => { try { await fsNative.lstat(p); return true; } catch { return false; } } };
  const git = hostGit({ fs, exec: { run: (cmd, args, opts) => execFileAsync(cmd, args, opts) } });
  try {
    await run(['init', '-q']);
    await run(['config', 'user.email', 'sandbox-test@example.com']);
    await run(['config', 'user.name', 'Sandbox Test']);
    await fsNative.writeFile(path.join(root, 'tracked.txt'), 'committed\n');
    await run(['add', 'tracked.txt']);
    await run(['commit', '-qm', 'initial']);

    await fsNative.writeFile(path.join(root, 'untracked.txt'), 'one\n');
    await git.assertClean(root);
    await fsNative.mkdir(path.join(root, '.anvil-worktrees', 'x'), { recursive: true });
    await fsNative.writeFile(path.join(root, '.anvil-worktrees', 'x', 'file'), 'worktree\n');
    await git.assertClean(root);

    await fsNative.writeFile(path.join(root, 'tracked.txt'), 'modified\n');
    await assert.rejects(git.assertClean(root), /local repository must be clean .*unstaged/);
    await fsNative.writeFile(path.join(root, 'tracked.txt'), 'committed\n');
    await fsNative.writeFile(path.join(root, 'staged-new.txt'), 'staged\n');
    await run(['add', 'staged-new.txt']);
    await assert.rejects(git.assertClean(root), /local repository must be clean .*staged/);
  } finally { await fsNative.rm(root, { recursive: true, force: true }); }
});

test('sandbox provenance prefers the request address, then the environment fallback, then null', async () => {
  const specified = await fixture();
  try {
    specified.clock.env.ANVIL_SUMMONER_ADDRESS = 'environment-address';
    const result = await specified.run();
    const handoff = JSON.parse(await fsNative.readFile(path.join(result.artifactDir, 'handoff-result.json'), 'utf8'));
    assert.equal(handoff.provenance.summonerAddress, 'session-address');
  } finally { await specified.clean(); }
  for (const [address, expected] of [['fallback-session', 'fallback-session'], [undefined, null]]) {
    const f = await fixture();
    try {
      delete f.req.summonerAddress;
      await fsNative.writeFile(f.request, JSON.stringify(f.req));
      if (address !== undefined) f.clock.env.ANVIL_SUMMONER_ADDRESS = address;
      else delete f.clock.env.ANVIL_SUMMONER_ADDRESS;
      const result = await f.run();
      assert.equal(result.exitCode, 0);
      const handoff = JSON.parse(await fsNative.readFile(path.join(result.artifactDir, 'handoff-result.json'), 'utf8'));
      assert.equal(handoff.provenance.summonerAddress, expected);
    } finally { await f.clean(); }
  }
});

test('stale registry anvil dispatches with a warning and records both shas', async () => {
  const current = 'b'.repeat(40);
  const f = await fixture({ registry: [{ snapshotId: 'snapshot-approved', repo: 'acme/repo', lockfileHash: sha, anvilSha: sha }], currentAnvilSha: current });
  try {
    const result = await f.run();
    assert.equal(result.exitCode, 0);
    assert.ok(f.logs.some(line => line.includes('stale anvil') && line.includes(sha.slice(0, 9)) && line.includes(current.slice(0, 9)) && line.includes('rebuildSnapshot: true')));
    for (const file of ['manifest.json', 'handoff-result.json']) {
      const data = JSON.parse(await fsNative.readFile(path.join(result.artifactDir, file), 'utf8'));
      assert.deepEqual(data.anvilStale, { snapshot: sha, current });
    }
  } finally { await f.clean(); }
});

test('stale registry anvil rebuilds once at fork sha when approved', async () => {
  const f = await fixture({ registry: [{ snapshotId: 'snapshot-approved', repo: 'acme/repo', lockfileHash: sha, anvilSha: sha }], currentAnvilSha: 'b'.repeat(40), req: { rebuildSnapshot: true } });
  try {
    const result = await f.run();
    assert.equal(result.exitCode, 0);
    assert.equal(f.calls.filter(call => call[0] === 'build').length, 1);
    assert.deepEqual(f.calls.find(call => call[0] === 'build')[1], { repo: f.repo, ref: sha });
    assert.equal(f.calls.find(call => call[0] === 'create')[1].source.snapshotId, 'snapshot-rebuilt');
    assert.equal(f.logs.some(line => line.includes('stale anvil')), true);
  } finally { await f.clean(); }
});

test('registered snapshot without anvilSha does not emit a stale warning', async () => {
  const f = await fixture({ registry: [{ snapshotId: 'snapshot-approved', repo: 'acme/repo', lockfileHash: sha }], currentAnvilSha: 'b'.repeat(40) });
  try {
    const result = await f.run();
    assert.equal(result.exitCode, 0);
    assert.equal(f.logs.some(line => line.includes('stale anvil')), false);
  } finally { await f.clean(); }
});

test('pinned snapshot with no registry record dispatches without a stale warning', async () => {
  const f = await fixture({ registry: [{ snapshotId: 'other-snapshot', repo: 'acme/repo', lockfileHash: sha, anvilSha: sha }], currentAnvilSha: 'b'.repeat(40) });
  try {
    const result = await f.run();
    assert.equal(result.exitCode, 0);
    assert.equal(f.calls.find(call => call[0] === 'create')[1].source.snapshotId, 'snapshot-approved');
    assert.equal(f.logs.some(line => line.includes('stale anvil')), false);
  } finally { await f.clean(); }
});

test('credential expiry message reports remaining and required dispatch minutes', () => {
  const now = Date.parse('2026-01-01T00:00:00Z');
  assert.match(credentialExpiryMessage(null, 600_000, now), /no Vercel CLI credential found; run `vercel login`/);
  const message = credentialExpiryMessage({ token: 't', expiresAt: new Date(now + 4 * 60_000) }, 600_000, now);
  assert.match(message, /4 minutes left/);
  assert.match(message, /15 minutes/);
  assert.match(message, /lower timeoutMs/);
  assert.match(message, /vercel logout && vercel login/);
});

test('fresh and unknown-current registry anvil shas do not log stale warnings', async () => {
  for (const currentAnvilSha of [sha, undefined]) {
    const f = await fixture({ registry: [{ snapshotId: 'snapshot-approved', repo: 'acme/repo', lockfileHash: sha, anvilSha: sha }], currentAnvilSha });
    try {
      const result = await f.run();
      assert.equal(result.exitCode, 0);
      assert.equal(f.logs.some(line => line.includes('stale anvil')), false);
    } finally { await f.clean(); }
  }
});

test('sandbox runner sources lane env before scoped exports and captures summoner under -R', async () => {
  const root = await fsNative.mkdtemp(path.join(os.tmpdir(), 'summon-golem-runner-'));
  try {
    const home = path.join(root, 'home');
    const lanes = path.join(root, 'lane files');
    await fsNative.mkdir(path.join(home, '.scripts'), { recursive: true });
    await fsNative.mkdir(lanes, { recursive: true });
    const laneEnv = path.join(lanes, 'sandbox.env');
    await fsNative.writeFile(laneEnv, 'export VERCEL_TEAM_ID=from-lane\nexport VERCEL_PROJECT_ID=project-lane\n');
    const env = { ...process.env, HOME: home, ANVIL_SANDBOX_LANE_ENV: laneEnv, PATH: process.env.PATH, PI_SESSION_ID: 'id-from-session', PI_SESSION_ADDRESS: '' };
    const { stdout } = await execFileAsync('bash', [SUMMONER, '-R', '-n', '--sandbox', '-e', 'VERCEL_TEAM_ID=from-flag', 'test', 'prompt'], { cwd: process.cwd(), env });
    assert.ok(stdout.includes(`LANE_ENV=${laneEnv.replaceAll(' ', '\\ ')}`));
    assert.match(stdout, /\[\[ ! -r "\$LANE_ENV" \]\] \|\| source "\$LANE_ENV"/);
    assert.match(stdout, /export ANVIL_SUMMONER_ADDRESS=id-from-session/);
    assert.ok(stdout.indexOf('source "$LANE_ENV"') < stdout.indexOf('export VERCEL_TEAM_ID=from-flag'));
    const noAddress = await execFileAsync('bash', [SUMMONER, '-R', '-n', '--sandbox', 'test', 'prompt'], { cwd: process.cwd(), env: { ...env, PI_SESSION_ID: '', PI_SESSION_ADDRESS: '' } });
    assert.equal(noAddress.stdout.includes('export ANVIL_SUMMONER_ADDRESS='), false);
    assert.ok(!stdout.includes('from-lane'), 'runner must source the file, not inline its contents');
  } finally { await fsNative.rm(root, { recursive: true, force: true }); }
});

test('sandbox runner includes refusal and stale-anvil ping details while non-sandbox runner stays isolated', async () => {
  const root = await fsNative.mkdtemp(path.join(os.tmpdir(), 'summon-golem-ping-'));
  try {
    const home = path.join(root, 'home');
    await fsNative.mkdir(path.join(home, '.scripts'), { recursive: true });
    const bin = path.join(root, 'bin'); await fsNative.mkdir(bin);
    const piPost = path.join(bin, 'pi-post'); await fsNative.writeFile(piPost, '#!/bin/sh\nexit 0\n'); await fsNative.chmod(piPost, 0o755);
    const env = { ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}`, PI_SESSION_ADDRESS: 'session-address' };
    const sandbox = await execFileAsync('bash', [SUMMONER, '-n', '--sandbox', 'test', 'prompt'], { cwd: process.cwd(), env });
    assert.match(sandbox.stdout, /controller refused the request before dispatch:/);
    assert.match(sandbox.stdout, /grep -a 'controller error:' .*tail -n 1/);
    assert.match(sandbox.stdout, /\$\{verdict:0:300\}/);
    assert.match(sandbox.stdout, /anvilStale=/);
    const ordinary = await execFileAsync('bash', [SUMMONER, '-R', '-n', 'test', 'prompt'], { cwd: process.cwd(), env });
    assert.equal(ordinary.stdout.includes('controller refused the request before dispatch:'), false);
    assert.equal(ordinary.stdout.includes('anvilStale='), false);
    assert.equal(ordinary.stdout.includes('LANE_ENV'), false);
    assert.equal(ordinary.stdout.includes('ANVIL_SUMMONER_ADDRESS'), false);
  } finally { await fsNative.rm(root, { recursive: true, force: true }); }
});
