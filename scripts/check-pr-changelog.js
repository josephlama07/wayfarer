#!/usr/bin/env node

const { execFileSync } = require('node:child_process');

const root = process.env.WORKSPACE || process.cwd();
const isPullRequest = Boolean(process.env.CHANGE_ID);
const description = process.env.PR_DESCRIPTION || '';
const exceptionMatch = description.split('\n').map((line) => line.trim()).filter((line) => line.startsWith('Changelog-Exception:'));
if (exceptionMatch.length > 1) {
  console.error('ERROR: duplicate changelog exception markers');
  process.exit(1);
}
const exception = process.env.CHANGELOG_EXCEPTION || (exceptionMatch[0] ? exceptionMatch[0].slice('Changelog-Exception:'.length).trim() : '');
const allowedExceptions = new Set(['documentation', 'ci', 'tooling']);

if (!isPullRequest) {
  console.log('PR_CHANGELOG_CHECK=SKIPPED');
  process.exit(0);
}

function git(...args) {
  return execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
}

let base;
try {
  if (process.env.PR_BASE_SHA) {
    base = process.env.PR_BASE_SHA;
  } else {
    const target = process.env.CHANGE_TARGET;
    if (!target) throw new Error('CHANGE_TARGET is required for pull-request builds');
    base = git('merge-base', 'HEAD', `origin/${target}`);
  }
} catch (error) {
  console.error(`ERROR: unable to determine pull-request base: ${error.message}`);
  process.exit(1);
}

let changedFiles;
try {
  changedFiles = git('diff', '--name-only', '--diff-filter=ACMR', `${base}...HEAD`).split('\n').filter(Boolean);
} catch (error) {
  console.error(`ERROR: unable to determine pull-request changed files: ${error.message}`);
  process.exit(1);
}

if (changedFiles.includes('CHANGELOG.md')) {
  console.log('PR_CHANGELOG_CHECK=PASSED');
  console.log('CHANGELOG_CHANGED=true');
  process.exit(0);
}

if (!exception) {
  console.error('ERROR: CHANGELOG.md was not modified; add an entry under ## Unreleased or set a valid changelog exception.');
  process.exit(1);
}

if (!allowedExceptions.has(exception)) {
  console.error(`ERROR: unsupported changelog exception: ${exception}`);
  process.exit(1);
}

const eligible = {
  documentation: (file) => file.startsWith('docs/') || file.endsWith('.md'),
  ci: (file) => file === 'Jenkinsfile' || file.startsWith('jenkins/') || file.startsWith('.github/'),
  tooling: (file) => file.startsWith('scripts/') || file.startsWith('test/') || file.startsWith('tests/') || file === 'package.json' || file === 'package-lock.json',
}[exception];

if (!changedFiles.length || !changedFiles.every(eligible)) {
  console.error(`ERROR: changelog exception '${exception}' does not cover all changed files.`);
  process.exit(1);
}

console.log(`PR_CHANGELOG_CHECK=PASSED_EXCEPTION_${exception.toUpperCase()}`);
