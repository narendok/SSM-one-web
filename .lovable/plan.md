# Inventory and asset replica plan

## Goal
Extend the existing governed inventory experience into a complete inventory-and-assets workspace while preserving its current stock, receiving, project-link, audit, and authorization controls. The uploaded brief is a requirements reference only; no sample records or browser-only transactions will be copied.

## Confirmed decisions
- **Wire harnesses**, not material hardness: treat them as project-linked connector-and-wire assemblies.
- **Classification:** wire harnesses have one controlled primary category plus Mechanical and Electrical cross-tags for discovery.
- **Assets:** keep production machinery and other serialized equipment in the separate asset register, not in stock-part inventory.
- **Recipients:** a part or harness can be issued only to an active member of its linked project team, after server-side scope validation.

## Delivery plan

### 1. Protect inventory authority and released-stock rules
- Retain backend-owned, idempotent receipts, adjustments, issues, returns, lots, and movement history.
- Verify and close the boundary between stock locations and incoming-quality lots before expanding allocation: held or rejected lots must not be issueable, and returns must retain a clear usable/inspection/quarantine disposition.
- Maintain existing official numbering, historical records, locations, and permissions. Do not create browser-local stock, audit, or fake success states.

### 2. Expand the controlled parts taxonomy
- Extend the existing hierarchical part categories without disturbing existing records.
- Add controlled paths for electronics, connectors, wire and cable, wire harnesses, mechanical parts, enclosures and enclosure subtypes, firmware tools, production tools, and packaging/consumables.
- Model wire harnesses as component records with connector/wire specifications, approved alternatives, linked projects, stock/lot traceability, and primary category plus Mechanical/Electrical discovery tags.
- Keep category stewardship, migration/backfill, validation, and duplicate-prevention rules explicit before enabling new selectors.

### 3. Complete the part register and project context
- Retain current search, hierarchy, manufacturer, package, location, stock/review state, and project filters.
- Add category/cross-tag, project-link, allocation state, and released-stock filters after their authoritative data contracts exist.
- Provide a part detail view covering specifications, project links, stock by location, released/held quantities, lots, approved substitutes, allocations, returns, movement history, and compatible assets.
- Keep component-to-project links descriptive and auditable; stock issue remains its own controlled transaction.

### 4. Introduce project-team-controlled issuance
- Extend the existing material issue/return flow instead of adding a parallel issuing path.
- Resolve each recipient from the active project team on the server; store the recipient, department context, project, issuer, and request key in the issued-record receipt.
- Permit multiple eligible project-team members for a feasible part/harness allocation, while rejecting inactive, removed, cross-project, or department-ineligible recipients.
- Preserve location selection, availability checks, partial returns, notifications, idempotent replay, and immutable issue/return history.

### 5. Keep assets separate but connected
- Expand the separate asset taxonomy into controlled classes and subclasses: office assets, production machinery, mechanical equipment, tools, and related subtypes.
- Keep serialized asset lifecycle, custody, facility location, maintenance, calibration, and handover history distinct from component quantities and lots.
- Add an auditable compatibility relation between a machine/asset and the parts, harnesses, enclosures, or consumables it uses; do not misuse custody assignments as compatibility links.
- Complete asset detail, classification, location/custodian selection, acceptance/return actions, and filters over protected asset rules.

### 6. Preserve receiving, GRN, and quality traceability
- Keep PO-led GRN, official receipt numbers, supplier/invoice data, accepted/rejected splits, lots/date codes, location/bin assignment, and idempotency.
- Retain quality hold before released availability and surface the receipt → lot → inspection → issue chain in part and Stores views.
- Add any distinct reel or harness serial identifier only after the traceability contract accepts it; do not overload lot/date code.

### 7. Deliver in small, accepted backend and interface increments
1. Read-only deployment/schema/permission preflight and released-lot allocation contract, with rollback and concurrency acceptance evidence.
2. Part taxonomy, harness specifications/cross-tags, and project-linked part detail.
3. Project-team recipient contract and controlled issue/return interface.
4. Separate asset classes/subclasses, asset compatibility links, and custody workflow completion.
5. Search, reporting, and operational views after the underlying records and access rules are accepted.

## Verification gates
- Category hierarchy, primary category/cross-tag validation, existing-record backfill, and enclosure/harness discovery.
- Harness project linkage, specifications, stock/lot traceability, substitutes, and compatible asset links.
- GRN/inspection lifecycle: pending, held, accepted, rejected, released availability, and denied allocation from non-released stock.
- Issuance: eligible project-team recipient, multiple approved recipients, removed/inactive/wrong-project denial, quantity/location validation, idempotent replay, partial/full return, and full audit trail.
- Assets: class/subclass validation, separate serialized lifecycle, custody acceptance/return, maintenance/calibration continuity, compatible-part links, and denied unauthorized actions.
- Focused contract tests, type checks, and preview verification before each interface is enabled.

## Technical details
- Current source evidence shows inventory components/categories, component-to-project links, controlled material issue/return, GRN/lots/incoming inspection, and a separate facility-asset/custody model. A live deployment preflight is required before relying on any migration-source contract.
- The current issue flow uses active R&D members; project-team eligibility requires a dedicated server/database contract rather than a client-side filter.
- Source evidence does not yet demonstrate that quality-held lot stock is excluded by every material-issue path; this is a mandatory first release gate.
- Schema, roles, grants, RLS, or migration work will be separately reviewed and applied only with explicit approval. Direct-write restrictions and unrelated Sales/feasibility work remain outside this plan.
