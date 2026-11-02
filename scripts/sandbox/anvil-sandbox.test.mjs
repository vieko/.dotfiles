import test from 'node:test';
import assert from 'node:assert/strict';
import fsNative from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { runController } from './anvil-sandbox.mjs';

const keys=['repoUrl','forkSha','specPath','gate','scopes','contracts','model','snapshotId','teamId','projectId','ghStsPolicy','vcpus','timeoutMs','localRepo','dispatchId','summonerAddress'];
const OIDC='OIDC_TOKEN_marker';
const GH='GH_STS_TOKEN_marker';
const sha='a'.repeat(40);
async function fixture(options={}) {
  const root=await fsNative.mkdtemp(path.join(os.tmpdir(),'anvil-sandbox-test-'));
  const home=path.join(root,'home'); await fsNative.mkdir(home);
  const repo=path.join(root,'repo'); await fsNative.mkdir(repo);
  const req={repoUrl:'https://github.com/acme/repo.git',forkSha:sha,specPath:'spec.md',gate:['npm test'],scopes:['src/**'],contracts:[],model:'luna',snapshotId:'snapshot-approved',teamId:'team-test',projectId:'project-test',ghStsPolicy:'vieko-golem-sandbox-development',vcpus:2,timeoutMs:600000,localRepo:repo,dispatchId:'dispatch-123',summonerAddress:'session-address'};
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
      if(opts.cmd==='bash' && line.includes('GITHUB_BLOCKED')) stdout='GITHUB_BLOCKED REGISTRY_BLOCKED GATEWAY_OK';
      else if(opts.cmd==='bash' && line.includes('/opt/anvil-snapshot')) stdout=options.lockMismatch?'bad-hash':`${sha}\n`;
      else if(opts.cmd==='bash' && line.includes('GATEWAY_OK')) stdout=options.setupContradiction?'':'GATEWAY_OKGITHUB_OK';
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
    async apply(){calls.push(['apply']);}, async stateBucket(){return 'repo-bucket';}, async verifyImported(repo,id){calls.push(['verify-imported',id]);if(options.verifyFailure)throw new Error('status missing dispatch');},
  };
  const exec={async run(cmd,args,opts={}){calls.push(['exec',cmd,args]); if(args[0]==='-tzf')return{stdout:options.archivePath??'.anvil/repo-bucket/runs/run.json'};if(args[0]==='-tvzf')return{stdout:options.archiveVerbose??''};if(args[0]==='-xzf'){const target=path.join(opts.cwd,'.anvil','repo-bucket','runs','run.json');await fsNative.mkdir(path.dirname(target),{recursive:true});await fsNative.writeFile(target,JSON.stringify(options.archiveRecord??{branch:'remote',pid:123}));}return{stdout:''};}};
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
  return {root,home,repo,req,request,calls,sdk,fs,git,exec,credentials,logs,clock,secrets,old,async run(){try{return await runController(request,{sdk,fs,git,exec,credentials,clock,log:m=>logs.push(m)});}finally{for(const k of ['VERCEL_TOKEN','AI_GATEWAY_API_KEY']){if(old[k]===undefined)delete process.env[k];else process.env[k]=old[k];}}},async clean(){await fsNative.rm(root,{recursive:true,force:true});}};
}

for (const missing of keys) test(`request validation missing ${missing} has no create`,async()=>{
  const f=await fixture(); delete f.req[missing]; await fsNative.writeFile(f.request,JSON.stringify(f.req));
  const r=await f.run(); assert.equal(r.exitCode,4); assert.equal(f.calls.some(c=>c[0]==='create'),false); await f.clean();
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
test('missing ghStsPolicy fails validation before mint',async()=>{const f=await fixture();delete f.req.ghStsPolicy;await fsNative.writeFile(f.request,JSON.stringify(f.req));const r=await f.run();assert.equal(r.exitCode,4);assert.equal(f.calls.some(c=>c[0]==='mint'||c[0]==='oidc'||c[0]==='create'),false);await f.clean();});
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
 const f=await fixture({archivePath:'.anvil/repo-bucket/runs/run.json',archiveRecord:{branch:'remote',pid:123,note:'original'}});const r=await f.run();assert.equal(r.exitCode,0);const imported=JSON.parse(await fsNative.readFile(path.join(f.home,'.anvil','repo-bucket','runs','run.json'),'utf8'));assert.equal(imported.branch,'golem/dispatch-123');assert.equal('pid' in imported,false);assert.match(imported.note,/sandbox-test/);assert.equal(r.importStatus,'complete');await f.clean();
});
test('unsafe archive paths and archive symlinks are refused',async()=>{
 for(const opts of [{archivePath:'.anvil/repo-bucket/runs/../escape.json'},{archiveVerbose:'lrwxrwxrwx user/group 0 link -> /tmp/out'}]){const f=await fixture(opts);const r=await f.run();assert.equal(r.exitCode,3);assert.equal(f.calls.some(c=>c[0]==='exec'&&c[2][0]==='-xzf'),false);await f.clean();}
});
test('local status verification failure blocks green handoff',async()=>{const f=await fixture({verifyFailure:true});const r=await f.run();assert.equal(r.exitCode,3);assert.match(r.importStatus,/status missing dispatch/);await f.clean();});
test('record collision refuses import without overwriting local record',async()=>{
 const f=await fixture({archivePath:'.anvil/repo-bucket/runs/run.json',archiveRecord:{branch:'remote',pid:123}});const target=path.join(f.home,'.anvil','repo-bucket','runs','run.json');await fsNative.mkdir(path.dirname(target),{recursive:true});await fsNative.writeFile(target,'local');const r=await f.run();assert.equal(r.exitCode,3);assert.equal(await fsNative.readFile(target,'utf8'),'local');await f.clean();
});
