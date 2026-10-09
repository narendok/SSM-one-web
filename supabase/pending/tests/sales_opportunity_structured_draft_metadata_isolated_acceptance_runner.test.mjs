import { describe, expect, it } from 'vitest'
import {
  ORIGINAL_BACKEND_REF,
  assertIsolatedTarget,
  backendRefFromConnectionUrl,
  buildStructuralPlan,
  requiredFixtureInputs,
} from './sales_opportunity_structured_draft_metadata_isolated_acceptance_runner.mjs'

const isolatedRef = 'abcdefghijklmnopqrst'
const fixtureEnv = Object.fromEntries(requiredFixtureInputs.map((key, index) => [
  key,
  `00000000-0000-4000-8000-${String(index + 1).padStart(12, '0')}`,
]))

describe('structured-draft isolated acceptance preflight', () => {
  it('refuses the original backend and a connection URL whose backend differs from approval', () => {
    expect(() => assertIsolatedTarget({ ACCEPTANCE_BACKEND_REF: ORIGINAL_BACKEND_REF, ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF: ORIGINAL_BACKEND_REF })).toThrow('original/shared')
    expect(() => assertIsolatedTarget({ ACCEPTANCE_BACKEND_REF: isolatedRef, ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF: isolatedRef, ACCEPTANCE_DATABASE_URL: 'postgresql://x@db.yyrvduosyyaluifqvwkr.supabase.co:5432/postgres' })).toThrow('does not match')
  })

  it('extracts only a managed database backend reference from a connection URL', () => {
    expect(backendRefFromConnectionUrl(`postgresql://x@db.${isolatedRef}.supabase.co:5432/postgres`)).toBe(isolatedRef)
    expect(() => backendRefFromConnectionUrl('postgresql://x@example.test/postgres')).toThrow('managed database')
  })

  it('requires every explicit pre-existing identity, fixture, and request key', async () => {
    await expect(buildStructuralPlan({ env: { ACCEPTANCE_BACKEND_REF: isolatedRef, ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF: isolatedRef } })).rejects.toThrow('Explicit existing fixture inputs')
  })

  it('fails closed when either reviewed source hash changes', async () => {
    const readFileImpl = async (path) => Buffer.from(path.includes('acceptance.sql') ? 'specification' : 'migration')
    await expect(buildStructuralPlan({
      env: { ...fixtureEnv, ACCEPTANCE_BACKEND_REF: isolatedRef, ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF: isolatedRef, ACCEPTANCE_MIGRATION_SHA256: '0'.repeat(64), ACCEPTANCE_SPECIFICATION_SHA256: '1'.repeat(64) },
      readFileImpl,
    })).rejects.toThrow('hash does not match')
  })

  it('returns only a rollback-only structural plan after target, fixtures, and exact hashes validate', async () => {
    const readFileImpl = async (path) => Buffer.from(path.includes('acceptance.sql') ? 'specification' : 'migration')
    const { createHash } = await import('node:crypto')
    const digest = (value) => createHash('sha256').update(value).digest('hex')
    await expect(buildStructuralPlan({
      env: { ...fixtureEnv, ACCEPTANCE_BACKEND_REF: isolatedRef, ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF: isolatedRef, ACCEPTANCE_MIGRATION_SHA256: digest('migration'), ACCEPTANCE_SPECIFICATION_SHA256: digest('specification') },
      readFileImpl,
    })).resolves.toEqual(expect.objectContaining({ mode: 'ROLLBACK_ONLY', backendRef: isolatedRef }))
  })
})