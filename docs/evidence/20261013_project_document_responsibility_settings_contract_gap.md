# Project document responsibility settings — contract gap note

**Status:** inspected source-only note. This note authorizes no SQL, schema, role, grant, policy, user, assignment, data, storage, runtime, or publishing change.

## Scope and inspected objects

This review covers the twelve planned native editable DOCX kinds only:

| Scope | Kind | Planned department | Current assignment state |
|---|---|---|---|
| Sales opportunity | SOR | Sales (`SAL`) | No deployed responsibility registry; reviewed DOCX path is gate-off. |
| Sales opportunity | NDA | Operations / Legal (`OPS`) | No deployed responsibility registry. Sales initiation is not Legal read/edit authority. |
| Sales opportunity | Commercial quotation | Sales (`SAL`) | No deployed responsibility registry. |
| Sales opportunity | Contract Review | Sales (`SAL`) | No deployed responsibility registry; reviewed DOCX path is gate-off. |
| Project | PRS | Hardware & R&D (`RND`) | No deployed responsibility registry. |
| Project | BOM | Hardware & R&D (`RND`) | No deployed responsibility registry. |
| Project | DFMEA | Hardware & R&D (`RND`) | No deployed responsibility registry. |
| Project | Manufacturing Control Plan | Production & Calibration (`PROD`) | No deployed responsibility registry. |
| Project | DVP&R | Hardware & R&D (`RND`), explicitly assigned for interdisciplinary use | No deployed responsibility registry. |
| Project | PDI | Production & Calibration (`PROD`) | No deployed responsibility registry. |
| Project | Commercial tax invoice | Finance (`FIN`) | No deployed responsibility registry. |
| Project | Annual skill matrix | Human Resources (`HR`) | No deployed responsibility registry; the Sales preview explicitly treats it as unsupported, not an HR record. |

The catalog mapping comes from `src/lib/structured-lifecycle-document-plan.ts` and `src/lib/structured-lifecycle-document-access.ts`. Existing IDs are deliberately not copied here: the prior evidence has read-only partial ID evidence for SAL, RND, PROD, FIN, and HR, while OPS / Legal was not asserted. No lookup or data query was made in this group.

## Existing primitives and what they do not establish

| Object | Inspected support | Insufficient for private document authority because |
|---|---|---|
| `employees` | Active employment, `user_id`, primary department, reporting/lead fields | It does not bind a person to an exact project/document kind/current template revision. |
| `employee_departments` | Employee-to-department membership | Membership alone is expressly insufficient for document discovery, edit, history, or download. |
| `project_team_members` | Project membership and discipline/access level | Membership is an additional project-scope check, not responsible-person authority. |
| `departments` | Code, active state, department lead | Department lead is not a private-document assignment or a bypass. |
| `department_process_templates` | Department template key, version, active/retired status | The generated source types do not expose the pending immutable document-revision relation; no runtime inference is permitted. |
| `document_control_registers` | Existing owner/reviewer employee, Drive node, department, project, source revision and controlled-version fields | These are historical/register anchors, not a configurable assignment resolver and current Drive/storage access policy. |
| `document_control_events` and Drive revisions | Existing event/revision lineage | Existing general Drive/register visibility cannot authorize future private DOCX metadata, edits, history, downloads, or direct links. |

## Reviewed pending registry contract

`supabase/pending/20261012_structured_lifecycle_docx_registry_contract.sql` is the smallest **additive pending contract** already present. It must remain uninstalled and unchanged in this group. It proposes:

- `structured_lifecycle_docx_responsibility_assignments`: immutable active/revoked assignment per exact Sales opportunity or project plus document kind; active partial unique indexes prevent duplicate roots.
- `structured_lifecycle_docx_template_pins`: one immutable approved department/kind template pin with exact template/version/document-revision/schema hash.
- `structured_lifecycle_docx_registry_audit_events`: append-only request-key and actor-bound assignment/template approval/revocation evidence.
- A resolver that derives the caller from `auth.uid()`, requires an active employee, current department membership, exact assignment, and for project scope current project-team membership plus handed-over source linkage.
- Revoke-only assignment/template mutations. A revocation invalidates future metadata resolution, edit, receipt, commit, history, download, and direct-link reads; existing human/document history is preserved rather than overwritten.

### Manager actor scope proposed by the pending contract

| Operation | Proposed allowed actor | Explicit exclusions |
|---|---|---|
| Project assignment or revocation | Active project-team member **and** scoped `lifecycle_can_manage_department` plus `can_access_department_drive` for that department | Ordinary project visibility, department membership, Sales visibility, and administrator status alone. |
| Sales pre-handover SOR / Contract Review assignment or revocation | Authenticated actor with `sales.manage`, exact opportunity/customer source, scoped lifecycle department-management and department-Drive authority | Sales permission alone; NDA and other Legal documents. |
| Template approval or revocation | Scoped lifecycle department-management and department-Drive authority | Template visibility, ordinary department membership, and client-side roles. |
| Private document use | The currently assigned active employee only; project scope also needs current project-team membership | Reviewer, department lead, project manager, Sales manager, and admin do not receive implicit edit/read authority. |

This is a pending contract, not an installed RPC surface: each entrypoint is explicitly revoked from browser and service roles in the reviewed source. A future activation requires separately accepted caller-authenticated grants and real-caller acceptance; this note does not specify or add either.

## Revision, conflict, audit, and revocation effects

1. Assignment and template identity are immutable after creation. Replacement requires revocation followed by a new active root, not an in-place rewrite.
2. Actor-bound request keys provide idempotent replay only for the same canonical payload; changed payloads conflict.
3. Source/template roots and rows are locked in a consistent order before resolver/receipt/commit checks. A stale assignment, template pin, employee status/membership, project membership, handover, source version, private location, object version, or receipt rejects the action.
4. Registry audit rows are append-only; revocation records a before/after state without erasing a historical document, Drive revision, or register entry.
5. The reviewed Sales materialization and trusted-receipt contracts repeat the active assignment, template, exact source, private location, object-version, checksum, and size checks at request, receipt, commit, history, and download boundaries. Those contracts remain frozen and gate-off.

## Corporate HR annual skill matrix boundary

`ANNUAL_SKILL_MATRIX` routes to HR in the catalog but has no accepted HR employee-skill source contract. Existing HR training/onboarding data and employee membership do not establish:

- which HR actor may assign an exact responsible employee for a project-linked skill matrix;
- what employee/capability/training evidence can be selected, redacted, retained, or exported;
- whether a matrix is project, department, workforce, or individual scope; or
- a separate HR read/download rule that prevents project, Sales, or general department visibility from exposing personnel data.

Therefore the skill matrix remains unavailable until an independently accepted HR data-scope and private-document assignment contract exists. It must not be exposed through local export merely because the catalog labels it HR.

## Source versus live prerequisites

- `ProjectStructuredDocuments` remains fail-closed: it exposes no project template titles, contents, or export entry until a backend resolver verifies current responsible-person authority.
- The lifecycle Settings screen is review-only. Its responsibility controls are disabled and cannot create, revoke, or approve anything.
- Existing Sales HTML history remains separate under its installed creator/requester and `sales.manage` rules; it is not proof of private DOCX authority or a reassignment path.
- Before any registry activation: install review must accept the frozen five-DOCX package in its recorded order; exact assignment/template/location records must be created by an authorized real caller; the trusted server object-reader/receipt boundary and restrictive private storage enforcement must be accepted; and real-caller tests must cover owner, non-owner, cross-department, reassignment/revocation, stale template/source, replay/conflict, history, download, and direct-link denial paths.
- The missing lifecycle-plan file `docs/planning/PROJECT_LIFECYCLE_GAP_AND_DELIVERY_PLAN_2026-10-05.md` remains absent. This note does not reconstruct it or represent any plan item as complete.

## Evidence references

- Routing and Legal boundary: `docs/evidence/20261013_lifecycle_legal_routing_matrix.md`
- Activation state: `docs/evidence/20261013_activation_handoff_status.md`
- Frozen registry package: `supabase/pending/20261012_structured_lifecycle_docx_registry_contract.sql`
- Frozen materialization package: `supabase/pending/20261012_sales_structured_docx_materialization_contract.sql`
- Frozen trusted receipt package: `supabase/pending/20261012_structured_lifecycle_docx_trusted_receipt_authority.sql`
- Existing fail-closed UI: `src/components/projects/ProjectStructuredDocuments.tsx`
