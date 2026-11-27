// The familiar's model as a pi-ai Model object. durable-harness pins pi-ai
// 1.0.4, whose catalog lacks the current gateway models (gpt-6.2-*, fable
// 5.2), so the Model comes from the catalog of the pi release installed on
// this host first, and the pinned catalog only as a fallback.

import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

// Mirrors summon-familiar.sh's alias_to_model, so -m means the same in both lanes.
export const ALIASES = {
  haiku: 'anthropic/claude-haiku-5.5:low',
  sol: 'openai/gpt-6.2-sol:high',
  sonnet: 'anthropic/claude-sonnet-5.5:medium',
  opus: 'anthropic/claude-opus-5.5:medium',
  fable: 'anthropic/claude-fable-5.2:high',
  luna: 'openai/gpt-6-luna:high',
  astra: 'openai/gpt-6.2-astra:high',
};
const LEVELS = ['off', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'];

/** `fable`, `openai/gpt-6.2-sol`, `openai/gpt-6.2-astra:xhigh` -> { id, thinkingLevel }. */
export function parseModelSpec(spec) {
  const full = ALIASES[spec] ?? spec;
  const m = /^([a-z0-9-]+\/[A-Za-z0-9._-]+)(?::([a-z]+))?$/.exec(String(full ?? ''));
  if (!m) throw new Error(`model must be an alias (${Object.keys(ALIASES).join('|')}) or provider/model[:effort], got ${spec}`);
  const thinkingLevel = m[2] ?? 'medium';
  if (!LEVELS.includes(thinkingLevel)) throw new Error(`unknown effort ${thinkingLevel} (${LEVELS.join('|')})`);
  return { id: m[1], thinkingLevel };
}

/** The gateway catalog of the pi release this host runs, or undefined. */
export function installedCatalog(home = homedir()) {
  try {
    const root = join(home, '.pi', 'agent', 'install');
    const version = readFileSync(join(root, 'current-version'), 'utf8').trim();
    const file = join(root, 'releases', version, 'node_modules', '@earendil-works', 'pi-ai', 'dist', 'providers', 'data', 'vercel-ai-gateway.json');
    return JSON.parse(readFileSync(file, 'utf8'));
  } catch {
    return undefined;
  }
}

/** Find a chat model by id in a provider data file ({ [api]: { 'chat:<id>': Model } }). */
export function findInCatalog(catalog, id) {
  for (const models of Object.values(catalog ?? {})) {
    const model = models?.[`chat:${id}`];
    if (model && model.id === id) return model;
  }
  return undefined;
}

/**
 * @param {string} spec
 * @param {{ catalog?: object, pinned?: (id: string) => object | undefined }} [sources]
 */
export function resolveModel(spec, sources = {}) {
  const { id, thinkingLevel } = parseModelSpec(spec);
  const model = findInCatalog(sources.catalog ?? installedCatalog(), id) ?? sources.pinned?.(id);
  if (!model) throw new Error(`no gateway model ${id} in the installed pi catalog or the pinned pi-ai catalog`);
  return { model: { ...model }, thinkingLevel, spec: `${id}:${thinkingLevel}` };
}
