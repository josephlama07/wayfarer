#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const scriptSource = path.join(__dirname, 'check-release-metadata.js');

function runCase({ packageJson = { version: '1.0.0' }, changelog = '## Unreleased\n', releaseTag, release = false, removePackage = false, removeChangelog = false }) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'wayfarer-metadata-'));
  const scriptsDir = path.join(root, 'scripts');
  fs.mkdirSync(scriptsDir);
  fs.copyFileSync(scriptSource, path.join(scriptsDir, 'check-release-metadata.js'));
  if (!removePackage) fs.writeFileSync(path.join(root, 'package.json'), JSON.stringify(packageJson));
  if (!removeChangelog) fs.writeFileSync(path.join(root, 'CHANGELOG.md'), changelog);

  const env = { ...process.env };
  if (releaseTag !== undefined) env.RELEASE_TAG = releaseTag;
  const result = spawnSync(process.execPath, [path.join(scriptsDir, 'check-release-metadata.js'), ...(release ? ['--release'] : [])], {
    cwd: root,
    env,
    encoding: 'utf8',
  });
  fs.rmSync(root, { recursive: true, force: true });
  return result;
}

function assertFails(options, message) {
  const result = runCase(options);
  assert.notEqual(result.status, 0, message);
  return `${result.stdout}${result.stderr}`;
}

function assertPasses(options, message) {
  const result = runCase(options);
  assert.equal(result.status, 0, `${message}\n${result.stdout}${result.stderr}`);
  return result.stdout;
}

assertPasses({}, 'valid metadata should pass');
assert.match(assertFails({ removePackage: true }, 'missing package.json should fail'), /package.json does not exist/);
assert.match(assertFails({ packageJson: { version: 1 } }, 'non-string package version should fail'), /package.json.version/);
assert.match(assertFails({ packageJson: { version: 'latest' } }, 'invalid SemVer should fail'), /package.json.version/);
assert.match(assertFails({ removeChangelog: true }, 'missing CHANGELOG.md should fail'), /CHANGELOG.md does not exist/);
assert.match(assertFails({ changelog: '# Changelog\n' }, 'missing Unreleased should fail'), /Unreleased/);
assert.match(assertFails({ release: true }, 'missing release tag should fail'), /RELEASE_TAG or GIT_TAG is required/);
assert.match(assertFails({ release: true, releaseTag: '1.0.0' }, 'tag without v should fail'), /vMAJOR.MINOR.PATCH/);
assert.match(assertFails({ release: true, releaseTag: 'v2.0.0' }, 'tag/version mismatch should fail'), /does not match/);
assert.match(assertFails({ release: true, releaseTag: 'v1.0.0', changelog: '## Unreleased\n' }, 'missing release section should fail'), /release section/);
assertPasses({ release: true, releaseTag: 'v1.0.0', changelog: '## Unreleased\n\n## [1.0.0] - 2026-11-02\n' }, 'valid release metadata should pass');

console.log('check-release-metadata tests passed');
