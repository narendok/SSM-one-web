# SSM One — document catalogue

Refined: 14 October 2026. **Reference for the web portal; not another implementation plan.**

The original 89 annexure item/note blocks are organized into **38 document/record families**, including the later Customer Register and Master/SOR clarifications. A family is a logical group, not one mandatory file. Unique subtypes and confidential scopes stay separate; no source requirement is discarded.

Use [the web master plan](SSM_ONE_WEB_PORTAL_MASTER_PLAN.md) for delivery order. The full source/code mapping is in [the catalogue JSON](SSM_ONE_DOCUMENT_CATALOGUE.json); original wording and aliases remain in [the source inventory](sources/ORIGINAL_DOCUMENT_CATALOGUE_2026-10-03.json).

## Current usable flow — prioritize these independently

| Family | Needed behavior | Format |
|---|---|---|
| Customer Register | Customer master and contacts refresh one Sales workbook | Existing records → genuine synced XLSX |
| Enquiries & Opportunities | One linked queue, owner, next action and review status | Software records |
| Master Specification / SOR | Customer inputs captured once with immutable source/revision | Versioned fields + editable DOCX rendition |
| Feasibility / contract review | Selected department/person reviews, evidence, conditions and notifications | Review records + DOCX rendition |
| Confirmed PRS / project start | Approved pinned baseline and explicit authorized project creation | Baseline record + DOCX |

NDA is required only when the configured customer/program calls for it. Quotation, sourcing, development, testing and production documents follow their applicable stage. Missing private DOCX/XLSX contracts block those saves; they do not make the entire catalogue a prerequisite for unrelated working features.

## Common pack and the four Drive groups

Each of the **eight existing departments** maintains its own SOP, authority/roles matrix, KPI definitions and applicable blank templates/work instructions. Reuse controlled revisions; do not generate a new common pack for every project. Engineering disciplines remain workstreams.

- **Common documents:** approved standards, policies, templates and definitions.
- **Internal projects / Client projects:** actual applicable project records/files, linked to the same source and revision.
- **Other department work:** customer/supplier/personnel registers, recurring reviews, tickets and non-project operational work.

Periodic reviews are record types, not another top-level folder. PPAP is a conditional type; Starred is a shortcut. Existing protected folder mapping is preserved until a reviewed change; this catalogue does not move files.

## Department catalogue

All entries below are target/reference families. Actual readiness comes from saved records, file bytes and accepted contracts. Review frequency, owner assignments and requiredness are configured; source headings do not enforce them.

### Each department

| Document / record family | Format | Use / applicability |
|---|---|---|
| Common operating pack: SOPs, authority matrix and work instructions | DOCX / approved references | Maintain one controlled pack per department/workstream; reuse its revision across projects. Includes engineering/SDLC/CI standards, FIFO and nonconformance procedures. |

### Sales

| Document / record family | Format | Use / applicability |
|---|---|---|
| Customer Register and contacts | Software records → synced XLSX | One managed Customer Register.xlsx from Customer master; refresh additions/changes, retain revisions. Not one file per customer and not external Excel import. |
| Enquiries & Opportunities register / pipeline reviews | Software records / review log | One linked queue and stage/owner/review tracking; pipeline review uses the same records rather than duplicate forms. |
| Master Specification / customer inputs / SOR | Versioned fields + DOCX | Capture known requirements once, preserve source/customer/revision, reuse in feasibility and project start. SOR is a rendition, not another source of truth. |
| Feasibility / contract review | Assigned review records + DOCX | Selected departments record scope, owner, due date, evidence, decision and conditions; one consolidated review links the contributions. |
| Quotation / commercial proposal | DOCX / commercial records | When an opportunity requires a commercial offer; scoped Finance input, explicit issuance and version history. |

### Hardware / R&D

| Document / record family | Format | Use / applicability |
|---|---|---|
| PRS / confirmed requirement baseline | Versioned baseline + DOCX | After required feasibility/confirmation, pin the exact approved requirements for explicit project start and engineering. |
| Architecture / block diagram / HSI | Design files / specification | Applicable engineering scope; architecture and HSI remain distinct linked subtypes and exact source revisions. |
| Design and release file package | Native CAD / schematic / PCB / ZIP | Engineer-provided schematic, Gerber/fabrication, enclosure/STEP and drawing/tooling files. ERP links real artifacts and checksums; it does not generate CAD. |
| Engineering BOM / cost tracker | Authoritative BOM + workbook rendition | Saved tentative/final BOM; Procurement reviews the same pinned parts/revision. Exports do not create duplicate BOM authorities or stock movements. |
| DFMEA | Structured ratings/actions + DOCX | When design risk analysis is applicable; ratings, actions and closure come from actual engineers/reviewers. |
| POC / design verification / DVP&R | Test records + evidence / DOCX | At applicable POC/validation stages; separate plan and measured-result subtypes, linked source/firmware/sample revisions. |
| Design change / ECO / ECN review | Change register + evidence | On a change or failed review; preserve previous decisions and record impact/effectivity. Stage/ECO audits read this history. |
| Software quality / security / performance review | Review records | Only firmware/software/cloud scopes that need these reviews; frequency is configured, not imposed on every project. |
| DRC / component-library review | Review records | When hardware/library review is due or change-triggered; reference actual rules and evidence. |

### Procurement

| Document / record family | Format | Use / applicability |
|---|---|---|
| Supplier qualification / ASL / ACML / performance and capacity | Supplier registers + review evidence | One supplier history with evaluation, on-site/system reviews, approved lists, scorecards/capacity/lead-time observations. No duplicate workbook per review title. |
| Supplier PPAP / submission warrant | Checklist + supplier evidence | Only applicable customer/product/supplier programs; a document-type/project category, never a fifth department Drive group. |

### Production

| Document / record family | Format | Use / applicability |
|---|---|---|
| Tooling condition / custody / mold maintenance review | Asset/tool review records | Production maintains process tools; Engineering supplies design evidence; Facility handles custody where authorized. |
| Calibration / MSA / expiration review | Instrument register + evidence | Applicable instruments/gages/processes; Operations quality audit links the same authorized calibration evidence. |
| Line capacity / startup / process flow | Readiness records / PFD | When preparing an actual build/line; use recorded capacity and readiness, retain separate process-flow subtype. |
| PFMEA / control plan | Distinct structured templates / DOCX | Applicable manufacturing process; PFMEA and control plan retain their own fields/decisions and cross-references. |
| EOL / FQC / PDI | Measured unit records + DOCX | For actual build/dispatch units; serial, firmware, test/inspector evidence and explicit disposition, never generated passes. |
| 5S / OEE / yield / scrap / defects / KPI reviews | Operational registers + calculated views | When production observations/reviews exist; use defined formulas/time windows. Standards/templates are Common; completed reviews are Other work. |
| Process-equipment PM / downtime / OEE | Maintenance and performance records | For applicable production equipment and actual maintenance/observations; Facility supports infrastructure separately. |

### Operations

| Document / record family | Format | Use / applicability |
|---|---|---|
| NCR / 8D / CAPA / lessons learned | Linked case and action records | When nonconformance or learning occurs; originating departments retain evidence and Operations coordinates the case. |
| Linked risk registers / project risk matrix | Scoped risk records | Combine repeated enterprise-risk titles into one index, with separate authorized strategic, financial, infrastructure/security and project scopes. No blanket shared confidential register. |
| Certification / statutory applicability and validity evidence | Reference / actual external evidence | Only when applicability and real evidence are confirmed. ISO/IATF/licenses/consents/NOC references are not automatically mandatory templates or claimed certificates. |
| APQP / internal audits / governance / management review | Assigned checklist/review records | Applicable program/governance reviews; one schedule/history links scope, customer feedback, risks and decisions across eight existing departments. |
| DMAIC / improvement charter and tollgate evidence | Improvement project records | Only approved improvement work; real sign-offs/evidence, not a compulsory document for every client project. |
| Cross-department KPI definitions / dashboard | Definitions + authorized aggregate views | Reuse measured records and the reviewed formula from each department, not a second manually copied enterprise tracker. |

### Operations / Legal

| Document / record family | Format | Use / applicability |
|---|---|---|
| NDA and confidential agreement | DOCX + actual agreement evidence | Only when required by the customer/program. Template belongs to Legal/Common; executed agreement is scoped to its case/project. Sales initiates/links, without Legal access. |

### Finance

| Document / record family | Format | Use / applicability |
|---|---|---|
| Receivables / MIS / financial KPI / closing / billing | Financial records + XLSX/DOCX renditions | Use Finance-owned records; Sales sees permitted commercial context. Tax invoice is a separate authorized rendition. IT tickets from the combined source note stay outside Finance records. |

### HR

| Document / record family | Format | Use / applicability |
|---|---|---|
| Skill matrix / TNI / training / manpower and workforce reviews | Restricted HR records + matrix rendition | Recorded competence/training/assignment; corporate scope unless project-linked work is needed. License governance is linked to Operations, not another HR workbook. |
| Onboarding / BGV | Restricted policy and case records | When an authorized onboarding/verification case exists; policy is Common, personnel evidence remains restricted. |
| Grievance / employee query | Restricted case register | Only actual authorized employee cases; not a generally shared project document. |

### Facility / Maintenance

| Document / record family | Format | Use / applicability |
|---|---|---|
| Utilities / DG / electricity and water | Facility records + evidence | Actual utilities/assets/consumption/maintenance, with scoped Finance payment review; unknown source shorthand requires field configuration. |
| IT backup / security review / project IT tickets | Authorized IT records | Infrastructure work only; privileged configuration remains administrator-controlled. Split project IT tickets from financial billing in the source note. |
| Facility/security service / waste disposal / pest control | Contracts, service and disposal evidence | Applicable services/assets/schedules; actual agreements/qualified disposal evidence and private commercial terms. Short reminders are work tasks, not templates. |

## Avoid duplicate documents and unnecessary work

Software registers, reviews, tasks, notifications, PR/RFQ/PO/GRN, work orders, releases and change cases remain authoritative software records. Create a file only for a useful controlled output or export. A reminder, dashboard, source note or certification reference is not automatically a new DOCX template.

Merged families preserve their meaningful subtypes: PRS and HSI; schematic/PCB/mechanical files; DFMEA and PFMEA; control plan and PDI; individual review contributions and the consolidated decision. Grouping never merges private Finance/IT/HR/Legal contents or overwrites revisions.

Legacy HLPL/SSM codes are source aliases, not instructions to renumber records. Official IDs come from the server. Certification/standards/license references stay conditional and unverified until real applicable evidence exists.

The web master plan already defines pilot sourcing, release/production/dispatch, change loops, audit and backend handoff. This catalogue does not repeat delivery packs or create another approval checklist. Evidence belongs in `docs/evidence`; technical contracts remain separate. Android builds are governed by their own plan.

Source coverage checked: **89 of 89 unique annexure blocks mapped**. Two added families reflect later human clarification. Original source data and dated backups are retained. No live records, grants, policies, templates or storage paths changed by this optimization.
