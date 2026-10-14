# SSM One — web portal master plan

Last refined: 14 October 2026. **Single current requirements and delivery roadmap.**

Repository entry point: `docs/planning/SSM_ONE_WEB_PORTAL_MASTER_PLAN.md`. `C:/Users/Admin/AndroidStudioProjects/SSMOneWeb` is the full Git repository root, containing application code and this single tracked docs folder. Normal Git pull/add/commit/push includes the documentation; no separate copy or mirror step is required. Historical backups live outside the active repository in sibling `SSMOneWebBackups`. Pending backend work remains pending.

This plan consolidates the company framework, lifecycle, departmental Drive, Sales refinements, editable documents, registers, Legal/directory follow-on and web-to-mobile backend handoff. Android implementation/build planning is explicitly excluded. Update this file in place; do not create a new dated plan for each clarification. Implementation status is evidence-qualified below, not a statement that the whole target is live.


## Plan boundary

This file plans the **Lovable web portal and its authoritative backend only**. It may define and export web-to-mobile integration contracts, but it does not own Android screens, mobile offline implementation, mobile build stages, APKs or emulator/device acceptance.

The separate `SSMApplication3/docs/planning/SSM_ONE_ANDROID_BUILD_PLAN.md` lives in the Android repository. Evidence generated or imported for this web source belongs in `docs/evidence/`; Android implementation evidence remains in `SSMApplication3/docs/evidence/`. Source snapshots retain their original layout for recovery and are not reorganized.

## 1. Authority and how to use this plan

The target is the original Lovable project `d758dbf2-2f0e-44b3-b149-1ec51def58eb`, managed backend `yyrvduosyyaluifqvwkr`, and its Android client. Web/Supabase owns identities, permissions, business records, official numbering, transactions, audit, automation and private storage. Android consumes that authority and owns mobile UI/device integration/cache/drafts.

Latest human refinements incorporated here supersede conflicting dated planning assumptions. AGENTS.md and current verified backend contracts govern implementation. A requirement, draft SQL, generated file, disabled control or admin-only demo is not a completed feature. If a verified contract differs from this target, report the gap and change only the supported operation.

Only two business-planning references are needed for normal use:

1. **This plan:** flow, navigation, ownership, delivery sequence and current gaps.
2. [Optimized document catalogue](SSM_ONE_DOCUMENT_CATALOGUE.md): 38 practical document/record families, mapped to all 89 original source blocks. It separates software registers, generated documents, native artifacts and conditional evidence; it is a reference, not an additional delivery queue or a prerequisite to build every listed item.

Keep `docs/backend-handoff/`, migrations and `docs/evidence/` separate: they describe exact callable contracts and verification. Superseded plans have been removed after consolidation; original source extraction and dated implementation evidence retain traceability.

## 2. One portal, eight departments

All employees see permitted department work, project context, tasks, documents and notifications through the same records. Department switching changes presentation, never impersonates another employee or grants access.

| Existing department | Main work and ownership |
|---|---|
| Sales | Customers, enquiries/opportunities, requirement intake, feasibility coordination, quotations, orders and customer service/handover |
| Hardware / R&D | Hardware, firmware, application/software and mechanical workstreams; specifications, design, BOM, DFMEA, validation and technical changes |
| Procurement | Suppliers, pilot/series sourcing, PR/RFQ/PO/ASN, Stores, receiving, IQC and controlled material transactions |
| Production | Planning/kitting, SMT/PCBA, programming/assembly, EOL/PDI, traceability, packaging/dispatch and process calibration |
| Operations | QMS, audits, CAPA, risks, KPI, management review, cross-team coordination and initially Legal documents/letterheads |
| Facility / Maintenance | Infrastructure/assets, maintenance, electrical/utilities, gate/security, tooling custody and scoped IT support |
| HR | Employees, applicants/shortlists/interviews, onboarding, policy, training and competence; restricted personnel cases |
| Finance | Terms/budgets, matching, invoices, expenses/payment review, aging and authorized reporting |

System controls is the existing privileged configuration area, not a ninth department. Workstreams and quality functions do not create departments or permissions. Members contribute assigned work; specialists maintain permitted drafts; leads assign/review their scope; authorized managers decide their gates. These are responsibility mappings, not new role grants.

Quality remains distributed between engineering/design, supplier/IQC, production/EOL/calibration and Operations/QMS. Security staff do not receive every Facility record; project participation does not expose restricted HR, Finance, Legal or other department documents.

## 3. Portal navigation and compact work views

Each department has an overview, its main operational queues, linked projects, Drive/registers and permitted settings. Overview summarizes real work rather than presenting every workflow action as a separate button. Rows open useful details with context and a clear next step; advanced actions stay inside details.

The web portal uses compact, permission-scoped navigation and responsive queues. Search filters authorized department/project/type/status/owner/revision; deep links reauthorize their target. Android navigation and device implementation are owned by its separate build plan.

### Sales overview

Compact grid cards show total customers, active opportunities, ongoing enquiries, actual active client projects, deployed devices, open customer tickets and overdue Sales tasks where verified data exists. Opportunity counts and actual project counts stay separate. Missing device/count contracts show **Not recorded / unavailable**, not invented zeros.

Three concise columns summarize:

- Ongoing enquiries/opportunities: stage, next action, owner, due/blocker and review progress.
- Customer tickets/issues: customer/project, assignee, status and overdue actions.
- Sales team tasks under the lead: who is doing what, project/customer link, due date and blocker.

One primary **New enquiry** action; no separate overview buttons for every NDA, requirement, assignment or reviewer step. Customers, Customer service, Commercial records and Client documents remain useful linked pages.

## 4. Enquiries and opportunities — one Sales flow

One left-menu item: **Enquiries & Opportunities**. One compact list, active opportunities first, then pending enquiries; one New enquiry button, search and concise status filters. Do not introduce competing enquiry/opportunity creation screens.

| Step | User action | Persisted result / boundary |
|---|---|---|
| New enquiry | Select existing customer, or Add customer inline in the same popup/sidebar; enter requirement and known context | Server-numbered enquiry linked to Customer master; customer creation updates the same customer records |
| Internal Sales review | Open saved enquiry, discuss/clarify, assign permitted Sales owner and next action | Remains enquiry until explicit pursuit/handover decision; no automatic department broadcast |
| Send for feasibility | Select applicable departments, responsible reviewers and due dates, then send saved requirement | Protected action creates/reuses linked opportunity, pins controlled requirement/Master revision, assigns reviews and records notification intents together |
| Department review | Assigned staff assess their scope, evidence, risks, questions, estimates and conditions | Persisted pending/in-progress/returned/completed decisions as supported by verified states; department/person/due/verdict visible to authorized Sales users |
| Consolidated decision | Authorized lead checks required reviews and unresolved conditions | Missing/rejected/stale evidence holds the gate; a document count is not approval |
| Start actual project | Explicit authorized conversion after required feasibility, confirmation/baseline and other configured prerequisites | One linked project and Drive root, preserving original enquiry/opportunity/customer, pinned Master and review history |

Ordinary file sharing is not conversion. Sending for feasibility is the explicit conversion point from enquiry to opportunity. Feasibility completion enables a controlled project-start decision; it must not silently approve a project, commercial commitment or release. Detailed downstream engineering POC/testing remains part of the project cycle, distinct from the initial feasibility review.

Opportunity detail uses **Overview / Customer inputs / Feasibility / History**. Customer identity and Master Specification remain accessible before project creation. The proposed workspace must not masquerade as a committed project. Master inputs include name, customer/internal owner, application, product family, development scope/workstreams, summary, power/units, interfaces, connectivity/GNSS, environment/enclosure, volumes, schedule, requested standards and exclusions. Unknowns remain explicit.

Edits use verified revision/conflict contracts, preserve manual values/history and identify what changed. Customer-master editing and Master-spec editing are separate authorities even when visible together. Notify affected assigned teams through the existing protected event path; do not claim notification if that path is absent.

List columns/cards show customer/code, subject, status/stage, owner, feasibility departments/review counts and next action. **Active** means open opportunity, not feasibility started. Show **Not sent for feasibility / No assigned team** when true. Wrap long labels, bound grid cells and contain any table scrolling; no content extending beyond the page/dialog.

### Consolidated departmental feasibility and shared analysis

**Agreed target; implementation pending.** Provide one shared Feasibility review within the existing opportunity detail, consolidating customer requirements and the analysis of all participating departments. Sales, the authorized opportunity coordinator/Operations representative and the assigned participating department leads/reviewers see the same current permitted technical comparison and discussion. Hardware, firmware, software, mechanical, Procurement, Production and Quality contribute as applicable through the existing departments/workstreams; do not create additional departments or a second opportunity workflow. Visibility is scoped to the opportunity's authorized participants, not every employee or every department globally.

Use a compact requirement-by-department comparison: each customer/Master requirement has a stable reference, exact source revision, requested value/unit/acceptance condition where known, and a short response from each applicable discipline. Proposed presentation choices include Supported, Conditional, Not supported and Needs clarification; these are target UX labels, not assertions about deployed database enums. Each contribution captures proposed capability, assumptions, constraints, dependencies, evidence revision, assigned contributor, review status and last change. Show pending contributions explicitly. Department review completion and feasibility disposition are separate concepts.

Keep customer requirements, department proposals and the final agreed disposition distinct. Each team edits its own authorized contribution; permitted participants can read other shared technical responses and discuss a requirement in its linked thread. Use a single authoritative set of contributions, surfaced in Sales and department workspaces rather than copied into separate forms. Restrict private commercial/Finance, Legal, HR and other confidential attachments under their existing rules; shared technical comparison does not grant blanket document access.

Each department column ends with a prominent **Department remarks / Key highlights** area: the main concise summary of that department's assumptions, concerns, dependencies, questions and recommendations for other teams and the client. Keep it visible as a highlighted footer; on narrow screens show it at the end of the department card. Show author, last saved time and the applicable source/analysis revision; allow links to specific requirement rows. An empty area states No remarks yet rather than inventing a conclusion. Each authorized department contributor edits their own remarks; other permitted teams can read and discuss them. Remarks inform requirement refinement and human decisions but never automatically change the customer's approved baseline or constitute approval.

Provide a clearly labelled **Client-visible highlight** for each participating department in the shared client analysis view, so the client can understand the relevant department's points and reply through linked questions/discussion. Keep optional Internal notes separately marked and scoped; do not expose internal costing, supplier negotiations, private staff discussion or restricted attachments through the public highlight. Before explicitly sharing/saving a client-visible highlight through an accepted publication contract, make its audience clear in the editor and show which revision the client can see. Reuse the same authoritative, versioned remarks rather than independently editable client copies. Access remains limited to that authorized client's opportunity/project and permitted participants. Saved highlight changes use the verified notification/audit path; view access, remarks and client replies do not imply engineering release or acceptance. This is planned behavior, not evidence that a client publication or notification contract is installed.

Show a concise overall summary of participating departments, outstanding reviews, unresolved conditions and conflicts. Expand a requirement to see all department points, linked evidence and discussion; on narrow screens use stacked department responses or contained horizontal scrolling. Keep the existing compact opportunity view and avoid overflowing tables, unrelated creation buttons or a separate general chat application.

For each conflict or clarification, retain the affected requirement and contributions, named issue owner, proposed resolution, due date, discussion and the authorized recorded decision. Do not overwrite earlier contributions or silently merge competing values. Changes notify affected authorized participants through a verified durable event path and retain audit history. A revised customer/Master source marks affected reviews stale for scoped reconfirmation instead of carrying old approval forward automatically. The accepted baseline preserves the exact reviewed inputs, agreed resolution and applicable sign-offs when the opportunity becomes a project; discussion alone does not create a project.

Provide deterministic checks for explicitly structured comparable fields: normalized units/ranges, interface or connector compatibility, contradictory selected responses, incompatible dependencies and schedule/lead-time constraints where the necessary values are known. Flag potential mismatches for human resolution; missing or unconfirmed values remain unknown. Structured rules cannot detect every engineering conflict or interpret every free-text claim. No AI is required for this workflow; do not send customer/design information to an AI provider or let AI merge authoritative requirements or approve feasibility as part of this agreed scope.

Required unresolved conflicts, stale required reviews and outstanding blocking conditions hold the project-start gate. Applicable assigned human reviewers resolve issues and provide required sign-offs; unnecessary all-department unanimity is not imposed. The authorized lead then records the consolidated disposition, followed by the existing explicit project-start action and its other prerequisites. Inspect actual review, discussion, issue, actor-scope, revision, audit and notification contracts before implementation; absent shared-analysis operations remain explicit backend gaps, not client-side approval or invented APIs.

### Minimal approved-requirements change flow

**Agreed initial UX; implementation pending.** Keep the shared analysis simple: a compact read-only Approved requirements summary at the top, followed by departmental review/discussion below. The summary is the exact approved Master Specification revision and its main project parameters, not the separate customer identity/contact master. Before baseline approval, label it Draft requirements rather than implying approval. Show Latest client input and any pending review separately from the last approved revision.

Use the simple **read-only → Edit → Save / Cancel** interaction for authorized client/Sales input. Editing opens only by deliberate action; typing never autosaves. Save is the explicit submission action: no additional confirmation popup, separately named Request change step or separate change-management dashboard is required for ordinary input edits. Show changed values in the same form and preserve the old version. A committed save creates a new source-linked client-input revision and immediately records notification intents for all authorized participating teams through the verified durable event path. Label it Client requirements updated or Requirements updated according to the actual actor; preserve both the client requester and Sales recording actor when Sales enters a client request. Never misattribute a Sales-originated change to the client.

Notification does not approve or overwrite the existing approved baseline. Sales coordinates any required affected technical reviews in the same workspace; the authorized reviewed result becomes a new immutable Master baseline revision. Preserve previous revisions, changed values, requester/actor and decisions, mark affected reviews stale and hold required conflict/prerequisite gates until resolved. Show the reviewed version and latest client input distinctly without an extra complex workflow screen. Send a separate concise notification when a new baseline is approved. Server-side contracts enforce authorization, revision/conflict checks and immutable history; the read-only UI alone is insufficient. Absent operations remain pending, not client-side status updates. No AI or new external notification provider is required for this initial scope.

## 5. Connected project cycle

The same Master/source baseline continues from pre-project intake into the project. Every applicable stage records assigned individuals, due dates, blockers, exact evidence revisions and authorized decisions. Product family proposes defaults; it does not inject certified technical values or approvals. Hardware-only scope does not create mandatory software work. Exclusions require a reason and the applicable reviewer decision.

| Macro stage | Main work and exit evidence |
|---|---|
| 1. Intake | Customer/enquiry, draft Master/SOR, clarification, scoped client input and applicable NDA evidence |
| 2. Feasibility / contract review | Applicable engineering, Procurement, Production/quality and Finance contributions; assigned decisions, risks/conditions and consolidated disposition |
| 3. Baseline / commercial confirmation | Exact client-confirmed requirement/PRS revision, scope/interfaces/acceptance criteria, quotation/order or PO/LOI and terms where applicable; protected project-start prerequisites |
| 4. Research / POC, where applicable | Investigate uncertain assumptions; modules/demonstrator where needed, shared phase analysis and actual test/client-review evidence; record an authorized justified bypass for proven designs |
| 5. Pilot | Tentative electronic/mechanical BOM, PCB/stencil/casing, pilot sourcing/build, bring-up, jig/test plan and inspection evidence |
| 6. Validation / pre-compliance | DVP/DVR, measured results, lab sourcing/reports, client prototype/field feedback and failure dispositions |
| 7. Final design / release | Exact approved BOM/Gerber/drawing/HSI/firmware/tool/test revisions and checksummed release manifest |
| 8. Order / supply / production readiness | Terms/order, supplier qualification/PPAP, capacity/forecast/lead times, materials/IQC, tools and calibration |
| 9. Production / dispatch / service | Authorized WO/routes/material operations, serial/lot genealogy, programming/EOL/PDI, packaging/dispatch/invoice, customer service and change feedback |

HW_01–HW_37 and SDLC gates map as substages, not another workflow engine. Initial feasibility enables project initiation; final baseline, development and release approvals remain distinct. The nine stages describe the complete business flow, including its pre-project stages.

Four change loops remain: customer scope amendment; mechanical/design ECO; failed-test NCR/RCA/ECN/retest; and post-release change/obsolescence. Each pins old/new source, impact/cost/timing, affected orders/WIP/lots/serials and approved effectivity. Preserve old releases and decisions; no automatic CAD/machine/stock changes from a note.

### Optional Research / POC and parallel pilot analysis

**Agreed target; implementation pending.** After explicit project start, retain the same requirement/Master history, shared analysis and departmental highlights throughout development. Hardware proposes the appropriate technical path: use an optional Research / POC phase for unresolved assumptions, with investigation and, where needed, ready-made modules/boards or a demonstrator. Research does not always require a physical prototype. For a justified proven/reused design, the authorized applicable reviewers may record why POC is not needed and proceed directly to pilot after the relevant prerequisites; do not fabricate a passed POC or silently skip a required gate.

Before research starts, show the client the agreed research objective, uncertainties, assumptions, expected outputs, scope, cost/timeline where agreed, and the decision point for continuation/rework/stop. The client understands that findings may change and gives recorded agreement to the applicable terms. Findings do not silently alter approved requirements, price or schedule. Maintain a simple client view with the approved requirements, published progress/department highlights, open questions and Your input needed. Internal analysis and the client view use one source-linked workspace with scoped publication; internal costing, supplier/private discussions and restricted files remain private. Client questions/answers link to exact requirements/revisions and notify affected authorized teams. Invitations remain scoped, expiring/revocable under accepted contracts.

During Research / POC, Hardware's proposed key parts/modules are visible promptly as clearly labelled draft candidates to assigned Firmware/software and Procurement reviewers. Firmware assesses MCU/toolchain, interfaces, drivers and implementation feasibility; Procurement assesses per-item cost, availability, lead time and sourcing constraints. Mechanical, Production, Quality and Service/installation workstreams contribute where relevant, including Service input during initial feasibility when installation/support affects scope. Keep these contributions in the same shared analysis; no new department identities or broad document grants are inferred.

Retain distinct linked snapshots for initial feasibility, Research/POC analysis and post-test updated feasibility. Test evidence and applicable client validation inform the next analysis revision. Sales reviews client scope/commercial continuation with the required technical reviewers before pilot proceeds. The project is not recreated at pilot; source-linked PRS and other applicable template drafts may be prepared from the approved known requirement baseline, with missing fields explicit and human review/release separate from drafting.

During pilot, develop the custom PCB/design and distinct electronic and mechanical tentative BOMs linked to the same project/variant. Firmware receives the relevant electronic candidates and affected interfaces; Procurement reviews both electronic and mechanical BOMs. Mechanical interfaces affecting Firmware remain shareable as needed rather than hiding all mechanical information categorically. Preserve clearly labelled POC purchases/build configuration separately from pilot and final production configurations; a draft candidate or cost review is not a released production BOM or PO/stock action.

Avoid circular completion dependencies by separating **Ready for cross-team review** from **Approved BOM baseline locked**. Hardware/Mechanical submit a stable, numbered review snapshot before final BOM lock; Firmware and Procurement can complete their phase-scoped compatibility/cost/sourcing reviews against that exact snapshot. Hardware cannot claim final BOM lock until required Firmware, Procurement and other applicable technical decisions are complete. Procurement can finish its review of that submitted revision before lock, but cannot claim final released purchasing readiness until the approved BOM baseline is locked and the purchasing prerequisites are met. Procurement approval alone is not engineering approval. A component/BOM revision change invalidates the affected earlier review decisions for scoped reconfirmation. Authoritative statuses, numbering, review locks, operational effects and access must use inspected protected backend contracts; these presentation checkpoints do not invent deployed enums or RPCs.

### Shared PCB/design records and customer product variants

**Agreed target; implementation pending.** A project manages customer requirements, scope, people, tasks, commercial commitments and delivery. A PCB/design record manages the reusable circuit/layout, fabrication specifications, technical files and controlled revisions. A product variant identifies a specific approved configuration of PCB revision, assembly/BOM revision and, where applicable, connector, firmware, enclosure and test requirements. These are linked records, not interchangeable identities: one PCB design may serve multiple projects/customers, and one project may contain several PCBs.

Maintain one authoritative shared PCB/design record owned by Hardware / R&D. Project and department views link to its exact permitted revisions instead of duplicating designs or files. Each customer project's requirement and product-variant baseline stays separately controlled. Release and operational references pin an exact approved variant, PCB revision, BOM/assembly revision and applicable firmware/test revisions; never resolve production requirements through an unpinned latest-design link. Official identifiers and business numbering remain server-owned under inspected contracts.

| Department | Target access and responsibility |
|---|---|
| Hardware / R&D | Create and revise designs, specifications and variant BOM/assembly definitions within authorized engineering scope; manage engineering review/release through accepted contracts. Released revisions remain immutable. |
| Purchase / Procurement | Read authorized approved fabrication specifications, relevant technical files and exact BOM/revision references; own supplier, quotation, availability, lead-time and purchasing records. Engineering changes return for review rather than directly altering the released design. |
| Production | Read the exact released PCB/variant, BOM, assembly/work instructions and applicable test requirements for assigned work; record actual build, inspection and traceability results. Engineering revisions require the controlled change path. |

Department membership alone does not grant every design or private file. Inspect existing backend/RLS and file-delivery contracts before implementing shared reads. Preserve customer confidentiality, design/IP ownership restrictions and existing assigned-person document rules. Do not broaden grants, infer ownership from folders, or copy confidential customer requirements into another client's view.

Example: Client A uses PCB-A revision 3, variant A with connector X. Client B's new enquiry selects the target action "Variant of existing product", links the permitted base design/product and captures connector Y plus customer requirements. Hardware assesses footprint/pinout, electrical ratings, enclosure fit and assembly/test impact; Procurement reviews availability/cost/lead time; Production/Quality review buildability and the required verification. Sales records the customer's agreed specification before release. A variant request is not automatic approval or project creation.

| Assessed change | Controlled result |
|---|---|
| Existing PCB supports the new fitted connector | Retain the PCB revision; create the distinct variant BOM/assembly specification and required verification. |
| Footprint, routing or circuit must change | Create a controlled PCB/design revision or linked derivative design where identity/ownership rules require it, plus the variant BOM and affected verification. Do not overwrite the original release. |
| Only the external cable/adapter changes | Keep the PCB unchanged; control the cable/adapter or assembly variant and its applicable checks. |

Orders, purchasing lines and production batches must identify the exact approved configuration, with effectivity and substitution/change rules where applicable, so customer connector variants cannot be mixed. Preserve Client A's released configuration and historical orders/builds when Client B's variant is introduced. Apply feasibility and testing proportional to the actual change and required approvals; do not force a complete new development cycle for every connector change, or bypass required engineering/quality checks because the base PCB is reused.

Implementation requires inspection of existing project, product/design, BOM, revision, release and operational-reference contracts first. Reuse supported authoritative records; any missing PCB/variant linkage, scoped access or revision/effectivity contract is an explicit backend gap, not an invented table, RPC or deployed feature.

## 6. Symmetrical departmental Drive and work registers

Every department uses the same **four group folders/views**:

```text
[Department]
├── 01 Common documents        SOP, KPI definitions, authority matrix, policies/templates
├── 02 Internal projects       authorized links to internal project workspaces
├── 03 Client projects         authorized links to client project workspaces
└── 04 Other department work   registers, recurring/conditional work and non-project records
```

These groups also act as filters on the same authorized Drive records. Add work/document-type filters across all permitted projects, so a department can find all matching files without opening projects individually. Periodic reviews are work types within the four groups, not a fifth root. **PPAP** is a relevant project/work-type category/filter, not an extra top-level group. **Starred** is a favorites shortcut, not a department group.

Project workspaces link governance, requirements, Hardware, firmware/software, Mechanical, validation, Procurement/IQC, Production/calibration, Operations/handover and service/archive revisions as applicable. Project, department, stage, task and search point to the same Drive node/revision; do not duplicate file authorities or infer ownership from names.

Keep important operational registers in departmental Drive in business sequence. Sales sequence: **Customer → Enquiry → Opportunity/proposal → Quotation/contract → Orders/handover**. Missing read/export contracts produce precise unavailable states, not dead links to unrelated creation forms. Other departments follow their verified operational order: sourcing/receiving/stock; production/test/dispatch; maintenance/calibration; HR/training; Finance/matching; QMS/audit/CAPA.

### Customer Register.xlsx

Create one managed **Customer Register.xlsx** containing all authorized fields shown in Customer master, with linked contact rows/sheets where necessary. Customer additions/changes refresh it automatically from authoritative software records; stable IDs prevent duplicate rows. Store it in Sales Drive with last-sync/source/version metadata and revision history. Users can access/download and explicitly share permitted copies.

This new managed register does **not** require an old workbook upload. Importing or synchronizing edits from a previous external Excel is a separate future operation requiring inspected columns/mapping/conflict rules. Backend records remain authoritative; an exported workbook alone is not automatic synchronization. Prefer genuine XLSX; CSV is only an explicitly labelled fallback. Keep text/formula-injection handling and typed values correct.

## 7. Controlled documents and native editable output

All twelve specialized templates require structured editing, native DOCX export and actual private DOCX save to the authorized department/project Drive category. Keep specialized tables, source/template/schema pins, conflict checks, immutable historical revisions, manual-edit preservation and separate human review/release. External Word reimport must state supported round-trip limits.

| Template | Initial ownership / specialized content |
|---|---|
| SOR | Sales: customer/platform, requirement, volumes, interfaces, service/warranty and delivery |
| NDA | Operations/Legal: parties, confidentiality/IP/duration, actual review/signature evidence; Sales initiates/links only |
| Quotation | Sales with scoped Finance review: price/volume, currency, NRE, milestones/lead times |
| Contract review | Sales coordination, assigned disciplines: feasibility/risk/estimates/conditions |
| PRS | Assigned engineering: architecture/power/protocol/environment/enclosure/interfaces |
| BOM cost tracker | Engineering source plus scoped Procurement review: component/quantity/MPN/package/source/cost/qualification |
| DFMEA | Engineering: functions/failures/ratings/controls/actions/closure |
| Control plan | Production/quality: process characteristics, sampling/controls/reaction/equipment |
| DVP&R | Assigned engineering/quality: applicable test/profile/criteria/results/evidence |
| PDI | Production: serial/IMEI/MAC, firmware, measured functional results and actual inspector decision |
| Tax invoice | Finance: approved customer/lines/tax/HSN/GST/reference/bank configuration |
| Skill matrix | HR: competency/training/assessment/expiry, corporate scope where appropriate |

Responsibility settings can refine routing through verified contracts. Relevant department scope **and current responsible-person assignment** govern document metadata, editing, history, download and direct links. Project overview membership alone does not confer document access. Reviewer responsibility does not automatically confer edit/material/payment authority.

Generate known typed draft values only. Missing values remain unconfirmed; no invented measurements, signatures, certifications or acceptance. Official numbers/actors/timestamps are server-issued. Used templates are immutable; settings clone/edit/activate/retire through protected operations. Source changes mark drafts stale and offer a proposed diff/new revision, preserving released/manual content.

Historical Sales HTML remains readable under its existing authorization. Never rename HTML to DOCX or overwrite it. File-ready success requires actual byte/checksum/storage receipts; pending rendering is not completion. PDF/print are renditions of pinned revisions. PDF preview, bounded ZIP inspection, spreadsheet table/formula support and supported STL/glTF viewing are separate capabilities; STEP/native CAD requires a verified converter or download/external-viewer fallback.

Tentative BOM entries select existing inventory/component IDs or use the existing new-part request flow. Procurement evaluates availability/cost/sourcing against exact saved BOM revisions. A review/request never deducts stock or automatically issues a PO.

## 8. Responsibilities, notifications and external collaboration

Versioned stage RACI uses existing departments/capabilities and assigned people. Record routing snapshots for active work; changes are audited/reassigned explicitly. A stage gate validates actor, current assignment, required evidence, source revision and unresolved amendments, and commits state/audit/durable notification intents together.

Recipients come from current authorized assignments, not every department member. Inbox shows person/department/due/status and safe deep links. Workers retry with deduplication, delivery receipts and visible failures; realtime triggers refresh and is not the durable ledger. Push/email/webhooks need verified provider configuration and separate delivery evidence. File edits notify affected authorized teams only through supported events.

Client/vendor collaboration uses scoped, expiring/revocable invitations and exact published revisions/actions. Editable intake differs from progress/download/approval. Do not expose internal Drive, other customers/vendors, private costing or HR records. Client confirmation, legal signing, engineering release and Finance approval remain distinct explicit decisions. Uploaded evidence is validated/quarantined as required before release.

## 9. Remaining web portal work and backend handoff

Preserve existing useful screens and controlled stock transactions. Complete department work queues/actions for HR/recruitment/training, Facility/assets/maintenance/security, Finance/matching/aging, Operations/QMS/audit/CAPA and customer service. Recurring work, KPI/OEE/MTBF/MTTR/yield and escalation use reviewed formulas/calendar/timezone/actual events; targets are not achieved values. Audit export is a permitted point-in-time manifest of exact evidence/decisions/missing items, not a certification.

After lifecycle/documents, add Operations **Legal Documents and Letterheads** using existing private Drive records, configurable responsibility and approved versions. Sales links NDA without copying files or gaining Legal access. Add one signed-in company directory through an approved work-contact projection: name, department, designation, manager and work communication details; exclude private phone/HR data. Connect authorized directory/document search to Help/chat/voice, then Android. Calling/messaging employees is an explicit separate user action; external chat/providers are follow-on scope.

Inspect existing employee/profile manager/contact contracts and search/Help/voice/navigation before implementing the directory. Missing contacts or broken reporting hierarchy remain explicit. Legal ownership can later transfer through an authorized configurable responsibility contract without duplicating files or rewriting historical ownership; do not invent a Legal department or grant every Operations employee agreement access. Protect template/letterhead versioning, private agreement history, assigned reviewers and retention. Letterhead availability does not authorize signing or issuing an agreement. Verify signed-in directory access across departments, confidential-field exclusion, absent hierarchy, allowed/denied Legal callers, search/deep-link isolation, reassignment and web/Android parity. Legal/directory work must not delay the active feasibility and document delivery groups.

Web-to-mobile handoff only: after a backend increment is accepted, export its exact fields/enums, payload/response/errors, scopes/RLS, numbering/retry semantics, private file delivery, offline classification and evidence. Keep pending operations explicitly unavailable. Android screens, scanner, native viewers, Room/WorkManager/SyncCoordinator, mobile stage sequencing and APK/device tests belong exclusively to the separate Android build plan (`SSMApplication3/docs/planning/SSM_ONE_ANDROID_BUILD_PLAN.md`).

## 10. One delivery queue and evidence-qualified checkpoint

Status definitions: **Verified** = actual stated evidence; **Reported** = implementation/checks reported but not independently/live verified; **Pending** = required behavior absent/unaccepted; **Approval required** = concrete sensitive deployment action still needs specific authorization. Current summaries carry forward prior dated evidence; this documentation consolidation did not rerun product builds or live authorization tests.

| Order | Bounded group | Latest known boundary / next work |
|---|---|---|
| 1 — current | Feasibility handover and reviewer workflow | Combined Sales list/details/customer/Master reads and truthful no-assignment states were browser-verified. Overflow repair and checks reported, visible updated layout observed. A consolidated requirement-by-department feasibility comparison, prominent departmental remarks/client-visible highlights, scoped shared discussion and human conflict resolution are agreed pending work. Protected source-bound requirement + department/reviewer + durable notification handover remains pending; latest source/form work was dispatched, not accepted live. Finish exact contracts, wiring and checks before any deployment gate |
| 2 | Controlled project start / baseline | Preserve enquiry/opportunity/Master/review source; verify explicit approval conversion, one project/root, retries and history. No verdict-only automatic project creation |
| 3 | Private DOCX and responsibility | Local renderer/export and private historical HTML evidence exist. Five-file DOCX backend package and responsibility extension are pending/source-only; specific access/deployment approval and real restricted callers remain required. Do not treat local export as saved DOCX |
| 4 | Drive/register completion | Four-group/filter source and UI checkpoints exist; verify all departments, PPAP/favorites placement, same revisions and useful register reads. Customer XLSX automatic private storage/refresh is pending, not established by export foundation |
| 5 | POC/pilot and Procurement review | Complete optional Research/POC, parallel phase-scoped Firmware/Procurement review, post-test feasibility and electronic/mechanical tentative BOM review without circular lock dependencies, plus shared R&D-owned PCB/design records and customer product variants with scoped Procurement/Production reads and exact revision links. Procurement source package is pending; preserve inventory/PO boundaries and exact BOM versions |
| 6 | Validation/release/readiness | Real DVP/lab/client decisions, release manifests, effectivity and supply readiness; no fabricated approvals or certifications |
| 7 | Production/dispatch/service | Verified controlled transactions, routes/EOL/PDI/serial genealogy/dispatch and Finance links; actual allowed evidence and failure paths |
| 8 | Company operations and Legal/directory | Department-specific queues, recurring work/audit, scoped Legal/letterheads and work-contact directory; then Help/chat/voice integration |
| 9 | Web integrated acceptance and backend handoff | Verify web/portal/API/private-storage authorization, gates and notifications; publish accepted contract changes and evidence for the separate Android build queue. This row does not schedule mobile implementation or APK/device tests |

Foundational fixes (query errors, Tasks routing, Drive provisioning/history refresh, contract/source integrity) travel with the affected group. Continue independent safe work when one operation is blocked. Do not accumulate changes while compilation errors exist.

For each meaningful group: inspect → implement → compile/typecheck → focused meaningful tests → build → actual web browser/API evidence → update this queue. Reversible UI work gets proportionate checks; authorization, transactions, revision history, retries and concurrency need stronger evidence. Avoid repetitive acceptance loops after successful unchanged checks. Report what users can actually do and the exact missing operation.

Reuse `OPPORTUNITY-2026-0013`, `MASTER-2026-0001` revision 1 and the existing explicitly labelled `ENQUIRY-2026-0001` sample with its existing sample customer. Preserve historical revisions; no duplicate fixtures or new production users. Existing redundant samples require a verified reversible, dependency-aware archive; archive source remains blocked by incomplete dependency/writer coverage. Do not delete them to tidy a demo.

Prepare concrete reviewable source/tests before requesting specific sensitive deployment approval. No destructive database changes, production deletion, permission/RLS weakening or expansion, privileged credential changes, new live users, irreversible migration or Publish/go-live without the required explicit authorization. An uninstalled proposal is never a callable production API.

### Contract integrity and handoff detail retained from earlier plans

Before enabling a proposed generator, template, dependency, feedback or workflow operation, inspect the actual deployed fields/extensions/helpers and every affected writer. Verify authorization before replay, actor/project/payload-bound receipts, null-auth rejection, expected revision, source provenance, correct OLD/NEW container checks, immutable used templates and dependency locking across legacy predecessor/reassignment paths. Reject cycles and cross-project edges under concurrency. Govern clone/edit/activate/retire rather than granting direct writes; authorized historical replay survives retirement. Existing proposal SQL remains unapplied until deployment is evidenced. These controls are targeted backend requirements, not reasons to repeat unrelated UI checks.

Storage and metadata are separate systems: verify actual bytes/checksum and compensation/failure handling before file-ready success. Reauthorize sensitive downloads; a previously issued signed URL can survive invitation revocation until expiry, so use short-lived delivery or an authorization gateway when immediate revocation is required. Bound file size, sanitize rich content, reject unsafe resources/scripts and do not extract ZIP paths unsafely. Private realtime channels require their own authorization. Do not promise exactly-once external delivery.

After each accepted backend increment export current exact contracts to `docs/backend-handoff/`: `MOBILE_BACKEND_CONTRACT.md`, `mobile_backend_contract.json`, `ANDROID_BACKEND_HANDOFF.md`, `BACKEND_GAPS.md`, the web-to-mobile handoff/remediation reports and generated `types.ts`, with supplemental versioned contracts where needed. Include fields/enums, RPC payload/result/errors, scope/file delivery, transaction/retry/offline semantics, applied versus pending state, source/environment and test evidence. Preserve earlier artifacts as historical. Only public Supabase URL/publishable configuration belongs in mobile; no service-role/database/signing/private OAuth secrets.

Implementation ownership: Lovable/web/backend owns shared contracts, authorization/storage, business UI, template/portal/workflow/integration services; Android implementation is separately planned and consumes accepted contracts; authorized business reviewers decide applicability, responsibility, actual evidence and gates. Local files are not automatically visible in Lovable: transfer the current roadmap explicitly before claiming both workspaces share it.

Integrated evidence covers permitted and denied API/storage paths, exact source changes/confirmation, stale and repeated edits/decisions, missing-evidence holds, template/number concurrency, same BOM/file revision across project/Drive/mobile, failed EOL/calibration paths, notification worker retry/reassignment/revocation, web session/account isolation and authorized audit export. Existing FCU/3D or Emulator_V2.0 TCU Test Jig files can be viewer examples where authorized; synthetic readings are labelled. Use approved test scope for any stock operation and verify record/quantity/audit together; ambiguous retry keeps its request key. No incidental machine command, client dispatch, invoice/tax filing or payment is a test step.

### Historical inspection notes retained from the 5 October gap plan

These are dated observations, not current failures or new verification. Reinspect only when relevant: Sales creation UI was missing despite server actions; client requirement submission and department-scoped reviewer saves were not established; Sales handover did not create/link a project; synthetic PROJECT-2026-0001 had no Drive root; design inputs appeared empty after reopening; embedded Tasks had a route-match error; a generated retained R3 draft required reopening history; renderer output was plain TXT with limited metadata substitution; TXT lacked body preview; complete configurable RACI/inbox delivery was unestablished. The isolated admin demo did not prove original-production or restricted-caller acceptance. Current evidence and the delivery queue supersede these observations where repairs are verified.

### Additional retained dependencies from the synced portal roadmap

The portal roadmap captured at Git commit `855c658` contained older overlapping checklists and unique technical dependencies. The overlapping business flow is consolidated above. Checked boxes and old blocked entries are dated source reports, not fresh live acceptance. The following unique work remains within this delivery queue:

| Group | Retained dependency and boundary |
|---|---|
| Sales / feasibility | The latest source includes `20261013_sales_feasibility_handover.sql` and a selection form, but send remains gated. Reuse the accepted assigned-reviewer response path; do not assume the enquiry's deployed table has review fields. Preserve atomic intake/replay, source-bound requirement pairing, Master revision/audit/conflict rules, legitimate legacy revision/approval compatibility and external intake expiry/revocation. Direct-write compatibility and original caller scope require current contract inspection before changing grants. |
| Project gates | Retain the source-only `42P17` stage-gate RLS recursion repair proposal. It preserves administrator, projects.view and same-project employee-membership semantics; no elevated frontend reads. Exact stage-decision authority/state, baseline/amendment applicability, evidence freshness, recipient resolver and immutable decision/outbox contracts remain unverified dependencies. |
| BOM candidate vs Procurement review | These are related but distinct contracts. Candidate submission requires a committed project, approved initiated baseline, completed exact-project handover and authorized active project-manager/team scope. Existing inventory selection remains a read. New-part duplicate matching is explicit, never fuzzy auto-merge. Scoped Purchase costing precedes final Hardware decision; missing volume/ceiling/currency/unit data is unavailable. Sales commercial input is non-approving by default; any approval exception is explicit and rare. No inventory/component promotion, stock/BOM mutation or final decision is inferred from a submission. |
| Official decision log | Preserve the proposed append-only project decision log with short human-authored rationale, server-derived actor/project/source, scoped evidence and linked immutable amendments. No callable approval/status/audit/read contract is assumed from the proposal. |
| Deviations | Submission-only and approval/closure are separate. Pin approved controlled source/evidence, exception/risk/safeguards and active project-manager scope. Proposed technical-authority plus Quality review and customer approval for affected customer requirements remain explicit future gates. A submitted proposal is not an approval; disposable concurrency evidence does not install a managed contract. |
| Responsibility overrides | Persisted project-stage responsibility and document-category reassignment are distinct pending contracts. Preserve existing stage/task/owner/reviewer/history/template records; validate expected revision, null actor/target, current scope and revocation-after-wait. Local responsibility/task-preparation previews do not create operational work or notifications. |
| Shared portal / HR | Retain remaining role/permission-catalogue and module-status forms, My Work/approvals/resolver/global search/activity details, HR assessments, digital ID, welcome-kit fulfilment, employee self-service and manager leave approval. Existing interview/offer/onboarding reports are historical, not whole-HR completion. Public Careers/resume/status and employee/reviewer/manager flows need their actual scoped contracts. |
| External integrations | Google Workspace/Drive guarded settings and actions remain connector-dependent. Do not assume Google integration, email/push/webhook, eSignature, tax or jig transport exists from a menu or proposal. |
| Operational data | Historical zero-stock recovery and pending supplier/CSV order review require actual source quantity/bin/order evidence. Missing quantities are not invented; no old roadmap checkbox authorizes fresh production stock/financial actions or new department records. |
| Document and sample integrity | Keep the existing HTML lineage, frozen DOCX review packages and dependency-aware archive block. Authoritative saved-BOM reads may work while a department list excludes an unassigned project; do not infer ownership or backfill a null department. A source-only schema proposal or admin fixture does not cure missing assigned-caller evidence. |

Technical proposals, SQL, acceptance matrices, handoff contracts and implementation reports are deliberately retained in repository `docs/planning`, `docs/evidence`, root interface contracts and `supabase/pending`. Their original exact versions also remain in the local immutable `SSMOneWebBackups/backups/2026-10-14-github-855c658` snapshot. Verification and handoff reports are organized under `docs/evidence/` without upgrading their dated claims. Review uncertain files before any later merge/removal.

## 11. Consolidation and refinement record

This consolidates the October 1 OEM plan, department/role/Drive operating model, October 2 lifecycle workflow, October 3 company plan/Lovable brief, October 5 gap plan and October 11 DOCX/Legal additions. Those eight redundant plan files were removed at the user's request on 14 October 2026 after incorporating their requirements, necessary contract rules and historical inspection boundaries. Backend contracts, original source extraction, catalogue and implementation evidence remain separate and retained; their evidence is not upgraded by consolidation.

Latest decisions now resolved in one place: four symmetrical Drive groups; PPAP as type and Starred as shortcut; compact Sales overview; unified Enquiries & Opportunities; inline customer creation; explicit selected-department feasibility handover; usable customer/Master/review/history detail; controlled project start; managed Customer Register.xlsx without old-workbook prerequisite; native DOCX saves with assigned-person/category scope; Operations/Legal NDA ownership; proportionate validation and visible features first.

Future changes update the relevant section and the delivery queue here. Store dated verification under evidence and exact server interfaces under backend-handoff; avoid new competing plan files. App-side copies and the scheduler must reference this stable plan, preserve paused/running settings and existing approval boundaries.


14 October source cleanup: root roadmap.md was removed after its business flow and unique remaining dependencies were folded into this plan. Original roadmap bytes remain in both dated source backups and Git history. No application source, SQL, authorization, production data or remote repository was changed by this local documentation cleanup.


14 October scope correction: Android implementation/build details moved into SSM_ONE_ANDROID_BUILD_PLAN.md. This file renamed SSM_ONE_WEB_PORTAL_MASTER_PLAN.md; only backend contract handoff remains here. Web verification/checkpoint reports centralized in docs/evidence without changing report bodies or snapshot history.


14 October catalogue optimization: replaced the raw dated annexure dump with SSM_ONE_DOCUMENT_CATALOGUE.md/json; all 89 source blocks remain mapped. NDA defaults to Operations/Legal, four Drive groups replace old three-category assumptions, and records/references are distinguished from actual generated files. Ship the active Sales/feasibility flow independently; do not turn this inventory into a requirement to finish every optional document first.


14 October final workspace refinement: SSMOneWeb itself is the full Git repository root, with application code and docs tracked together. The nested source checkout and sparse-docs workaround were removed. Existing backup captures and the prior workspace metadata are preserved outside the active repository in sibling SSMOneWebBackups. Normal Git operations now synchronize the one docs folder directly. Application code, backend contracts, authorization and production data remain unchanged.

Latest agreed PCB/variant refinement: projects manage customer work; shared R&D-owned PCB/design records and their revisions are separate. Customer variants reuse a permitted base design, with exact BOM/assembly/release references and scoped Procurement/Production access. This is an agreed planning target; no backend records, access grants or release behavior were changed by this plan update.

Latest agreed shared-analysis refinement: participating departments contribute to one requirement-linked opportunity feasibility view with scoped cross-team visibility, discussion, explicit issue ownership, human resolution and deterministic mismatch checks. AI is not required. This is an English planning update only; no application behavior, backend deployment or permissions changed.

Latest agreed collaboration refinement: prominent departmental remarks and client-visible highlights; deliberate Edit plus Save/Cancel without an extra change-request confirmation; optional Research/POC with recorded client terms and phase-linked analysis; and separate review-ready versus finally locked BOM checkpoints. These are English planning refinements only, with no application deployment, permission changes or new department records.
