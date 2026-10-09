#!/usr/bin/env node
/**
 * Source-only isolated acceptance harness for the pending structured-draft
 * metadata proposal. It does not connect to a database unless a future,
 * separately authorized executor consumes the command plan it returns.
 */
import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

export const ORIGINAL_BACKEND_REF = 'yyrvduosyyaluifqvwkr'
export const migrationPath = 'supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql'
export const specificationPath = 'supabase/pending/tests/sales_opportunity_structured_draft_metadata_acceptance.sql'

export const requiredFixtureInputs = [
  'SALES_MANAGER_USER_ID', 'OUTSIDER_USER_ID', 'OPPORTUNITY_ID', 'CUSTOMER_ID',
  'SPECIFICATION_ID', 'MASTER_VERSION_ID', 'ALTERNATE_OPPORTUNITY_ID',
  'ALTERNATE_CUSTOMER_ID', 'ALTERNATE_SPECIFICATION_ID', 'ALTERNATE_MASTER_VERSION_ID',
  'REQUEST_KEY_CREATE', 'REQUEST_KEY_UPDATE', 'REQUEST_KEY_RESTORE',
  'REQUEST_KEY_CONFLICT', 'REQUEST_KEY_EMPTY_KIND_BASELINE',
]

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

export function sha256(value) {
  return createHash('sha256').update(value).digest('hex')
}

export async function fileSha256(path, readFileImpl = readFile) {
  return sha256(await readFileImpl(path))
}

export function backendRefFromConnectionUrl(connectionUrl) {
  if (typeof connectionUrl !== 'string' || !connectionUrl.trim()) {
    throw new Error('An isolated database connection URL is required for structural execution.')
  }
  let hostname
  try {
    hostname = new URL(connectionUrl).hostname
  } catch {
    throw new Error('The isolated database connection URL is invalid.')
  }
  const match = hostname.match(/^db\.([a-z0-9]{20})\.supabase\.co$/i)
  if (!match) throw new Error('The connection URL must identify a managed database hostname.')
  return match[1]
}

export function assertIsolatedTarget(env) {
  const configuredRef = env.ACCEPTANCE_BACKEND_REF
  const approvedRef = env.ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF
  if (!configuredRef || !approvedRef || configuredRef !== approvedRef) {
    throw new Error('The configured target must exactly match the explicitly approved isolated backend reference.')
  }
  if (configuredRef === ORIGINAL_BACKEND_REF) throw new Error('Refusing the original/shared backend.')
  if (env.ACCEPTANCE_DATABASE_URL) {
    const connectionRef = backendRefFromConnectionUrl(env.ACCEPTANCE_DATABASE_URL)
    if (connectionRef !== configuredRef) throw new Error('The connection URL target does not match the approved isolated backend reference.')
  }
  return configuredRef
}

export function assertFixtureInputs(env) {
  const missing = requiredFixtureInputs.filter((key) => !env[key])
  const malformed = requiredFixtureInputs.filter((key) => env[key] && !uuidPattern.test(env[key]))
  if (missing.length || malformed.length) {
    throw new Error(`Explicit existing fixture inputs are required; missing: ${missing.join(', ') || 'none'}; malformed: ${malformed.join(', ') || 'none'}.`)
  }
}

export async function buildStructuralPlan({ env = process.env, readFileImpl = readFile, root = process.cwd() } = {}) {
  const backendRef = assertIsolatedTarget(env)
  assertFixtureInputs(env)
  const migration = resolve(root, migrationPath)
  const specification = resolve(root, specificationPath)
  const migrationSha256 = await fileSha256(migration, readFileImpl)
  const specificationSha256 = await fileSha256(specification, readFileImpl)
  if (env.ACCEPTANCE_MIGRATION_SHA256 !== migrationSha256 || env.ACCEPTANCE_SPECIFICATION_SHA256 !== specificationSha256) {
    throw new Error('The approved migration or acceptance-specification hash does not match the reviewed local source.')
  }
  return {
    status: 'READY_FOR_SEPARATELY_AUTHORIZED_STRUCTURAL_EXECUTION',
    backendRef,
    migration: { path: migrationPath, sha256: migrationSha256 },
    specification: { path: specificationPath, sha256: specificationSha256 },
    mode: 'ROLLBACK_ONLY',
    fixtures: requiredFixtureInputs,
    limits: [
      'This plan proves configuration and source identity only.',
      'It does not prove caller RLS, authenticated transport, outsider denial, or concurrency.',
      'It must run only after an isolated deployment authorization; the SQL specification ends in ROLLBACK.',
    ],
  }
}

async function main() {
  console.log(JSON.stringify(await buildStructuralPlan()))
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : 'Isolated acceptance preflight failed.')
    process.exitCode = 69
  })
}