# Smart BOM and purchase-import replica

## Goal
Create a complete, inventory-aligned BOM and purchase-import experience that combines the existing PartsBench workflow with selected interaction patterns from an external reference when supplied. It will cover stock matching, purchasing decisions, and controlled project BOM management without enabling unreviewed procurement or receiving actions.

## What users will be able to do
1. Import BOMs from CSV, Excel, or pasted tabular data; correct the detected columns before matching.
2. Match every line against stock using normalized MPN/manufacturer rules, known substitutes, footprint/value compatibility, and available quantity.
3. Review exact, close, substitute, and missing results; select an alternate stocked component when needed and preserve the rationale.
4. Save a named, revisioned BOM under a project, reopen it, refresh the stock match, compare revisions, and export the resolved BOM or shortage list.
5. Turn selected shortages into a grouped purchase draft by supplier, with quantities, links, preferred alternatives, and BOM/project traceability.
6. Import supplier purchase files into a review screen that validates headers, duplicates, quantities, supplier identity, and component matches before any draft is created.
7. Keep receiving separate from import: imported purchasing data creates drafts only. Stock becomes available only through the existing controlled receiving and quality-release path.

## Delivery stages

### 1. Inventory-aligned BOM workspace
- Audit and retain the current `/bom` import, mapping, match, substitute, share, project-save, and export behavior.
- Consolidate the results view into a clear line-level workspace: source values, matched part, stock by location, shortages, substitutes, cost variance, assignment/reservation eligibility, and resolution state.
- Add deterministic matching explanations and manual override history so a saved BOM can be understood and safely refreshed later.
- Preserve existing project BOM records and their read-only saved revisions.

### 2. Smart project BOM management
- Add project BOM revisions and a comparison view for quantity, part, cost, and substitute changes.
- Support line annotations, requested quantity, approved substitute choice, and controlled status indicators without making a BOM approval itself authorize stock movement or purchasing.
- Re-run availability against current released stock only; show held, reserved, and available quantities separately where the existing data model supports them.
- Maintain exports for resolved BOMs, shortages, and a procurement-ready line list.

### 3. Purchase-file import and planning
- Add a dedicated purchase-import review flow for CSV/Excel supplier files and normalized column mapping.
- Match supplier lines to components and suppliers, flag unknown parts, duplicate supplier order lines, quantity/cost anomalies, and BOM-line conflicts.
- Create only editable, grouped purchase drafts from accepted review lines; retain source filename and import-row traceability.
- Prefill the existing purchase-order workflow rather than bypassing its authorization, numbering, or audit boundary.

### 4. Controlled receiving boundary
- Keep purchase import, PO drafting, receipt, incoming inspection, and stock release as distinct states.
- Do not treat a supplier file or received quantity as automatically available inventory.
- Reconcile the register/GRN plan’s quality-hold requirement before connecting purchasing drafts to stock availability, reservations, or project issue/return.

### 5. Reference-replica polish
- When an external reference is provided, map its observable workflows and field behavior to the secure flows above, reproducing only compatible functionality and visual patterns.
- Use the established inventory visual language and responsive table patterns; avoid a parallel inventory or procurement system.

## Technical details
- Reuse the current browser-side BOM parsing/matching utilities and project-BOM server contracts where they remain authoritative.
- Inspect current purchase-order, supplier, receipt, inventory-lot, reservation, and quality contracts before changing persistence or mutations.
- Any new data model or permission change requires a separate reviewed backend increment with explicit grants, row-level policies, migration tests, and authorization checks.
- Add focused tests for normalization/matching, revision comparison, supplier import validation, duplicate handling, draft-only creation, and held-stock exclusion.
- Verify the end-to-end flow with a signed-in user: import BOM, resolve lines, save revision, generate a purchase draft, and confirm no imported line changes stock before the controlled receipt/release flow.

## Boundaries
- No automatic component creation, purchase-order issuance, stock posting, GRN approval, supplier communication, or project approval from an import.
- Pending procurement-review and direct-write transition contracts remain separate and are not enabled by this work.
- The existing Mouser part lookup will be retained for component enrichment (MPN, manufacturer, description, package, datasheet, and availability) and verified against its current integration before changes.
