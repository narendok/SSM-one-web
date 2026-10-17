# Governed Smart BOM, Adaptive Purchase/Invoice Ingestion, and Asset Lifecycle Plan

## Goal
Create an enterprise-grade, inventory-aligned BOM, purchase-import, and asset lifecycle experience that combines the existing PartsBench workflow with multi-lifecycle BOMs (Tentative vs Released), arbitrary "random-style" purchase order/invoice ingestion via a governed review process, and end-to-end asset register import/export. It ensures full traceability across stock matching, purchasing decisions, project BOM baselines, and serialized equipment without ever allowing unreviewed, uninspected stock postings or automated approval bypasses.

## What users will be able to do
1. **Dual-Lifecycle BOM Management**:
   - Create and explore **Tentative BOMs** (provisional MPNs, design exploration, substitute evaluation, and "what-if" shortage simulations against live stock without claiming reservations).
   - Formally approve and lock **Released BOMs** (production-ready, strict catalog-matching, versioned baseline under ECO change control).
   - Compare BOM revisions side-by-side (identifying added/removed parts, quantity per board shifts, substitute changes, and cost deltas).
   - Export BOMs in multiple formats: full Indented/Hierarchical BOM, Flattened Production BOM with aggregated reference designators, and Procurement Shortage Requisitions.
2. **Adaptive Purchase Order & Invoice Ingestion ("Any-Style" Ingestion)**:
   - Import arbitrary, non-standard tabular spreadsheets (CSV, Excel `.xlsx`/`.xls`, TSV) or document files (PDF/scans via AI extraction) from any supplier, distributor, or custom fabricator.
   - Automatically normalize headers and values using fuzzy token matching across document IDs (PO #, Invoice #), vendor identities, line items (SKU, MPN, description, package), and commercial data (ordered/billed quantities, unit prices, taxes, totals).
   - Review and correct detected columns on an interactive mapping screen with instant confidence ratings (`High`, `Low`, `Unmapped`) before processing.
3. **Governed Pre-Inventory Review Process**:
   - Reconcile imported lines against the approved Vendor Register (`procurement.vendors`) and component catalog (`components`).
   - Flag unmatched parts, new vendor candidates, duplicate order/invoice rows, and PO line quantity/price variances in an interactive review staging table.
   - Accept, reject, remap, or split lines individually or in bulk.
   - Generate editable, grouped **Purchase Drafts** or **Inwarding (GRN) Drafts** from accepted lines while maintaining complete source file and row traceability.
4. **Controlled Receiving, GRN & Quality Release Boundary**:
   - Maintain strict separation: imported POs and invoices create drafts only; they NEVER directly increment available inventory.
   - Stock becomes usable only through the governed pathway: Stores Inwarding -> Inspection Lot (QC Hold / Quarantine) -> Quality Release -> Active Stock Bins.
   - Prevent any stock on QC hold or quarantine from being issued or allocated to BOMs.
5. **Asset Register Import, Export & Machinery Compatibility**:
   - Ingest and export serialized asset records (Production Machinery, Service & Maintenance Equipment, IMTE / Calibration Tools, and Enterprise Assets) via CSV/Excel.
   - Validate asset tags, serial number uniqueness, facility locations, and custodian employee IDs before committing.
   - Link machines and test jigs to the specific components, wire harnesses, and consumables they utilize (`compatible_component_ids`).
   - Export comprehensive asset registers, maintenance histories, and upcoming calibration schedules.

## Delivery stages

### 1. Dual-Lifecycle BOM Workspace (Tentative vs. Released)
- Audit and retain the current `/bom` import, mapping, stock matching, substitute selection, and sharing behavior.
- Support **Tentative BOMs**: permit provisional MPNs, generic descriptors, alternative comparisons, supplier quotes exploration, and preliminary cost rollups without hard stock reservations.
- Support **Released BOMs**: enforce full component resolution against approved catalog parts, lock revisions (Rev A, Rev B), and mandate change rationale for modifications.
- Consolidate the line-level results view: source values, matched part, stock by location, shortages, approved substitutes, cost variance, and assignment eligibility.
- Add deterministic matching explanations and manual override history so saved BOMs can be refreshed and audited safely.
- Provide comprehensive export formats: Indented BOM, Flattened Production BOM (with aggregated designators), and Shortage Requisitions.

### 2. Smart Project BOM Management & Revision Comparison
- Add project BOM revisioning with side-by-side diffing for quantity, part, cost, substitute, and lifecycle status changes.
- Support line-level annotations, requested quantities, substitute rationale, and engineering approval flags without enabling premature stock deduction.
- Re-run availability strictly against released, usable stock; separate available, reserved, and QC-held quantities.
- Maintain persistent exports for resolved BOMs, shortages, and procurement-ready line requisitions.

### 3. Adaptive Purchase Order & Invoice Ingestion Engine
- Add a flexible, multi-format import parser for arbitrary CSV, Excel, and PDF/image supplier files.
- Implement fuzzy column normalization with alias dictionaries covering varied naming conventions, date formats, and currencies.
- Provide a pre-import mapping screen with confidence ratings (`High`, `Low`, `Unmapped`) and inline column remapping dropdowns.
- Implement integrity and duplicate guards: flag repeated invoice numbers from the same vendor and duplicate PO line items.

### 4. Governed Review Staging & Reconciliation Gate
- Build the interactive Review Staging Table:
  - Match vendor names against `procurement.vendors`; flag unknown suppliers as candidates.
  - Match parts against `components`; distinguish Exact Match, Known Substitute, Candidate Part, and Unmatched.
  - Reconcile invoice lines against existing POs: detect quantity overages and price spikes.
- Provide row-level review actions: Accept, Reject/Ignore, Remap, or Split.
- Generate editable, grouped Purchase Drafts for PO imports and Inwarding (GRN) Drafts for invoice imports; retain source file and row metadata.

### 5. Controlled Receiving & Quality Release Boundary
- Keep purchase import, PO drafting, receipt, incoming inspection, and stock release strictly decoupled.
- Enforce the quality-hold invariant: incoming goods remain in QC Hold / Quarantine until formally accepted by inspection.
- Prohibit allocation or issuance of uninspected lots to any project, BOM, or work order.

### 6. Asset Register Import, Export & Compatibility Mapping
- Add bulk CSV/Excel import and export for assets across Production Machinery, Service Jigs, IMTE Instruments, and Facility Tooling.
- Validate serial number uniqueness, facility location, and active custodian membership prior to commit.
- Surface and maintain machine-to-component compatibility mappings (`compatible_component_ids`) in the Asset Register.
- Provide exportable calibration schedules, maintenance logs, and asset custody reports.

## Verification gates
- **BOM Verification**: Tentative BOM creation with provisional items, stock shortage simulation, transition to Released BOM with catalog resolution, revision diffing, and multi-format exports.
- **Ingestion Verification**: Upload arbitrary supplier formats (different column names, orders, date formats); verify correct fuzzy detection and mapping confidence.
- **Review Gate Verification**: Correctly flag duplicate invoices, detect PO price/quantity variances, stage unknown vendors/parts as candidates, and permit line acceptance/rejection.
- **Stock Invariant Verification**: Verify that importing invoices/POs never increases usable stock until an official GRN is generated, inspected, and released by Quality.
- **Asset Verification**: Bulk asset import with duplicate serial rejection, custodian verification, component compatibility linking, and register export.

## Technical details
- Reuse browser-side BOM parsing/matching utilities and project-BOM server contracts where authoritative.
- Extend existing tabular mapping utilities (`guessInventoryMapping`, `InventoryCsvMapping`) and document extraction (`extractInvoice`) into unified review staging contracts.
- Persist review staging drafts with source file, row index, match confidence, and user override records.
- Integrate with existing `procurement.orders`, `procurement.inward`, `inventory_lots`, and `assets` schemas.
- Write focused contract and unit tests for fuzzy mapping heuristics, revision comparison, duplicate detection, draft generation, and QC-hold enforcement.

## Boundaries
- No automatic component creation, purchase-order issuance, stock posting, GRN approval, supplier communication, or project approval from an import.
- Unrecognized suppliers or components become reviewable candidates, never silent auto-entries.
- The existing Mouser part lookup will be retained for component enrichment (MPN, manufacturer, description, package, datasheet, and availability) and verified against its current integration before changes.
