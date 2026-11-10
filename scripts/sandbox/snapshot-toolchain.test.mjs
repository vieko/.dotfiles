import test from 'node:test';
import assert from 'node:assert/strict';
import { detectPackageManager, installCommand, offlineConfigCommand, offlineInstallCommand, toolchainScript } from './snapshot-toolchain.mjs';

test('packageManager field wins over any lockfile on disk', () => {
  assert.deepEqual(detectPackageManager({ files: ['package-lock.json'], packageJson: { packageManager: 'pnpm@9.1.0' } }), { name: 'pnpm', version: '9.1.0', lockfile: 'pnpm-lock.yaml' });
  assert.deepEqual(detectPackageManager({ files: ['pnpm-lock.yaml'], packageJson: { packageManager: 'npm@10.2.0' } }), { name: 'npm', version: '10.2.0', lockfile: 'package-lock.json' });
});

test('packageManager field strips a corepack hash suffix', () => {
  assert.deepEqual(detectPackageManager({ files: [], packageJson: { packageManager: 'pnpm@8.6.0+sha512.abc' } }).version, '8.6.0');
});

for (const [name, file, lockfile] of [['pnpm', 'pnpm-lock.yaml', 'pnpm-lock.yaml'], ['npm', 'package-lock.json', 'package-lock.json']]) test(`lockfile fallback detects ${name} with no packageManager field`, () => {
  assert.deepEqual(detectPackageManager({ files: [file, 'README.md'], packageJson: null }), { name, version: null, lockfile });
});

test('both lockfiles present is refused', () => {
  assert.throws(() => detectPackageManager({ files: ['pnpm-lock.yaml', 'package-lock.json'], packageJson: null }), /ambiguous/);
});

test('neither lockfile present is refused', () => {
  assert.throws(() => detectPackageManager({ files: ['README.md'], packageJson: null }), /no supported lockfile/);
});

test('yarn.lock is refused even alongside a supported lockfile', () => {
  assert.throws(() => detectPackageManager({ files: ['yarn.lock', 'pnpm-lock.yaml'], packageJson: null }), /yarn is not supported/);
  assert.throws(() => detectPackageManager({ files: ['yarn.lock'], packageJson: {} }), /yarn is not supported/);
});

test('install commands are frozen and offline-capable', () => {
  assert.equal(installCommand({ name: 'pnpm' }), 'pnpm install --frozen-lockfile');
  assert.equal(installCommand({ name: 'npm' }), 'npm ci --no-audit --no-fund');
  assert.equal(offlineInstallCommand({ name: 'pnpm' }), 'pnpm install --frozen-lockfile --offline');
  assert.equal(offlineInstallCommand({ name: 'npm' }), 'npm install --no-audit --no-fund');
  assert.equal(offlineConfigCommand({ name: 'npm' }), 'npm config set offline true --location=user');
  assert.equal(offlineConfigCommand({ name: 'pnpm' }), null);
});

test('toolchainScript puts pnpm on PATH at the detected or default version; npm needs nothing but node', () => {
  assert.match(toolchainScript({ name: 'pnpm', version: '9.1.0' }), /corepack prepare pnpm@9\.1\.0 --activate/);
  assert.match(toolchainScript({ name: 'pnpm', version: null }), /corepack prepare pnpm@10\.33\.0 --activate/);
  assert.equal(toolchainScript({ name: 'npm' }), 'node -v && npm -v');
});

test('a packageManager version that is not a plain semver is refused before it reaches a shell', () => {
  for (const field of ['pnpm@10.33.0;curl example.com', 'npm@$(id)', 'pnpm@latest'])
    assert.throws(() => detectPackageManager({ files: ['pnpm-lock.yaml'], packageJson: { packageManager: field } }), /plain semver/);
});
