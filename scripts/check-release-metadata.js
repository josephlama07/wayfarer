#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const packagePath = path.join(root, 'package.json');
const changelogPath = path.join(root, 'CHANGELOG.md');
const releaseMode = process.argv.includes('--release');
const releaseTag = process.env.RELEASE_TAG || process.env.GIT_TAG || '';
const errors = [];

function readFile(filePath, label) {
  if (!fs.existsSync(filePath)) {
    errors.push(`${label} does not exist: ${path.relative(root, filePath)}`);
    return null;
  }

  const stat = fs.statSync(filePath);
  if (!stat.isFile()) {
    errors.push(`${label} is not a regular file: ${path.relative(root, filePath)}`);
    return null;
  }

  return fs.readFileSync(filePath, 'utf8');
}

function parseVersion(value) {
  if (typeof value !== 'string' || value !== value.trim() || value.startsWith('v')) {
    return false;
  }

  return /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/.test(value);
}

function normalizedTag(tag) {
  const match = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/.exec(tag);
  return match ? tag.slice(1) : null;
}

function hasReleaseHeading(version, changelogText) {
  return changelogText.split('\n').some((line) => {
    const prefix = `## [${version}] - `;
    if (!line.startsWith(prefix)) return false;
    const dateText = line.slice(prefix.length).trim();
    if (dateText.length !== 10 || dateText[4] !== '-' || dateText[7] !== '-') return false;
    if (![dateText.slice(0, 4), dateText.slice(5, 7), dateText.slice(8)].every((part) => /^\d+$/.test(part))) return false;
    const date = new Date(`${dateText}T00:00:00Z`);
    return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === dateText;
  });
}

const packageText = readFile(packagePath, 'package.json');
let packageJson = null;
if (packageText) {
  try {
    packageJson = JSON.parse(packageText);
  } catch (error) {
    errors.push(`package.json contains invalid JSON: ${error.message}`);
  }
}

const changelog = readFile(changelogPath, 'CHANGELOG.md');
const applicationVersion = packageJson?.version;

if (!parseVersion(applicationVersion)) {
  errors.push(`package.json.version must be a valid SemVer value without a leading v: ${applicationVersion ?? '<missing>'}`);
}

if (changelog && !/^##\s+Unreleased\s*$/im.test(changelog)) {
  errors.push('CHANGELOG.md must contain an "## Unreleased" section');
}

if (releaseMode) {
  if (!releaseTag) {
    errors.push('RELEASE_TAG or GIT_TAG is required in release mode');
  } else {
    const tagVersion = normalizedTag(releaseTag);
    if (!tagVersion) {
      errors.push(`release tag must use vMAJOR.MINOR.PATCH format: ${releaseTag}`);
    } else if (tagVersion !== applicationVersion) {
      errors.push(`release tag ${releaseTag} does not match package.json.version ${applicationVersion}`);
    } else if (changelog && !hasReleaseHeading(tagVersion, changelog)) {
      errors.push(`CHANGELOG.md must contain a release section for ${tagVersion}`);
    }
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(`ERROR: ${error}`);
  process.exit(1);
}

console.log(`APPLICATION_VERSION=${applicationVersion}`);
console.log('PACKAGE_VERSION_VALID=true');
console.log('CHANGELOG_FILE_PRESENT=true');
console.log('CHANGELOG_UNRELEASED_PRESENT=true');
if (releaseMode) {
  console.log(`RELEASE_TAG=${releaseTag}`);
  console.log('RELEASE_METADATA_VALID=true');
}
