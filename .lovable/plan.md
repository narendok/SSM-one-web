# Inventory register parity and controlled GRN flow

## Goal
Create a governed inventory workspace that replicates the useful interaction patterns in the supplied Phase 8 reference—without copying its records—while retaining the current portal’s authoritative stock, receiving, allocation, audit, and permission controls. This is **not** a browser-local demo: inventory movements and receipts remain backend-owned, validated transactions.

## Current feature inventory

### Part register and catalogue — available now
- Part register with search by part number, name, manufacturer, or value; filters for package, manufacturer, hierarchical category, location, linked active project, stock/review state; sorting by name, quantity, or manufacturer.
- Stock counters for total, in stock, low stock, and out of stock.
- Controlled parent/child category hierarchy; category pages include descendants.
- Add/edit component form: part number, description/name, category, manufacturer, package/footprint, compatibility reference, voltage/current/temperature ratings, unit cost, supplier and supplier link, datasheet link, notes, low-stock threshold, one or more storage locations/bins, linked projects, and substitute parts.
- Supplier lookup, category suggestion, datasheet preview, provenance capture, and explicit review state for incomplete quick-added parts.
- Per-location quantities and total-stock calculation; removal of a location containing stock is blocked.
- Component-level projects and substitute relationships; selected parts can be shared as a BOM-compatible selection.

### Controlled stock movements — available now
- Add/remove stock adjustment against one chosen location with typed positive quantity, required reason, idempotency key, permission check, low/out-of-stock warning, and persistent movement history.
- Controlled location creation/edit/delete through protected inventory routines.
- History page for the latest 200 stock deltas: timestamp, action, part, location, actor, and note.
- Recovery workflow for historical stock issues is present in the register.

### Multi-part allocation and returns — available now
- Assign one or more parts as one material-issue bundle, with a typed quantity and selected location per item, optional project, notes, availability validation, idempotency key, shared issue number, and queued assignee notification.
- Add more parts to an open allocation by name or part number; remove lines before posting.
- Issue/return workflows use the existing protected material-issue and return contracts, with assignment status/history rather than browser-local audit data.
- Current limitation: the assignee picker is the legacy active R&D member list; it does **not** yet select a research owner and derive/lock that person’s department from the employee directory.

### Receiving, lots, and quality — available now
- GRN creation against a purchase order with vendor invoice/date, selected PO lines, received and rejected quantities, rejection reason/note, location or new bin, lot/date code, idempotency key, and official GRN number.
- Procurement can quick-add an unrecognised PO part to the register as needing review.
- Each receipt is held for incoming quality review rather than made freely allocatable; Quality can accept, hold, or reject with findings.
- Lot-level Stores inventory shows part, lot/reel, location, quantity available, quality status, and receipt date.
- GRN list shows vendor/PO/invoice, received items, locations, quantities, and receipt date.
- Current limitation: the incoming dialog is PO-led and uses lot/date code; supplier and PO reference are inherited from the selected order, and reel ID is not captured as a distinct field.

### Access and connected records — available now
- Register actions are permission-gated; stock adjustment and component saves require inventory/procurement authority or administrator authority on the server.
- Material receipt, movement, issue, return, lot and assignment records use existing protected backend routines; anonymous use is denied.
- Facility assets have a separate governed asset register and custody-assignment model.
- Current limitation: inventory parts do not yet have an explicit component-to-asset-catalog compatibility link, and category-based Hardware/Mechanical read scopes are not yet verified or implemented as a dedicated rule.

## Replica scope and delivery order

### 1. Preserve and tighten the existing controlled foundation
- Keep backend-owned, idempotent transactions for receipts, adjustments, issues, returns, lots, and history; do not introduce browser-local stock or audit records.
- Confirm every new mutation uses the existing permission model and immutable transaction history.
- Add focused rule tests for quantity validation, idempotent replay, held/rejected receipt availability, and authorised actor paths before any new interface is enabled.

### 2. Complete the component register
- Retain the existing Add Part form and extend only missing structured fields: controlled category/subcategory, richer specifications, storage bin, linked projects, and an optional asset-catalog compatibility link.
- Expand the controlled taxonomy with harnesses and subcategories; enclosures; connectors; PCB/electronic components; test equipment; production consumables; software/firmware tools; and packaging.
- Define taxonomy stewardship and migration/backfill rules so existing categories and component records remain intact.
- Provide a part-detail view that brings together stock by location, linked projects, linked compatible assets, specifications, approved alternatives, current allocations, lots, and movement history.

### 3. Improve findability and register operations
- Retain current search, hierarchy, manufacturer, package, location, project, stock/review filters, and sorting.
- Add asset-link and allocation-state filters only after their authoritative relations exist.
- Add a compact detail-opening pattern from the register without weakening the existing action permissions.

### 4. Finish allocation ergonomics
- Keep the current multi-line allocation bundle, per-line location choice, typed quantities, optional project, notes, stock validation, and return trail.
- Replace the legacy R&D-member picker with a research-owner selector from active employees; resolve and display the owner’s department server-side, lock it in the issue receipt, and reject stale/ineligible owners.
- Keep all allocation, issue, return, and adjustment history in the authoritative audit trail; do not add a browser-only substitute.

### 5. Refine the GRN-to-quality-to-available flow
- Preserve PO-led GRN creation, official receipt numbering, invoice metadata, accepted/rejected quantities, bin/location, lot/date code, idempotency, and transaction logging.
- Add a distinct reel identifier only if the data contract and lot traceability rules accept it; do not overload lot/date code ambiguously.
- Keep every newly received lot on quality hold until the authorised incoming inspection accepts it. Held/rejected quantities must remain unavailable for allocation, with an auditable disposition.
- Surface the receipt-to-lot-to-inspection chain in both the part detail and Stores views.

### 6. Add governed asset compatibility and scoped visibility
- Add an explicit, auditable component-to-asset compatibility relation for harnesses, enclosures, and related mechanical inventory; do not reuse asset custody assignments as a compatibility shortcut.
- Define and test category-based Hardware and Mechanical visibility against existing permission policies before enabling it. Procurement remains the controller of create, receive, adjust, allocate, and archive actions.

## Out of scope
- Copying any records, source data, users, policies, or backend contracts from the reference project.
- Browser-local demo inventory, browser-local audit trails, or fake operational success states.
- Replacing current official numbering, historical inventory records, locations, permissions, or protected routines.
- Any unrelated asset, Sales, feasibility, document, publishing, or authentication changes.

## Verification and release gates
- Add Part: required fields, controlled category, multiple locations, project links, low-stock threshold, duplicate/invalid input behaviour.
- Register: search, hierarchy/manufacturer/package/location/project/stock/review filters, sorting, and detail contents.
- Movement: large numeric adjustment, required reason, location choice, idempotent replay, negative-stock prevention, and history result.
- GRN: PO receipt, large quantity, new/existing bin, accepted/rejected split, hold before inspection, accepted availability, held/rejected unavailability, lot/reel traceability, and idempotent replay.
- Allocation: multiple parts, typed per-line quantities, stock-location validation, project/notes, eligible research owner with derived department, issue/return history, and rejected over-allocation.
- Assets and access: compatible-asset linking, Procurement write control, Hardware/Mechanical allowed-category reads, and denied cross-scope access.
- Run focused inventory and database-contract tests, type checking, and preview verification with no build or runtime errors before any release.

## Technical details
- Existing authoritative operations include stock adjustment, material issue/return, controlled location management, goods-receipt creation, lot records, incoming inspection, stock history, and permission checks. New work must extend these contracts rather than bypass them.
- Schema, role, grant, RLS, or migration work requires a separately reviewed backend increment with preflight, rollback plan, and concrete acceptance evidence.
- The present GRN and allocation workflows are live-data workflows; DEMO-only/browser-local data from the uploaded brief is deliberately not used because it would conflict with the current portal’s established inventory authority.
