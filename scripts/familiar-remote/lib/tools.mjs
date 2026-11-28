// Host tools of a remote familiar. They run in the driver on this Mac, not in
// the VM: `report` sends the final report to the summoner over pi-post, and
// `request_publish` takes the sandbox's changes through review and the
// approval inbox to a signed commit and a PR.

import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { deterministicChecks, modelReview } from './review.mjs';
import { BRANCH_PREFIX, publishSnapshot, readBaseFiles, restorePaths, summarize, takeSnapshot, updateChanges, updatePublished } from './publish.mjs';

export const REPO_DIR = '/workspace/repo';

/**
 * @typedef {{ name: string, address: string, repo: string, brief: string, summoner?: string }} Familiar
 * @typedef {{
 *   familiarOf: (runId: string) => Familiar | undefined,
 *   vmFor: (runId: string) => Promise<{ run: Function, readFile: Function }>,
 *   approvals: { request: Function, waitFor: Function },
 *   ask: (prompt: string) => Promise<string>,
 *   github: object,
 *   send: (to: string, from: string, body: string) => Promise<void>,
 *   update: (name: string, patch: object) => void,
 *   alert?: (id: string) => void,
 *   logDir: (name: string) => string,
 *   secrets?: () => string[],
 *   waitMs?: number,
 * }} Deps
 */

function familiarFor(deps, io) {
  const runId = io?.ctx?.runId;
  const familiar = runId ? deps.familiarOf(runId) : undefined;
  if (!familiar) throw new Error(`no familiar is registered for session ${runId}`);
  return { runId, familiar };
}

/** @param {Deps} deps */
export function reportTool(deps) {
  return {
    name: 'report',
    label: 'Report',
    description: 'Send your final report to the session that summoned you. Call it at the end of the brief, and again at the end of each later message you are given: what you did, the PR URL if you published one, test results, and anything left open.',
    inputSchema: { type: 'object', properties: { body: { type: 'string', description: 'The report, plain text, at most 6000 characters.' } }, required: ['body'], additionalProperties: false },
    replay: 'never',
    async execute(input, io) {
      const { familiar } = familiarFor(deps, io);
      const body = String(input?.body ?? '').slice(0, 6000);
      if (!body.trim()) return 'error: the report is empty';
      if (!familiar.summoner) {
        deps.update(familiar.name, { reported: true, report: body });
        return 'no summoner to report to; the report is saved with the familiar';
      }
      await deps.send(familiar.summoner, `rfam:${familiar.name}`, `Remote familiar ${familiar.name} (${familiar.repo}) reports:\n\n${body}`);
      deps.update(familiar.name, { reported: true, report: body });
      return `report sent to ${familiar.summoner}`;
    },
  };
}

/** @param {Deps} deps */
export function requestPublishTool(deps) {
  return {
    name: 'request_publish',
    label: 'Request publish',
    description: `Publish your changes in ${REPO_DIR} as a pull request. The driver takes every changed file in the working tree against the commit you cloned, checks it, and asks the user to approve it; it then commits on the branch ${BRANCH_PREFIX}<your name> (a signed commit) and opens the PR. This call waits for the user's answer, up to 30 minutes. You cannot push yourself. Call it when the work is done and the tests pass. Once your PR is open, calling it again pushes one more commit to the same PR with everything that changed since; the PR title and description stay as they are.`,
    inputSchema: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'PR title and commit headline: lowercase conventional commit, e.g. "fix(redact): keep trailing newline".' },
        body: { type: 'string', description: 'PR description: what changes for a user, and why.' },
      },
      required: ['title', 'body'],
      additionalProperties: false,
    },
    replay: 'never',
    async execute(input, io) {
      const { runId, familiar } = familiarFor(deps, io);
      const title = String(input?.title ?? '').trim().slice(0, 200);
      const body = String(input?.body ?? '').slice(0, 20_000);
      if (!title) return 'error: give a title';
      const previous = familiar.published;
      if (previous && !previous.base) return `already published: ${previous.pr} (this PR predates updates; it cannot take more commits)`;
      const branch = previous?.branch ?? `${BRANCH_PREFIX}${familiar.name}`;
      let snapshot;
      let baseContent;
      try {
        const vm = await deps.vmFor(runId);
        snapshot = await takeSnapshot(vm, REPO_DIR);
        if (previous) {
          baseContent = await readBaseFiles(vm, REPO_DIR, snapshot.base, restorePaths(previous, snapshot));
          updateChanges(previous, snapshot, baseContent); // refuses a moved base or no change, before anyone is asked
          const pr = await deps.github.pr(familiar.repo, previous.number);
          if (pr.state !== 'open') return `error: PR #${previous.number} is ${pr.merged_at ? 'merged' : pr.state}; it cannot take more commits. Report instead.`;
        }
      } catch (e) {
        return `error: could not take the changes from the sandbox: ${e.message}`;
      }
      const dir = deps.logDir(familiar.name);
      mkdirSync(dir, { recursive: true });
      const patchPath = join(dir, `publish-${snapshot.digest.slice(0, 12)}.patch`);
      writeFileSync(patchPath, snapshot.patch);

      const findings = deterministicChecks(snapshot, deps.secrets?.() ?? []);
      if (findings.length) {
        deps.update(familiar.name, { lastPublish: { status: 'refused', findings, patch: patchPath } });
        return `refused before review, nothing was sent to the user:\n- ${findings.join('\n- ')}\nFix these and call request_publish again.`;
      }
      // The summoner's and the user's steers and follow-ups change the scope, so the review reads them with the brief; anyone else's do not.
      const scope = [familiar.brief, ...(familiar.messages ?? []).filter((m) => m.summoner || m.user).map((m, i) => `Later message ${i + 1} from the ${m.user ? 'user' : 'summoner'}:\n${m.body}`)].join('\n\n');
      const review = await modelReview({ brief: scope, patch: snapshot.patch, ask: deps.ask });
      if (review.verdict === 'deny') {
        deps.update(familiar.name, { lastPublish: { status: 'denied-by-review', notes: review.notes, patch: patchPath } });
        return `the review denied this publish, nothing was sent to the user:\n- ${review.notes.join('\n- ')}`;
      }

      // `command` is what the overview and `approvals list` show; the hash covers the whole call, digest included.
      const command = previous ? `push commit "${title}" to PR #${previous.number} on ${familiar.repo} (${branch})` : `open PR "${title}" on ${familiar.repo} from ${branch}`;
      const call = { command, ...(previous ? { pr: previous.number, after: previous.commit } : {}), repo: familiar.repo, branch, base: snapshot.base, digest: snapshot.digest, title, body: createHash('sha256').update(body).digest('hex') };
      const reason = [
        previous
          ? `remote familiar ${familiar.name}: one more commit on ${previous.pr}; the branch becomes ${summarize(snapshot)} against the base (the diff is the whole PR)`
          : `remote familiar ${familiar.name}: PR on ${familiar.repo} from ${branch}, ${summarize(snapshot)}`,
        `diff: ${patchPath}`,
        ...(review.verdict === 'hold' ? [`review held it: ${review.notes.join('; ')}`] : []),
        ...snapshot.notes,
      ].join('\n');
      const req = deps.approvals.request({
        tool: 'request_publish',
        input: call,
        rule: 'remote-publish',
        reason,
        address: familiar.address,
        cwd: `github.com/${familiar.repo}`,
        head: snapshot.digest,
        waitMs: deps.waitMs,
      });
      deps.update(familiar.name, { lastPublish: { status: 'pending', approval: req.id, patch: patchPath, review: review.verdict } });
      deps.alert?.(req.id);
      const answer = await deps.approvals.waitFor(req.id, req.hash, { signal: io?.signal });
      if (answer !== 'approved') {
        deps.update(familiar.name, { lastPublish: { status: answer, approval: req.id, patch: patchPath } });
        return `the user did not approve the publish (${answer}). Nothing was pushed.`;
      }
      try {
        const published = previous
          ? await updatePublished({ github: deps.github, repo: familiar.repo, previous, snapshot, title, body, baseContent })
          : await publishSnapshot({ github: deps.github, repo: familiar.repo, branch, snapshot, title, body });
        deps.update(familiar.name, { published, lastPublish: { status: 'published', approval: req.id, patch: patchPath } });
        return `published: ${published.pr} (commit ${published.commit.slice(0, 9)} on ${branch}${published.verified ? ', signed' : ', NOT verified'})`;
      } catch (e) {
        deps.update(familiar.name, { lastPublish: { status: 'failed', error: e.message, approval: req.id, patch: patchPath } });
        return `approved, but publishing failed: ${e.message}`;
      }
    },
  };
}
