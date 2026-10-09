import { describe, expect, it } from 'vitest'
import {
  ORIGINAL_BACKEND_REF,
  assertCanonicalBackendRef,
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
  const baseEnv = {
    ...fixtureEnv,
    ACCEPTANCE_BACKEND_REF: isolatedRef,
    ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF: isolatedRef,
    ACCEPTANCE_DATABASE_URL: `postgresql://example@db.${isolatedRef}.supabase.co:5432/postgres`,
  }

  it('refuses the original backend in every casing, malformed references, and mismatched hosts', () => {
    expect(() => assertIsolatedTarget({ ACCEPTANCE_BACKEND_REF: ORIGINAL_BACKEND_REF, ACCEPTANCE_APPROVED_ISOLATED_BACKEND_REF: ORIGINAL_BACKEND_REF })).toThrow('original/shared')
    expect(() => assertCanonicalBackendRef(ORIGINAL_BACKEND_REF.toUpperCase(), 'ref')).toThrow('canonical lowercase')
    expect(() => assertIsolatedTarget({ ...baseEnv, ACCEPTANCE_BACKEND_REF: 'NOT-A-REF' })).toThrow('canonical lowercase')
    expect(() => assertIsolatedTarget({ ...baseEnv, ACCEPTANCE_DATABASE_URL: 'postgresql://x@db.yyrvduosyyaluifqvwkr.supabase.co:5432/postgres' })).toThrow('does not match')
  })

  it('accepts only a managed postgres URL with the exact hostname and port', () => {
    expect(backendRefFromConnectionUrl(`postgresql://x@db.${isolatedRef}.supabase.co:5432/postgres`)).toBe(isolatedRef)
    expect(backendRefFromConnectionUrl(`postgres://x@db.${isolatedRef}.supabase.co:5432/postgres`)).toBe(isolatedRef)
    expect(() => backendRefFromConnectionUrl('postgresql://x@example.test/postgres')).toThrow('managed database')
    expect(() => backendRefFromConnectionUrl(`mysql://x@db.${isolatedRef}.supabase.co:5432/postgres`)).toThrow('postgresql or postgres')
    expect(() => backendRefFromConnectionUrl(`postgresql://x@db.${isolatedRef}.supabase.co:6543/postgres`)).toThrow('managed database port')
    expect(() => assertIsolatedTarget({ ...baseEnv, ACCEPTANCE_DATABASE_URL: undefined })).toThrow('database URL is required')
  })

  it('requires every explicit pre-existing identity, fixture, and request key', async () => {
    await expect(buildStructuralPlan({ env: { ...baseEnv, SALES_MANAGER_USER_ID: undefined } })).rejects.toThrow('Explicit existing fixture inputs')
  })

  it('fails closed when either reviewed source hash changes', async () => {
    const readFileImpl = async (path) => Buffer.from(path.includes('acceptance.sql') ? 'specification' : 'migration')
    await expect(buildStructuralPlan({
      env: { ...baseEnv, ACCEPTANCE_MIGRATION_SHA256: '0'.repeat(64), ACCEPTANCE_SPECIFICATION_SHA256: '1'.repeat(64) },
      readFileImpl,
    })).rejects.toThrow('hash does not match')
  })

  it('returns a non-executing configuration plan without credentials after local checks validate', async () => {
    const readFileImpl = async (path) => Buffer.from(path.includes('acceptance.sql') ? 'specification' : 'migration')
    const { createHash } = await import('node:crypto')
    const digest = (value) => createHash('sha256').update(value).digest('hex')
    await expect(buildStructuralPlan({
      env: { ...baseEnv, ACCEPTANCE_MIGRATION_SHA256: digest('migration'), ACCEPTANCE_SPECIFICATION_SHA256: digest('specification') },
      readFileImpl,
    })).resolves.toEqual(expect.objectContaining({ status: 'CONFIGURATION_PLAN_ONLY', mode: 'NON_EXECUTING', backendRef: isolatedRef }))
  })
})