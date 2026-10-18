# SSMone — web portal master plan

Last refined: 14 October 2026. **Single current requirements and delivery roadmap.**

Repository entry point: `docs/planning/SSM_ONE_WEB_PORTAL_MASTER_PLAN.md`. `C:/Users/Admin/AndroidStudioProjects/SSMone/SSMone-Web` is the full Git repository root, containing application code and this single tracked docs folder. Normal Git pull/add/commit/push includes the documentation; no separate copy or mirror step is required. Historical backups live outside the active repository in sibling `SSMOneWebBackups`. Pending backend work remains pending.

This plan consolidates the company framework, lifecycle, departmental Drive, Sales refinements, editable documents, registers, Legal/directory follow-on and web-to-mobile backend handoff. Android implementation/build planning is explicitly excluded. Update this file in place; do not create a new dated plan for each clarification. Implementation status is evidence-qualified below, not a statement that the whole target is live.


## Plan boundary

This file plans the **Lovable web portal and its authoritative backend only**. It may define and export web-to-mobile integration contracts, but it does not own Android screens, mobile offline implementation, mobile build stages, APKs or emulator/device acceptance.

The separate `SSMone-App/docs/planning/SSM_ONE_ANDROID_BUILD_PLAN.md` lives in the Android repository. Evidence generated or imported for this web source belongs in `docs/evidence/`; Android implementation evidence remains in `SSMone-App/docs/evidence/`. Source snapshots retain their original layout for recovery and are not reorganized.

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

Provide a clearly labelled **Client-visible highlight** for each participating department in the shared client analysis view, so the client can understand the relevant department's points and reply through linked questions/discussion. Keep a separate **Internal remarks � team only** field at each department footer, alongside the **Client-visible highlight** field. Edit each independently with explicit Save/Cancel; never auto-copy internal remarks into client highlights. Keep internal remarks separately marked and scoped; do not expose internal costing, supplier negotiations, private staff discussion or restricted attachments through the public highlight. Before explicitly sharing/saving a client-visible highlight through an accepted publication contract, make its audience clear in the editor and show which revision the client can see. Reuse the same authoritative, versioned remarks rather than independently editable client copies. Access remains limited to that authorized client's opportunity/project and permitted participants. Saved highlight changes use the verified notification/audit path; view access, remarks and client replies do not imply engineering release or acceptance. This is planned behavior, not evidence that a client publication or notification contract is installed.

Show a concise overall summary of participating departments, outstanding reviews, unresolved conditions and conflicts. Expand a requirement to see all department points, linked evidence and discussion; on narrow screens use stacked department responses or contained horizontal scrolling. Keep the existing compact opportunity view and avoid overflowing tables, unrelated creation buttons or a separate general chat application.

For each conflict or clarification, retain the affected requirement and contributions, named issue owner, proposed resolution, due date, discussion and the authorized recorded decision. Do not overwrite earlier contributions or silently merge competing values. Changes notify affected authorized participants through a verified durable event path and retain audit history. A revised customer/Master source marks affected reviews stale for scoped reconfirmation instead of carrying old approval forward automatically. The accepted baseline preserves the exact reviewed inputs, agreed resolution and applicable sign-offs when the opportunity becomes a project; discussion alone does not create a project.

Provide deterministic checks for explicitly structured comparable fields: normalized units/ranges, interface or connector compatibility, contradictory selected responses, incompatible dependencies and schedule/lead-time constraints where the necessary values are known. Flag potential mismatches for human resolution; missing or unconfirmed values remain unknown. Structured rules cannot detect every engineering conflict or interpret every free-text claim. No AI is required for this workflow; do not send customer/design information to an AI provider or let AI merge authoritative requirements or approve feasibility as part of this agreed scope.

Required unresolved conflicts, stale required reviews and outstanding blocking conditions hold the project-start gate. Applicable assigned human reviewers resolve issues and provide required sign-offs; unnecessary all-department unanimity is not imposed. The authorized lead then records the consolidated disposition, followed by the existing explicit project-start action and its other prerequisites. Inspect actual review, discussion, issue, actor-scope, revision, audit and notification contracts before implementation; absent shared-analysis operations remain explicit backend gaps, not client-side approval or invented APIs.

UI checkpoint: the first reusable opportunity analysis view is implemented with existing caller-authorized department-level reads and a clearly labelled, in-memory example for reviewing requirements, department remarks and client-preview layout. Granular saved analysis, remarks publication, notifications and operational decisions remain pending. See [the bounded UI evidence](../evidence/SHARED_OPPORTUNITY_ANALYSIS_UI_2026-10-14.md); this does not mark the whole shared-analysis workflow complete.
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

### Project shared analysis — one full-page visual workspace

**Agreed refinement, 15 October 2026; implementation pending.** After the authorized project-start decision, the opportunity's shared analysis continues as the project's full-page Overview / Shared analysis workspace. Opening a project should give its permitted owner, coordinator and participating technical leads a coherent understanding of the product, current work and dependencies without assembling separate document pages. Keep one project identity and link back to its enquiry, opportunity, exact approved Master/PRS baseline, feasibility decisions and phase history. This extends shared analysis through Research/POC, direct Pilot where justified, validation and release; it does not replace those controlled decisions.

Start with one readable page and progressive disclosure, not a separate dashboard for every discipline. Use compact status cards and a simple phase strip, a central product/system visual with linked workstream cards, then current blockers/actions and a reference gallery. Expand a card or reference in context for detail. The internal and client views are audience-specific projections of the same authoritative records; do not maintain independently editable copies or show inaccessible information briefly before hiding it.

| Page area | Information and expected interaction |
|---|---|
| Project identity and requirement baseline | Project/customer, product/variant, current phase, approved requirement revision and latest proposed changes separately. Show last updated time and source/revision freshness; missing facts remain Not recorded or Not verified. |
| Product/system visual | Approved concept pictures, annotated product images, electronic/system block diagrams, interface connections, mechanical drawing previews and permitted 3D reference previews. Link visual items to relevant requirements, parts/subassemblies, interfaces, workstreams and evidence. A diagram is a navigation/understanding aid, not proof of engineering compatibility. |
| Technical workstream cards | Hardware/electronics, mechanical, firmware, software and other applicable workstreams together; key parts/modules, MCU/interfaces, electronic and mechanical BOM snapshot links, firmware/software compatibility notes and relevant design/variant revisions. Existing departments own their applicable work; these cards do not create new departments. |
| Work and handoffs | What each participating department is doing, named authorized assignee/reviewer, actual task state, next required action, expected date where supported, dependencies and handover state. Open the existing task/review through a permitted link; do not create competing task records in the dashboard. |
| Blockers and impact | Clearly identify the main recorded blockers, responsible person/department, blocked workstreams, needed decision/input and affected phase. Show directional dependency links such as Hardware review snapshot → Firmware compatibility and Procurement sourcing → approved BOM lock. Select a blocker to inspect its recorded reason, linked revision and resolution history. |
| Department conclusions | Retain independently saved Internal remarks and Client-visible highlights, including assumptions, risks, recommendations and questions. Link discussion to its requirement/part/issue. Do not publish internal notes automatically. |
| References and updates | A compact gallery of permitted images, block diagrams, drawing/PDF previews and 3D reference artifacts, with caption, owner, source revision, publication state and date. Activity shows what changed and affected dependencies. Preview/open the same controlled Drive revision rather than uploading a second unmanaged copy. |

Graphical status must be backed by real task/review/dependency data. Use text and icons as well as colour; keep a list/table equivalent for accessibility and small screens. Never infer progress percentages, critical path, readiness or approval from document counts. A Next step is either an explicit recorded action or a clearly labelled suggestion; rules may suggest actions from known prerequisites but cannot approve work, create assignments or run transactions automatically. If dependency dates or links are missing, report the gap instead of inventing a schedule. No AI service or external design-data transmission is required.

**Reference previews versus engineering originals.** Shared analysis presents selected concepts, previews and explanatory references; the original CAD, PCB/Gerber, editable mechanical/3D, firmware/software source and restricted working files remain in their authoritative controlled Drive locations under the agreed department/project/group hierarchy. A reference pins its source node/revision and, when available, a checksum or immutable rendition identity. Source updates flag stale previews and reviews for reconfirmation; they never silently replace an approved revision. Where a safe 3D viewer/conversion contract is absent, use an approved static render/thumbnail with an explicit format limitation rather than promising native CAD viewing. Preview visibility must not expose an original download URL or an embedded restricted attachment.

Original-file access is **restricted to the specifically authorized responsible people, reviewers and applicable leads** under the existing assigned-person/category/project rules. Department-lead status, project overview access and ordinary administrator status alone are not blanket file grants. Other teams receive the minimum approved technical information needed for their dependencies. Procurement/Production may still access their explicitly authorized approved BOM, fabrication or released instructions as already planned. The user-requested owner/lead overview does not override RLS, customer/IP restrictions or the existing private DOCX rules.

**Client projection.** Once a project has started, an authorized client can use the same project overview through its accepted scoped invitation/access contract. Publish only approved client-facing requirements, selected concept images/diagrams/renditions, permitted phase progress, department highlights, questions and Your input needed. Internal costing, supplier negotiations, private staff discussion, restricted attachments and original design/source files remain excluded. Client visibility is deliberate publication with a clear audience and exact revision, never an automatic consequence of project start or file upload. Client comments/input use the agreed Edit then Save/Cancel flow, preserve history and notify relevant authorized participants; they do not overwrite the approved baseline. Expiry/revocation and authorization apply to every page and artifact request, not only the opening link.

**Delivery sequence.** First implement a read-only project overview using accepted existing project/baseline/task/part/review reads and explicit unavailable states. Next add scoped reference-preview linkage/publication and actual saved departmental analysis; then dependency/blocker visualization and client projection as their protected contracts become available. Preserve the current bounded feasibility → client approval → baseline lock → project-start queue; this post-start refinement is the next development workspace, not a reason to delay or bypass that flow. Reuse the existing labelled project sample only if a valid project already exists; never start a project or invent approvals merely for a demo. Keep implementation and browser evidence separate from this agreed planning target.

### Reusable PCB, harness, firmware and software records versus client projects

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

#### Composition and early reuse assessment

**Refined agreement — 15 October 2026; implementation pending.** Each new customer engagement has its own project identity, name, requirements baseline, approvals, tasks, delivery records and project reports, even when its entire technical configuration repeats an earlier project. A reusable technical asset is independent of any one client project. A project configuration may contain multiple PCB assemblies, multiple harnesses, mechanical assemblies, firmware builds/configurations and software releases; each permitted asset revision may be used in multiple projects. The six-workstream fictional UI comparisons do not yet demonstrate this composition model and must not be interpreted as one PCB or one firmware per project.

| Reusable record | Exact configuration needed by a consuming project |
|---|---|
| PCB/design and assembled board | Design revision plus assembly/BOM variant, quantity and role in the system; bare PCB reuse does not imply the same fitted components or connector. |
| Harness/cable assembly | Independent harness identity and revision, connector/pinout, wire specification, length/configuration, quantity and endpoint connections to the correct board/interface instances. Reuse across projects is supported. |
| Firmware | Released build/version, compatible board/MCU revision, target board instance, configuration and applicable programming/test reference. One project may use several firmware builds. |
| Software | Versioned release, configuration and interface/protocol compatibility with the selected firmware/system; a project can combine reused software with new firmware or the reverse. |
| Mechanical assembly and system configuration | Exact drawing/assembly revision and compatible board/harness/enclosure interfaces; a reusable system configuration can seed a new project's candidate composition. |

At initial enquiry/Master intake, offer the simple optional choice New design / Reuse existing / Mix of existing and new, with permitted base product/project references when known. Sales or the client can express the intended reuse without gaining access to restricted engineering libraries. During feasibility against that exact Master revision, the responsible departments select the actual permitted existing asset revisions and map them to requirements in the same shared analysis. Allow multiple selections and quantities/instances per category. Keep unresolved selections explicit; saving a selection proposes reuse and does not approve it. A source project is a starting reference for its technical composition, never a source of another customer's confidential scope, approvals or commercial records.

Keep the department decision compact: New development / Adapt existing / Reuse as-is / Not applicable, with selected exact revisions, a concise compatibility/gap note, reviewer and decision history. Assess cross-department interfaces together: board-to-harness pinout, electrical ratings, MCU-to-firmware compatibility, software protocols, enclosure fit and required test applicability. Procurement checks current availability, substitutions and sourcing separately from engineering reuse suitability. Required conflicts and client requirement differences remain visible and block affected gates until resolved.

After the applicable authorized reuse decision is recorded, automatically tailor the department's work template: mark only the covered design/development tasks Not required — approved reuse, retaining the source revision and reason; create adaptation tasks for remaining gaps. Reused is a distinct disposition, never a fabricated completed development task. Whole departments may skip new development only when all their applicable requirements are covered. Integration, configuration/programming, current sourcing, production readiness and applicable Quality/client verification still run where needed. Reuse does not automatically pass feasibility, approve the client baseline, start a project, skip POC without justification or release a BOM. A changed requirement/asset revision invalidates affected reuse conclusions for scoped review.

#### Files, project reports and automatic drafting

Default to one authoritative versioned asset/file with project-scoped references, rather than copying and renaming engineering source files for every customer. A project reference can have a friendly project-specific display label, but it retains the original asset identifier, revision and provenance; aliases are not new technical identities or access grants. Provide a Where used view for permitted projects/configurations and affected dependency notices. Later asset revisions never silently replace pinned revisions in existing projects. Any adoption is an explicit reviewed configuration change.

Create a derivative/new controlled revision only when actual design, configuration, ownership or isolation needs require it, with its source lineage retained. Existing released revisions remain unchanged. The project Drive can show permitted reference entries/shortcuts bound to exact versions under the accepted resolver; no general cross-client file access or original-file publication is implied. Preserve existing assigned-person/category rules. Client views receive only expressly published project-specific summaries/previews and allowed deliverables.

Each client project's reports and applicable controlled documents remain distinct records with its own name/number, customer, approved requirements and configuration snapshot. Draft them automatically from approved project data plus authorized reused revision metadata, applicable evidence and templates, with source/version references. Do not merely rename or copy another client's report; do not copy signoffs, invent missing evidence or claim that auto-drafting is reviewed/released documentation. Retain manual edits and earlier drafts/revisions through the existing controlled generation workflow. Documents for skipped development should record the approved reuse rationale/evidence rather than fabricate a fresh design process. Missing source/template/materialization contracts keep only the affected generation pending.

The full-page project analysis must show a compact System configuration section with expandable PCB instances, harness connections, firmware mappings and software releases, visibly labelled Reused / Adapted / New / Pending review. Selecting an item reveals its permitted revision, related requirements, dependencies and shared concept references. Keep the initial overview concise; detailed technical source files stay behind the existing controlled Drive access.

Delivery refinement: inspect existing component/design, harness, firmware/software version, project-configuration, reuse-decision, where-used and document-source contracts before implementation. Extend supported records/contracts instead of inventing authoritative tables/RPCs. Start reuse assessment during enquiry/feasibility (delivery queue 1), carry the approved composition into baseline/project start (queue 2), then tailor development work, visual configuration and document drafts (queue 5). This refinement adds no mobile build work and does not change the current deployment gates.

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

**Source-only Sales Copy projection checkpoint:** `src/lib/client-opportunity-copy.ts` now defines a pure typed allowlist for a future opportunity-scoped client copy. It emits only selected customer requirement values, separately supplied published highlights, and exact Master/requirement source-revision pins; it excludes internal remarks, costing, staff details and attachments. It neither resolves a link nor treats the shared-analysis example highlights as published. Link resolution remains unavailable until an accepted recipient-bound opportunity scope, expiry/revocation/deactivation, publication/audit and narrow resolver contract exists. Evidence: `docs/evidence/20261015_sales_copy_client_projection_source_only.md`.

## 9. Remaining web portal work and backend handoff

Preserve existing useful screens and controlled stock transactions. Complete department work queues/actions for HR/recruitment/training, Facility/assets/maintenance/security, Finance/matching/aging, Operations/QMS/audit/CAPA and customer service. Recurring work, KPI/OEE/MTBF/MTTR/yield and escalation use reviewed formulas/calendar/timezone/actual events; targets are not achieved values. Audit export is a permitted point-in-time manifest of exact evidence/decisions/missing items, not a certification.

After lifecycle/documents, add Operations **Legal Documents and Letterheads** using existing private Drive records, configurable responsibility and approved versions. Sales links NDA without copying files or gaining Legal access. Add one signed-in company directory through an approved work-contact projection: name, department, designation, manager and work communication details; exclude private phone/HR data. Connect authorized directory/document search to Help/chat/voice, then Android. Calling/messaging employees is an explicit separate user action; external chat/providers are follow-on scope.

Inspect existing employee/profile manager/contact contracts and search/Help/voice/navigation before implementing the directory. Missing contacts or broken reporting hierarchy remain explicit. Legal ownership can later transfer through an authorized configurable responsibility contract without duplicating files or rewriting historical ownership; do not invent a Legal department or grant every Operations employee agreement access. Protect template/letterhead versioning, private agreement history, assigned reviewers and retention. Letterhead availability does not authorize signing or issuing an agreement. Verify signed-in directory access across departments, confidential-field exclusion, absent hierarchy, allowed/denied Legal callers, search/deep-link isolation, reassignment and web/Android parity. Legal/directory work must not delay the active feasibility and document delivery groups.

Web-to-mobile handoff only: after a backend increment is accepted, export its exact fields/enums, payload/response/errors, scopes/RLS, numbering/retry semantics, private file delivery, offline classification and evidence. Keep pending operations explicitly unavailable. Android screens, scanner, native viewers, Room/WorkManager/SyncCoordinator, mobile stage sequencing and APK/device tests belong exclusively to the separate Android build plan (`SSMone-App/docs/planning/SSM_ONE_ANDROID_BUILD_PLAN.md`).

## 10. One delivery queue and evidence-qualified checkpoint

Status definitions: **Verified** = actual stated evidence; **Reported** = implementation/checks reported but not independently/live verified; **Pending** = required behavior absent/unaccepted; **Approval required** = concrete sensitive deployment action still needs specific authorization. Current summaries carry forward prior dated evidence; this documentation consolidation did not rerun product builds or live authorization tests.

| Order | Bounded group | Latest known boundary / next work |
|---|---|---|
| 1 — current | Feasibility handover and reviewer workflow | Combined Sales list/details/customer/Master reads and truthful no-assignment states were browser-verified. Overflow repair and checks reported, visible updated layout observed. A consolidated requirement-by-department feasibility comparison, prominent departmental remarks/client-visible highlights, scoped shared discussion and human conflict resolution are agreed pending work. Protected source-bound requirement + department/reviewer + durable notification handover remains pending; latest source/form work was dispatched, not accepted live. Finish exact contracts, wiring and checks before any deployment gate |
| 1a � source-only writer lock review | Read-only inventory found direct write privileges and Sales manage policies on requirements, revisions, and feasibility reviews, with no installed protected handover/assignment/response route. Pending handover replay and pending assignment/response now share a requirement-root key; disposable same-key, different-key and guarded phantom schedules passed. The reviewable original-target proposal at `supabase/pending/20261015_requirement_feasibility_original_target_compatibility.sql` removes only direct I/U/D and the three verified broad Sales policies, retaining protected source-bound creation/assignment/response operations. Original-target inspection confirmed separate Sales/Engineering/Admin SELECT policies for all three tables; the corrected proposal fails closed on named-policy drift and preserves those exact predicates rather than relying on removed FOR ALL policies. Synthetic ordinary-caller evidence now covers nonempty before/after reads for Sales-manage, Sales-view, Engineering-manage and Engineering-view, denied unauthorized authenticated/anon reads, all authenticated/anon direct I/U/D combinations on each graph table, and protected handover/assignment/response on accepted local prerequisites. The synthetic drift case rejects altered named policy text; the synthetic rollback-capture shape records grants plus exact policy command/roles/USING/WITH CHECK fields. This does not prove target JWT/RLS, target rollback capture/restore, unknown writers, or every protected caller path. A different request key for the same opportunity/customer/Master/title source now serializes then rejects, preventing duplicate handovers. Direct writers remain outside this protocol, so installation and the Sales action remain blocked until exact target compatibility, complete restore capture, and real caller evidence are approved. Evidence: `docs/evidence/20261015_sales_feasibility_handover_writer_root_lock_inventory.md` |
| 1b � source-only Sales Copy | A pure typed, exact-revision client projection is available only as local source preparation; it has no resolver, link, token, publication or authorization effect. It allowlists customer requirement values and separately published highlights while excluding internal remarks, costing, staff details and attachments. Recipient-bound opportunity scope, active/revoked/deactivated/expired checks, publication authority, audit and external caller/RLS acceptance remain mandatory before any client link can exist. Evidence: `docs/evidence/20261015_sales_copy_client_projection_source_only.md` |
| 2 | Controlled project start / baseline | Preserve enquiry/opportunity/Master/review source; verify explicit approval conversion, one project/root, retries and history. No verdict-only automatic project creation |
| 3 | Private DOCX and responsibility | Local renderer/export and private historical HTML evidence exist. Five-file DOCX backend package and responsibility extension are pending/source-only; specific access/deployment approval and real restricted callers remain required. Do not treat local export as saved DOCX |
| 4 | Drive/register completion | Four-group/filter source and UI checkpoints exist; verify all departments, PPAP/favorites placement, same revisions and useful register reads. Customer XLSX automatic private storage/refresh is pending, not established by export foundation |
| 5 | Project visual shared analysis, POC/pilot and Procurement review | Complete optional Research/POC, parallel phase-scoped Firmware/Procurement review, post-test feasibility and electronic/mechanical tentative BOM review without circular lock dependencies, plus shared R&D-owned PCB/design records and customer product variants with scoped Procurement/Production reads and exact revision links. Procurement source package is pending; preserve inventory/PO boundaries and exact BOM versions |
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

### Current scheduled completion boundary � 15 October 2026

Complete the discussed Sales flow through selected-department handover, durable notifications, shared departmental analysis with separate internal remarks and client-visible highlights, conflict resolution and feasibility pass against the exact Master revision. Obtain recorded client approval of the final requirements revision, then lock that approved baseline before an authorized project-start decision selects optional Research/POC or a justified direct Pilot path. Changes to that revision must invalidate stale approvals/reviews as applicable; notifications alone are not approval. Keep client edits simple: read-only by default, deliberate Edit and Save/Cancel, latest input separate from the approved baseline. No automatic project start from a feasibility status or client edit.

The scheduled follow-up targets this bounded operational flow first. UI examples are not persisted remarks, delivered notifications, client approval or baseline-lock evidence. Inspect/develop the protected contracts and continue unaffected source/UI work while any deployment or identity gate awaits specific authorization. Android implementation remains outside this queue.
Readiness correction checkpoint (15 October): a completed not-feasible verdict must remain a blocker, even with exact source pins; completion is not feasibility pass. The read-only composer now enforces this, with a regression test. Backend installation and operational acceptance remain pending.
Handover replay review (15 October): the pending source now pins immutable requirement/review identities and replay source facts, then locks mutable validation rows with FOR SHARE in the documented order before returning. Disposable two-session checks use coordinated plain updates for replay-held and writer-held graph changes. Installation remains blocked: row locks do not prevent new-review phantoms or direct writers that bypass an accepted requirement-root serialization path. Required production-like direct-write/RLS and writer-path evidence remains pending; do not substitute production execution or claim the deployment accepted.
## Source-only repository reconciliation review — 15 October 2026

UI checkpoint (15 October): commit 777ea64 clarifies Client-visible highlight headings and reserves four department columns for extra-wide screens. All 14 focused UI tests, TypeScript and production build passed; local browser evidence is linked in docs/evidence/SHARED_OPPORTUNITY_ANALYSIS_UI_2026-10-14.md. Original-project readback of this final styling remains unverified. Lovable-backed disposable assignment/response and full caller/read checks remain pending because the available session reached its credit limit; this does not authorize a purchase. Live installation, policy/grant changes and UI enablement remain blocked pending the exact compatibility/restore and real-caller evidence. Continue local unaffected work without repeated unchanged verification.
Read-only UI checkpoint (15 October): the internal shared-analysis view now includes a compact Before project start summary. It reports recorded source/assignment facts while condition resolution, client approval and baseline lock remain explicitly unverified. Client preview excludes it. Fifteen focused UI tests, TypeScript, production build and local-browser verification passed; this does not implement live feasibility approval or project start.
Sales list UI checkpoint (15 October): compact semantic table now includes Status/stage, Feasibility/team, Next action and direct Details/shared-analysis/team-handover preparation icons. Real sending remains blocked by the pending protected backend installation and caller acceptance; the shortcut does not imply team notification or approval.

Original-preview checkpoint (15 October): the existing OPPORTUNITY-2026-0013 table icons independently opened Feasibility/shared analysis and team-handover preparation. Send remained disabled. Evidence and original screenshot are recorded in docs/evidence/SHARED_OPPORTUNITY_ANALYSIS_UI_2026-10-14.md. Source equivalence was reported by Lovable; diverged Git histories and pending backend activation remain unresolved. This UI verification does not establish persisted remarks, notifications, client approval or baseline lock.

Client-link placement refinement (15 October): provide a Copy client link action directly on each opportunity row alongside shared analysis and team-handover preparation. Copy only an existing valid opportunity/client-scoped invitation URL supplied by an accepted protected contract; never copy the internal Sales route or synthesize an access token. Keep unavailable with an explanatory reason until that contract is installed and accepted. Creating or renewing client access is a separate explicit authorized operation, not a side effect of Copy. The client projection includes only permitted requirements and published highlights, excludes internal remarks and restricted files, and preserves expiry/revocation and approved-baseline separation. Clipboard success alone is not client-access acceptance.

## Ongoing plan maintenance and future reuse

User instruction (15 October 2026): keep this master plan current after each meaningful discussion or implementation group, including completed work for future reference and reuse in other projects. Update the relevant requirements and delivery status in place. Retain a concise completed-work record with the behavior delivered, actual verification boundary, evidence/source references and any remaining dependency. Clearly distinguish agreed, implemented locally, visible in original preview, deployed and operationally verified states. Do not remove completed requirements merely because they are done, or mark a planned/example feature as working. Keep detailed dated evidence in docs/evidence and exact technical contracts separately; do not create competing dated master plans. Android implementation continues to use its separate Android build plan.


Client-link prerequisite review (15 October): the existing token invitation handler needs verified intended-recipient/existing-account binding and deactivation checks before reuse from Sales. Source-review details are retained in the existing shared-analysis evidence. No invitation was generated, copied, accepted or sent, and no authentication/permission change was made.


Original-project client-link inspection (15 October, reported source 2435f5c): no opportunity-scoped copy-only resolver exists; recipient replacement, repeat acceptance and missing acceptance-time deactivation checks must be addressed before exposing invitations from Sales. Existing file/BOM links and pending intake do not satisfy this feature. Prepare a source-only resolver/projection contract first; preserve the separate specific authorization gate for access/deployment changes.


GitHub-first reconciliation (15 October): downloaded original Lovable source ZIP SHA256 415140696b36574376e2a58f0d55e595d0e6a39be61ab2d8212429e7ee15cecd and retained it outside the active repository in SSMOneWebBackups/sync-review-20261015-1105. Imported new source-only client projection and original compatibility fixture improvements. Preserved local readiness summary, explicit Client-visible highlight labels, wider responsive breakpoint, and corresponding tests instead of regressing them to older original-source equivalents. Detailed private source history remains in the backup; this snapshot import is not a two-parent Git merge or proof of Lovable connection repair. Scheduler is active and future implementation uses local source/GitHub; Lovable consultation is limited to current sync recovery. Client projection remains unavailable for external access pending protected resolver and publication contracts.

Status: **review candidate only**. No remote push, connected-repository setting,
GitHub permission, database, policy/grant, live record, handover enablement, or Publish action
occurred. The original Lovable workspace stays at private HEAD
`7e18929246f91854c8d9a28c4fb0bb82b5eaba3d`.

### Preserved histories and merge basis

- Private head: `7e18929246f91854c8d9a28c4fb0bb82b5eaba3d` (`Verified policy drift guard`), parent `a8ed88b2cec0cb5b6f27acabb9c692f2070003a3`.
- Private compatibility lineage retained unchanged: `e7e00c4`, `bd6770f`, `3bd0a3a`, `dce054f`, `d90d1e4`, `dd0e011`, `7e18929`.
- Public main candidate: `6685732ccb28e43e3208148a333d0cee562e1718` (`Compact sales pipeline with direct analysis and team handover shortcuts`), parent `a8ed88b2cec0cb5b6f27acabb9c692f2070003a3`.
- Exact common base: `a8ed88b2cec0cb5b6f27acabb9c692f2070003a3`.

The managed workspace prohibits branch/merge operations, so no review branch or merge commit
can be created there. An exported private-head tree was reconciled only under `/tmp` by applying
the public commit's exact parent diff; this leaves the managed checkout and both histories intact.
The exact public patch SHA-256 is
`b107ad852c47131b5dbd7d6e3240f5164c30444381230798d2a108af36b085cb`.

### Reconciled candidate scope

The public UI source applied cleanly to the exported private tree:

- `src/components/sales/EnquiriesWorkspace.tsx`
- `src/components/sales/EnquiriesWorkspace.dom.test.tsx` (new)
- `src/components/sales/OpportunityDetail.tsx`
- `src/components/sales/OpportunityDetail.dom.test.tsx`
- `src/routes/_authenticated/sales.enquiries.tsx`

The public image was copied only into the disposable candidate as
`docs/evidence/ssm-opportunity-table-20261015.png`; its extracted blob SHA-256 is
`ff524653f21278a7da87e88d3f13172edc17ab14dd1f024bdbf012322a4121fe`.

Two documentation hunks overlapped private source-only verification wording and were resolved in
the disposable candidate by retaining the complete private documents and appending the public UI
checkpoint verbatim:

- `docs/evidence/SHARED_OPPORTUNITY_ANALYSIS_UI_2026-10-14.md`
- this canonical plan

No pending SQL file was altered. Frozen pending-source checksums remain:

- `supabase/pending/20261015_requirement_feasibility_original_target_compatibility.sql` — `34713394369e38e87f0c968e47c6f3eb6a78aaf3e29527b6c867698bc62f413f`
- `supabase/pending/20261013_sales_feasibility_handover.sql` — `a5f8b0b5fce1be565bfc6e8ea3e3c97e58020bd2d61a922f401e4aff2a3dfbab`

### Disposable verification

Against the reconciled temporary candidate only:

- `bunx vitest run src/components/sales/EnquiriesWorkspace.dom.test.tsx src/components/sales/OpportunityDetail.dom.test.tsx src/components/sales/SharedFeasibilityAnalysis.dom.test.tsx` — exit `0`; 3 files / 13 tests passed.
- `bunx tsgo --noEmit` — exit `0`.
- `bun run build` — exit `0`.

### Safe application after review

1. Keep private `7e189292` and public `6685732` immutable.
2. In a normal writable clone that contains both objects, create a named review branch from private `7e189292`.
3. Merge public `6685732` with a normal two-parent merge (no reset, rebase, cherry-pick, or force update).
4. Preserve the two documentation additions described above; do not replace the private compatibility evidence or canonical-plan checkpoint.
5. Repeat the three checks above, then have an authorized maintainer review the merge commit and connect that merged commit to the original project. Only then should the preview be expected to render the compact table.

This is source-only reconciliation guidance. It neither authorizes nor performs a push, connection change, SQL installation, policy/grant change, live data write, UI enablement, project start, or Publish.



### Managed source application � compact Sales table, 15 October 2026

The verified UI-only source from public commit `6685732ccb28e43e3208148a333d0cee562e1718` was copied into the original managed project using ordinary source edits: `EnquiriesWorkspace.tsx`, its DOM test, `OpportunityDetail.tsx`, its direct-entry test, and the Sales enquiries route wiring. The applied UI files match the public candidate byte-for-byte; private feasibility compatibility source, tests and prior documentation remain unchanged. This makes the compact table and its direct shared-analysis/team-handover row actions visible in the original preview. The handover send action remains disabled pending separately approved backend installation.

This source equivalence is not a two-parent Git history reconciliation. The public GitHub connection and the private managed history remain separate; no remote, connection, rebase, reset, cherry-pick, force push, SQL, grants, policies, records or publishing action occurred.

Sync recovery merge resolution: preserved both Git histories using origin/lovable-sync, combined both documentation checkpoints, and retained newer local shared-analysis UI/tests and screenshots. Deferred unrelated Lovable Vite-config dependency upgrade 2.25.3 to 2.26.5; current validated dependency version remains 2.25.3. Recovery branch commits remain ancestors of the merge, not squashed or rebased.


Reconciliation validation: 17 focused projection/list/detail/shared-analysis tests passed; TypeScript no-emit and production build exited 0. SQL fixture additions are retained as source-only; no local PostgreSQL execution or live backend deployment occurred.


Sync recovery completed (15 October): normal two-parent merge 81eccfd42651feef9ece0ed76647079a54671047 includes origin/lovable-sync c8e7ee8907ea5ade1d38bf754108750dfccf2f23 as an ancestor and was pushed to narendok/ssmone1 main. Original Lovable Git settings re-check displayed In sync with GitHub. Screenshot: docs/evidence/ssm-github-in-sync-20261015.png. Both histories and latest client projection are now retained; future feature implementation continues locally through GitHub under the active scheduler. No SQL deployment or live business/access mutations were performed.


Multi-department handover preparation (15 October): opportunity handover now accepts multiple intended department/reviewer pairs, prevents duplicate selections and supports removing teams. Closing clears the local preparation. Five focused detail tests, TypeScript and production build passed. This is UI preparation only; membership verification, atomic persistence and durable notifications remain gated by the protected backend deployment. No fixture or live routing was saved. Original-preview readback follows GitHub sync.


Original preview now displays the multi-team preparation controls from 4027eb1 for existing OPPORTUNITY-2026-0013; detailed evidence and screenshot are in docs/evidence/SHARED_OPPORTUNITY_ANALYSIS_UI_2026-10-14.md. Backend sending remains unavailable.


## Implementation ownership and economical Lovable assistance

User direction (15 October): Codex performs most coding, feature implementation and verification locally, with GitHub as the primary workflow. Use Lovable only for a concrete difficult blocker or managed-environment check unavailable locally, in one bounded request with explicit success criteria. After Lovable completes such work, fetch/reconcile the resulting GitHub changes into the same local web repository before continuing; avoid concurrent unsynchronized edits. Minimize Lovable credit use and prioritize working features rather than repeated planning or unchanged validation. Demonstrate each successful usable increment in the actual browser using the existing labelled sample opportunity, Master revision, enquiry and customer, without duplicate fixtures. State which actions persist and which are preparation/source-only. Keep completed decisions and evidence in this master plan for future reuse. Existing data/access/deployment approval boundaries remain applicable. The active scheduler has been updated to follow this approach.


Pending handover adapter increment (15 October): added caller-authenticated submitSalesFeasibilityHandover transport for the inspected pending SQL interface. Immutable enquiry/opportunity/customer/Master version, expected enquiry timestamp and request key are mandatory; department/reviewer pairs remain together in canonical order, duplicates are rejected, and an empty/malformed receipt is not saved success. The server handler rejects before RPC while availability is false. Three focused transport tests and production build passed. No UI enablement, SQL install, notifications or operational acceptance is claimed; typecheck result is recorded separately after completion.

TypeScript no-emit completed successfully for the pending handover adapter. No browser demo applies to this disabled server transport; the previously verified preparation UI remains the current visible behavior.


### Source-only first feasibility activation bundle — 17 October 2026

Prepared a reviewed source-only package for pinned review provenance, protected assignment/response and atomic Sales handover. It excludes external intake, private notes/highlights/publication, baseline approval, project start and direct-write restriction. The activation draft fails closed on missing dependencies, incompatible helper signatures, partially pinned legacy reviews and duplicate non-null revision/department review pairs. On 17 October, a disposable PostgreSQL 17 run corrected the reserved `constraint` preflight alias, aligned only the synthetic `next_business_number(text,text,text)` helper to the managed signature, corrected the replay fixture to comply with complete provenance pins, verified the separate transition include, and passed handover/replay/stale/unauthorized/graph-drift/notification-rollback plus synthetic access-transition checks. No migration was applied and no UI was enabled. Managed caller/RLS, concurrency, notification rollback, writer reconciliation and restore acceptance remain required. Evidence: `docs/evidence/20261017_feasibility_activation_bundle_source_review.md`.

### Two project-analysis UI alternatives — 15 October 2026

User requested an independent Lovable versus Codex comparison before selecting a product layout. Both standalone fictional previews are retained under public/design-previews, with project-analysis-compare.html as the entry. Lovable source arrived in ac91e19 and was fast-forward reconciled before the independent Codex file was added. The incidental managed Vite configuration upgrade was deferred back to validated 2.25.3; no application route/backend changes were needed. Codex emphasizes wide visuals, workstream cards and a dependency/list toggle; Lovable uses a three-column department selector, system visual and analysis panel. Both illustrate internal remarks versus published highlights and a proposed change separate from the baseline. These are UI-only examples, not persistence, authorization, client publication, a project start or acceptance. Local browser navigation timed out, so visual/interaction verification and final user comparison remain pending; do not mark either design chosen or live.

Project analysis comparison browser checkpoint: both A/B prototypes now open and their basic department selection, client filtering and reference interactions were exercised through the existing 4179 preview server. Prior timeout is resolved for that server path. Detailed limits and screenshots: docs/evidence/PROJECT_ANALYSIS_UI_COMPARISON_2026-10-15.md. Lovable desktop center overflow requires refinement; Codex workstream cards require scrolling. Neither design is selected or integrated with live persistence.

Planning-folder refinement (15 October 2026): reviewed all 13 dated technical files in docs/planning. They contain unique contracts, review-only SQL/preflight queries and acceptance specifications, so retained them under docs/contracts rather than deleting or flattening their safety/implementation detail into this roadmap. docs/planning now contains this single master plan, README, document catalogue Markdown/JSON and its source/tool support. Updated active indexes and two technical cross-references; historical evidence paths remain unchanged for provenance and are explained in docs/contracts/README.md. No useful contract, pending SQL, source inventory, evidence or mobile plan was deleted. No runtime/backend changes or acceptance implied.

Compact Codex refinement (15 October): user prefers the Codex direction and requested one more compact trial before adopting the layout. Added project-analysis-compact.html and C · Compact Codex in the comparison entry; earlier A/B versions are preserved. Candidate layout: condensed phase/requirements rows, smaller concept visual beside blocker/owner/next action, short dependency chain, collapsed system configuration with multiple PCB/harness instances and firmware/software mappings, compact department selectors and one selected analysis with separate remarks/highlights. Configuration illustrates proposed reuse, not approved reuse or skipped development. Browser checks verified expansion, Firmware selection and removal of private configuration/notes in client preview. Desktop screenshot: docs/evidence/compact-project-board-20261015.png. This is a candidate UI-only example pending user layout review; no live project data, persistence or authorization changes. The screenshot predates the wording refinement from reused boards to boards proposed for reuse; final source makes the pending state explicit.

## Approved project analysis UI baseline — 15 October 2026

User approved the final compact Codex design. Use public/design-previews/project-analysis-compact.html (design source commit 24890b1) as the reference for application integration and future reuse. This decision supersedes earlier candidate layouts, list/card alternatives, separate remarks tables and department-selector refinements; retain the earlier A/B previews and evidence as history, not competing implementation targets.

- One project overview combines approved requirements, separately identified pending client input, product/concept and block-diagram references, current blocker and next action, reusable system configuration, dependencies, tasks and department analysis. Keep project identity separate from versioned reusable PCBs, harnesses, firmware, software and mechanical assets.
- Progress & Dependencies, Team & Tasks, and Department Workstreams & Remarks have subtle bordered uppercase headings and accessible chevrons. Main sections start expanded and collapse independently. System configuration, team roster, dependency explanations and individual task/department details start collapsed.
- Dependencies use a compact arrow sequence with explicit completed/active/blocked/waiting states, responsible teams and expandable conditions. A subtly animated progress bar counts only clearly defined completed steps and respects reduced motion. The prototype's 25% is one of four fictional equally counted steps, never overall project effort, schedule progress or live acceptance.
- Tasks use compact cards only, with assignee, department, due information and colored textual statuses from the existing task contract: To do / In progress / In review / Blocked / Done (the standalone mock uses simplified labels). Keep bordered department/status/assignee/search filters and Clear filters. Task filters remain scoped to tasks. Expanded cards expose descriptions, assignment and related task details.
- Show all department workstreams as compact closed cards. Each includes its status, workstream title and separate two-line internal remark/client highlight excerpts. Expanding replaces excerpts with full notes, next action and permitted related links; avoid duplicate remarks in separate sections. Excerpts are clipped source text, not AI summaries.
- Compact arrow links provide approved Master revision, task details, department workspace/related assets and exact reusable asset revision context. Preserve the project and revision when navigating. Private originals stay in controlled Drive locations and require independently verified access; no overview link grants permission.
- Client view uses only the accepted published projection. Exclude private task assignments, roster, internal remarks, costing and engineering source files; show only explicitly published highlights/references and permitted requirements context.

Implementation status: approved UI design and browser-tested standalone demonstration only. Sample navigation opens labelled fictional context dialogs. Task assignments are in-memory and reset on reload. Live reads/routes, durable tasks/remarks, notifications, publication, scoped asset/Drive resolvers and operational access acceptance remain pending. Design approval does not approve a requirement baseline, feasibility pass, project start, deployment or Publish. Continue the existing bounded feasibility/client-approval flow and protected-contract gates before live project lifecycle integration. Android build scope remains separate.

Verification history and screenshots: docs/evidence/PROJECT_ANALYSIS_UI_COMPARISON_2026-10-15.md. Main-section disclosure controls, collapsed note previews, task filters/assignment examples and contextual navigation were exercised in the browser. Do not repeat unchanged UI checks merely to record this planning decision.

### Department project management — clarified requirements and integration order

Status (17 October 2026): the user confirmed the selected compact project-analysis UI as final; no further design choice is required. public/design-previews/project-analysis-lead-trial.html demonstrates browser-memory interactions only. The approved common-board visual baseline above remains valid. Trial labels, sample identities, free-text owners and isolated task lists are not authoritative models and must not become a second task system.

#### Reuse existing task management

Integrate the existing src/components/tasks/TaskDialog.tsx, TaskDrawer.tsx and TaskBoard.tsx presentation patterns and src/lib/tasks.ts contracts. Create/edit the same project tasks used elsewhere in the portal; cards, project overview, department workspace and personal task views must agree after save/refetch. Do not copy tasks into a parallel department table or synchronization engine.

- Preserve existing project_id, canonical department_id, assignee_id and supported related-record IDs. Select permitted existing members by identity, never free-text names. Department/workstream labels are not substitute IDs or permissions.
- Use exact existing task statuses: todo (To do), in_progress (In progress), in_review (In review), blocked (Blocked), done (Done). Priority: low/medium/high/urgent. Reuse title, description, due_date, estimated/logged hours and supported checklist/history/linked-record controls rather than inventing equivalents. Due date is currently a date; do not imply time-of-day deadlines or scheduling dependencies that the contract does not provide.
- Keep compact task cards and bordered search/status/assignee filters. Create and edit use the existing task form with current project/department context. Save/Cancel, pending/error feedback and refresh must reflect actual persistence; UI editing alone is not success. Template-specific deliverables, dependencies, work routes or stage links absent from verified contracts remain explicitly proposed until supported.

#### Department scope, editing and navigation

Place Project overview / Department view beside Internal view / Client preview in the top controls. Resolve a normal member's department from verified membership; no routine department dropdown. Only authorized multi-department users get a top-bar department switcher, with permitted choices. My tasks / Team tasks and project filters narrow authorized records, never broaden access.

Department leads manage authorized project work, tasks, assignments, dates, priorities, remarks and team responsibilities. Members can create/edit tasks or other fields only under explicit supported capabilities/delegation; membership alone does not grant blanket edit access. Enforce the same authority in common view, detail forms, direct links and backend operations. Common view exposes permitted cross-department context; department view focuses own work plus relevant upstream/downstream dependencies.

Project metadata, team membership/reassignment, closure and task editing are separate capabilities. Removing a member must account for open assignments and history. Distinguish closing department work from ending the whole project. Whole-project closure requires explicit project-level authority and an accepted disposition/audit contract; no implicit authority from being a department lead. Approved requirements, released asset/BOM revisions, approvals, stock and payments retain their existing protected operations.

#### Phases, department stages and configurable task templates

Keep project phase (feasibility / optional Research-POC / Pilot / later lifecycle), department stage and individual task status separate. A Pilot workspace must show Pilot-specific technical work, not only a generic phase label. Reused assets may require compatibility/validation while approved unnecessary development is marked not required with reason; never fabricate completion or bypass integration/review gates.

Use the eight existing department groups from src/lib/department-dashboard.ts. Hardware, Firmware, Software and Mechanical are technical workstreams here, not newly created authorization departments. The following are proposed default Pilot task families for gradual company review, not an approved exhaustive stage matrix:

| Existing department group | Proposed Pilot work families |
| --- | --- |
| Hardware & R&D | Requirements/reuse compatibility; parts/BOM; schematic and PCB/assembly revision; fabrication outputs; bring-up; firmware/software interfaces; enclosure/harness fit; integration and validation evidence. Engineering workstreams refine their own tasks. |
| Procurement, Stores & Incoming Quality | Exact-BOM sourcing, stock/availability, quotes/alternatives, authorized purchasing references, shipment/IQC/material readiness and joint BOM review. Tasks never post stock or orders. |
| Production | Build readiness, routing/fixtures, trained operators, assembly/traceability, programming/calibration references, yield/defects/rework and build report. |
| Facility & Maintenance | Workspace/utilities/ESD readiness, maintenance/calibration references and equipment blockers. |
| Operations & QMS | Risks/dependencies, validation evidence, nonconformities/CAPA, controlled revisions, authorized release coordination and handover/service readiness. |
| Sales | Approved requirements, client clarification/change coordination, milestones, published updates, demonstration/acceptance evidence and next-phase coordination. |
| Human Resources | Staffing/competency/training coordination with permitted references; private HR records stay private. |
| Finance | Approved budget/cost references, permitted payment dependencies, variance review and billing references; no financial authority inferred from tasks. |

Settings should eventually support versioned department workflow templates: duplicate a stage, rename and insert/reorder it, configure applicability, roles, task defaults, deliverables and dependencies. Clones copy definitions only, not approvals, signatures, completed work or client data. Used template versions and active-project routing snapshots remain pinned; changes to active work require reviewed explicit migration. Protected gates cannot be removed through ordinary template editing. Settings UI/backend and the full default stage matrix remain pending contract inspection and gradual department review.

#### One practical workspace and next bounded implementation

Keep approved requirements/pending input distinct at top, then relevant configuration/revisions, current stage/milestone, scoped task/team cards, blockers, incoming/outgoing dependencies, reviews/deliverables and separate internal remarks/client highlight drafts. Derived counts/progress must use actual scoped records and distinguish task completion from stage approval. Original files require accepted Drive access; highlights require explicit publication. Avoid parallel generic and Pilot task lists like the current trial; converge on one task collection with phase/workstream filtering.

Next: inspect existing task mutation authorization/member resolution and project/department filtering, then integrate one existing task create/edit/due-date flow into the department board. Verify saved task readback in the existing task views, review status, member selection, dates, errors and permitted/denied editing. Reuse existing labelled fixtures; no duplicate fixtures or new production identities. Keep unsupported stage/delegation/closure operations blocked while continuing supported task integration. Verify the integrated approved view before declaring persistence complete. Preserve the existing feasibility/client-approval delivery order and deployment gates; Android builds remain separate.

Evidence: docs/evidence/PROJECT_ANALYSIS_UI_COMPARISON_2026-10-15.md retains trial checks and limitations. No live task management, settings stage matrix, delegation, notifications, publication or project closure acceptance is claimed by this planning refinement.

Shared task source checkpoint (16 October): added DepartmentProjectTasks using existing TaskBoard/TaskDialog with canonical department presentation scope, board-mode default and new-task department default. Eight DOM tests and production build passed. Not yet route-integrated or browser/live accepted. Existing source policy uses projects.manage; delegated department editing and affected-row write readback are unverified. Continue caller membership/project resolution and browser integration without changing RLS or claiming mock roles as authorization.

Connected trial checkpoint (16 October): replaced separate generic/Pilot task editors with a shared sample task collection across common/department projections and client-only published highlights. Browser tested task creation with canonical status/priority/member/date, cross-view readback, draft/publication separation, read-only controls, stage editing and Cancel. Trial aligns field semantics with existing tasks but remains standalone HTML; actual React route integration and verified durable writes/permissions remain pending. The user confirmed the selected compact project-analysis UI as final on 17 October 2026; no further design selection is required. Evidence remains in docs/evidence/PROJECT_ANALYSIS_UI_COMPARISON_2026-10-15.md.

## Unified budget planning, expenses and asset-cost visibility

User requirement (16 October 2026): budgeting belongs throughout the portal at company, department, project and assigned-member levels. This section defines planned capability, not an implemented accounting system. Reuse existing Finance expenses/payment records and asset/assignment records after verifying their contracts; do not create duplicate expense ledgers or infer budget support from the existence of quick_expenses. Source inspection found createExpense in src/lib/phase6.functions.ts accepts project/department context and uses server numbering; assets/asset_assignments are covered by src/lib/phase8.functions.ts. Their current scope/authorization and any budget objects must be verified before implementation.

### Planning hierarchy and ownership

- Company: financial-year/period budget, approved department envelopes, project portfolio allocation, centrally held/unallocated funds, capital/operating plans, forecasts and consolidated variance. Finance prepares/reconciles; explicit authorized company approvers approve versions/transfers.
- Department: approved allocation, project/non-project work, shared overhead, member spending limits, equipment/asset needs, purchase commitments and expense actuals. Department leads may prepare and manage authorized plans; financial approval/payment authority remains separately configured.
- Project: approved baseline and forecast by phase/workstream/department, materials/BOM, prototyping, services, testing, tools/equipment, travel/installation and other configured categories. Separate estimated BOM sourcing from actual purchases and consumption. Common project analysis exposes a permitted compact budget summary; department view exposes its scoped allocation and expenses. Client view excludes internal costs unless explicitly published under an accepted contract.
- Member: assigned spending envelope/advance where applicable, submitted/approved/rejected/reimbursed expenses and assigned asset custody. Member budget is a scoped allocation, not personal salary, asset ownership or permission to spend. Show only authorized personal/team financial information; private HR/payroll data stays separate.
- Shared allocation dimensions must refer to the same underlying cost/budget records. Company, department, project and member are views/allocations, not four independent amounts to sum. Allocate shared costs with explicit amounts/percentages, effective dates and rounding rules; split totals must reconcile to the source.

### Budget lifecycle and operational records

Plan versions support draft, submitted review, approved baseline, forecast/revision and closed/archived states only through verified configurable contracts. Preserve approved versions and actuals; amendments/transfers record reason, before/after values, approver and effective period. Distinguish reallocating an envelope from approving a purchase or paying an expense. Configure category, cost centre, financial year/period, currency and approval thresholds in Settings with scoped permissions and audit.

Where authorized, department/project/member views provide New expense and expense records using the existing Finance workflow. Inspect and extend supported fields for category, amount/currency, transaction date, project/department/member allocation, supplier/payee reference, receipt/evidence and reimbursement context. Clearly distinguish draft/requested, approved, rejected, paid/reimbursed and reversed states according to actual contracts; no invented status mapping. Preserve server-issued numbering, payment references and audit; approval never implies payment. Procurement, invoice/expense matching and reversals must prevent duplicate recognition of the same spend. Missing contracts block only the affected operation.

Budget lines should distinguish approved baseline, revised approved allocation, forecast, reserved/committed amount, recognized actual, paid cash, remaining and variance. Finance must approve formulas and recognition events before operational totals: for example, PO outstanding commitment reduces as recognized invoices replace it; paid cash is a separate view and must not be subtracted a second time. Separate drafts/pending requests from posted actuals. Track cancellation/credit/return and partial fulfillment with source references. Show unavailable/pending when a source cannot be reconciled, not zero or a fabricated total. Multi-currency totals require an approved reporting currency, rate source/date and rounding policy; otherwise keep currencies separate. Period and fiscal boundaries follow configured company timezone/calendar.

### Assigned assets and budget treatment

Link existing asset identities, purchase/acquisition references, current custodian, department/project usage allocation, assignment/return dates, condition, maintenance/calibration and disposal history where supported. Leads see permitted team assets; members see their own custody; authorized asset/Finance managers see company summaries. Reassignment changes custody/allocation history, not acquisition cost or an automatic new expense.

Show asset acquisition/capital planning separately from operating expenses and cash. Any depreciation, rental, utilization or internal charge-back requires a reviewed policy/contract; never count full acquisition plus depreciation plus internal transfer as repeated company spend. Shared asset allocations reconcile to one original record. Procurement of new equipment, assignment of existing equipment and expense claims remain distinct actions. Planned asset demand may flag availability/reuse before proposing a purchase.

### Embedded views, charts and filters

Use one Finance budget workspace with linked compact summaries in company dashboard, department workspace, project analysis and permitted member view. Offer cards/table detail and accessible charts: budget versus actual/commitment, monthly spend trend, department/project/category breakdown, capital versus operating allocation, variance/forecast and asset allocation. Label units, currency, period, actual versus forecast, inclusion rules, source freshness and unavailable data. Chart drill-down opens the exact contributing permitted records; table equivalents remain available. Do not treat arbitrary chart percentages as approved financial performance.

Filters: period/financial year, department, project, member where permitted, category/cost centre, capital/operating, status, currency and asset/expense source. Persist navigation context and avoid private information leaking via aggregate totals or exports. Low budget, forecast overrun and overdue expense-review notifications follow configured thresholds/current authorized recipients, with deduplication and durable delivery evidence; no automatic financial transaction.

### Delivery and verification

1. Inventory verified budget/expense/payment/Procurement/asset contracts, Finance permissions and recognition rules; document supported fields and gaps without changing privileges.
2. Trial read-only reconciled scoped summaries and charts using explicitly labelled sample data; review company/department/project/member allocation and asset treatment together before adopting UI.
3. Integrate existing expense create/edit/review routes and permitted asset references; verify persistent readback, denied callers, period/currency handling, split allocations, no duplicate recognition and history.
4. Add protected versioned budget approvals/transfers/forecasts only after accepted backend contracts, then reconciliation, exports and threshold notifications. No payment execution, payroll expansion, production identities or privileged changes are authorized by this roadmap addition.

Keep this work in the same master plan, with evidence under docs/evidence. Continue the previously prioritized bounded feasibility/client-approval delivery; budgeting is an added portal workstream, not a claim that the existing trial or Finance module already implements it. Android receives verified contract handoff separately and retains its own build plan.

## Governed inventory and asset workspace

Refinement (17 October 2026): extend the existing governed inventory experience into a complete inventory-and-assets workspace while preserving its current stock, receiving, project-link, audit, and authorization controls. The uploaded brief is a requirements reference only; no sample records or browser-only transactions will be copied.

### Confirmed decisions
- **Wire harnesses**, not material hardness: treat them as project-linked connector-and-wire assemblies.
- **Classification:** wire harnesses have one controlled primary category plus Mechanical and Electrical cross-tags for discovery.
- **Assets:** keep production machinery and other serialized equipment in the separate asset register, not in stock-part inventory.
- **Recipients:** a part or harness can be issued only to an active member of its linked project team, after server-side scope validation.

### Delivery plan

#### 1. Protect inventory authority and released-stock rules
- Retain backend-owned, idempotent receipts, adjustments, issues, returns, lots, and movement history.
- Verify and close the boundary between stock locations and incoming-quality lots before expanding allocation: held or rejected lots must not be issueable, and returns must retain a clear usable/inspection/quarantine disposition.
- Maintain existing official numbering, historical records, locations, and permissions. Do not create browser-local stock, audit, or fake success states.

#### 2. Expand the controlled parts taxonomy
- Extend the existing hierarchical part categories without disturbing existing records.
- Add controlled paths for electronics, connectors, wire and cable, wire harnesses, mechanical parts, enclosures and enclosure subtypes, firmware tools, production tools, and packaging/consumables.
- Model wire harnesses as component records with connector/wire specifications, approved alternatives, linked projects, stock/lot traceability, and primary category plus Mechanical/Electrical discovery tags.
- Keep category stewardship, migration/backfill, validation, and duplicate-prevention rules explicit before enabling new selectors.

#### 3. Complete the part register and project context
- Retain current search, hierarchy, manufacturer, package, location, stock/review state, and project filters.
- Add category/cross-tag, project-link, allocation state, and released-stock filters after their authoritative data contracts exist.
- Provide a part detail view covering specifications, project links, stock by location, released/held quantities, lots, approved substitutes, allocations, returns, movement history, and compatible assets.
- Keep component-to-project links descriptive and auditable; stock issue remains its own controlled transaction.

#### 4. Introduce project-team-controlled issuance
- Extend the existing material issue/return flow instead of adding a parallel issuing path.
- Resolve each recipient from the active project team on the server; store the recipient, department context, project, issuer, and request key in the issued-record receipt.
- Permit multiple eligible project-team members for a feasible part/harness allocation, while rejecting inactive, removed, cross-project, or department-ineligible recipients.
- Preserve location selection, availability checks, partial returns, notifications, idempotent replay, and immutable issue/return history.

#### 5. Keep assets separate but connected
- Expand the separate asset taxonomy into controlled classes and subclasses: office assets, production machinery, mechanical equipment, tools, and related subtypes.
- Keep serialized asset lifecycle, custody, facility location, maintenance, calibration, and handover history distinct from component quantities and lots.
- Add an auditable compatibility relation between a machine/asset and the parts, harnesses, enclosures, or consumables it uses; do not misuse custody assignments as compatibility links.
- Complete asset detail, classification, location/custodian selection, acceptance/return actions, and filters over protected asset rules.

#### 6. Preserve receiving, GRN, and quality traceability
- Keep PO-led GRN, official receipt numbers, supplier/invoice data, accepted/rejected splits, lots/date codes, location/bin assignment, and idempotency.
- Retain quality hold before released availability and surface the receipt → lot → inspection → issue chain in part and Stores views.
- Add any distinct reel or harness serial identifier only after the traceability contract accepts it; do not overload lot/date code.

#### 7. Deliver in small, accepted backend and interface increments
1. Read-only deployment/schema/permission preflight and released-lot allocation contract, with rollback and concurrency acceptance evidence.
2. Part taxonomy, harness specifications/cross-tags, and project-linked part detail.
3. Project-team recipient contract and controlled issue/return interface.
4. Separate asset classes/subclasses, asset compatibility links, and custody workflow completion.
5. Search, reporting, and operational views after the underlying records and access rules are accepted.

### Verification gates
- Category hierarchy, primary category/cross-tag validation, existing-record backfill, and enclosure/harness discovery.
- Harness project linkage, specifications, stock/lot traceability, substitutes, and compatible asset links.
- GRN/inspection lifecycle: pending, held, accepted, rejected, released availability, and denied allocation from non-released stock.
- Issuance: eligible project-team recipient, multiple approved recipients, removed/inactive/wrong-project denial, quantity/location validation, idempotent replay, partial/full return, and full audit trail.
- Assets: class/subclass validation, separate serialized lifecycle, custody acceptance/return, maintenance/calibration continuity, compatible-part links, and denied unauthorized actions.
- Focused contract tests, type checks, and preview verification before each interface is enabled.

### Technical details and boundary rules
- Current source evidence shows inventory components/categories, component-to-project links, controlled material issue/return, GRN/lots/incoming inspection, and a separate facility-asset/custody model. A live deployment preflight is required before relying on any migration-source contract.
- The current issue flow uses active R&D members; project-team eligibility requires a dedicated server/database contract rather than a client-side filter.
- Source evidence does not yet demonstrate that quality-held lot stock is excluded by every material-issue path; this is a mandatory first release gate.
- Schema, roles, grants, RLS, or migration work will be separately reviewed and applied only with explicit approval. Direct-write restrictions and unrelated Sales/feasibility work remain outside this plan.

## Current delivery status — reconciled 18 October 2026

This status replaces the repeated chronological checkpoints below the budget requirements. Requirements, approved UI decisions, historical commits and detailed evidence remain authoritative in their respective sections/files. Local SQL or DOM success is not managed deployment, client publication or operational acceptance.

| Area | Verified preparation | Remaining gate |
| --- | --- | --- |
| Managed feasibility backend | First 20261017053400 bundle installed with user approval on 17 October through direct Cloud SQL, exact source hash, precommit access checks and independent committed catalog. Five pins, four RPCs and private receipts verified; zero business writes. Managed missing-actor denial passed. The separately approved own-Sales handover reader is installed; committed privacy/null-context checks passed and gated save requires independent matching readback. | Real JWT caller/membership, notification, concurrency/restore and usable UI acceptance remain pending. The specifically approved direct-write restriction was installed and independently verified on 18 October; six SELECT-only policies preserve prior read audiences. No restore was needed. Migration tool history replay is unsafe; no generic db push or automatic history repair. |
| Managed preview | Local package.json/Bun/npm align to verified Vite configuration 2.26.5; unrelated managed auth edits restored through normal history-preserving commits. Local builds pass. | Managed preview failure logs/recovery remain unavailable; lockfile mismatch is not a proven remote root cause. Avoid further managed generation for the completed audit. |
| Shared task integration | DepartmentProjectTasks reuses existing TaskBoard/TaskDialog/records. Canonical department filters apply to reads/cache keys. Member-read denial is explicit and blocks reassignment; unrelated edits preserve assignment. Missing member display joins no longer inflate unassigned counts or imply reassignment. Create/update require returned identity and matching submitted scalar values, then a separate caller-authorized SELECT with matching identity/values; unavailable readback reports uncertain commit without automatic retry. DOM checks cover deadline/identity/status, failed save and Cancel; typecheck/build pass. | The project overview now embeds the existing common TaskBoard in board mode and shares its query cache with overview totals (local source preparation). Department route/authenticated membership/delegation and live member eligibility remain unaccepted. Explicit member/employee identity stewardship, audit binding, receipt readback and withdrawal are prepared and native-tested through 661ba45, but remain owner-private uninstalled proposals; they confer no task authority. Independent readback is prepared and mock-tested locally; managed durable readback remains unverified. No department editing authority or browser persistence is inferred. |
| Private internal notes | Assigned-reviewer exact-source save/read proposals retain versions, optimistic conflicts, replay receipts and metadata-only audit. Caller-bound adapters require separate matching readback. Gated editor is placed in exact-pinned internal cards; deliberate Edit/Save/Cancel preserves uncertain drafts and isolates identity/source state. | Approved own-author note/highlight bundle installed on 17 October; four authenticated-only wrappers, denied direct table/helper access and zero draft rows verified. Gate remains false. Ordinary real-JWT save/readback and live UI persistence remain unaccepted. Own-author access is not shared colleague discovery/delegation or client visibility. |
| Private highlight drafts | Separate version table and own-author save/read RPCs installed with approval on 17 October; adapters and internal editor remain gated. SQL verifies separation from internal notes, replay, clear, caller denial, audit rollback and overlapping saves. Simultaneous editor tests verify independent text, versions, keys and endpoints. | Draft saving is not publication or notification. Gate remains false; client preview never mounts private editors. Recipient/revision-bound publication, scoped resolver, Copy client link and durable client notifications remain pending. Never reuse unsafe invitation binding or copy internal text automatically. |
| Shared analysis accuracy | Recorded assumptions and risks are distinct from independently saved remarks. Example edits remain explicitly memory-only. Approved compact common-board design remains the integration target; the user confirmed the selected compact UI as final on 17 October 2026. | Exact-Master conflict resolution/feasibility pass, recorded client approval, approved baseline lock and separately authorized optional Research/POC or justified Pilot start remain pending. No automatic approval/start. |
| Local SQL acceptance | Portable PostgreSQL 17.11 runs compatibility, atomic handover/replay, root contention, notes/draft caller/rollback/repin/clear and overlapping-save cases. Stronger share locks block overlapping employee/department deactivation, membership deletion and pinned requirement/Master content edits. Loopback PGHOSTADDR overrides inherited addresses; environment is restored. Verified stopped disposable data is removed by default, logs retained; -KeepData is opt-in. | Synthetic roles/helpers are not real JWT/managed caller acceptance. Capability-helper internals, all source writers, target lock ordering and remaining interleavings remain unverified. User has no test account; continue local work without requiring one. |
| Budget and assets | Existing Finance/asset contracts inspected; read-only fictional company/department/project/member trial and charts browser-tested. Paid cash is separate and asset custody is not counted as new expense. | Expense handler lacks verified scoped submission authority; currency/UI and asset allocation gaps remain. No accounting formulas, live budget/expense integration or financial authority accepted. |

### Evidence for reuse

- Managed catalog, authority and restore preparation: docs/evidence/20261016_managed_feasibility_task_authority_audit.md.
- Preview dependency reconciliation and its limits: docs/evidence/20261016_managed_preview_dependency_alignment.md.
- Archive/restore root-lock source and validation limits: docs/evidence/20261017_archive_requirement_root_locks.md.
- Independent task readback and managed sample inspection: docs/evidence/20261017_task_independent_readback.md.
- Task save representation and member-visibility display: docs/evidence/20261016_task_save_representation_verification.md; docs/evidence/20261016_task_assignee_visibility.md. Earlier task/form checks remain in source tests and Git history; do not rerun unchanged checks for reporting alone.
- Overview common-board route integration and UI approval: docs/evidence/20261017_project_overview_common_board.md.
- Shared analysis field meanings: docs/evidence/20261016_shared_analysis_field_meaning.md.
- Internal-note SQL, caller, history, concurrency and mutable prerequisites: docs/evidence/20261016_internal_notes_local_sql.md.
- Internal-note adapters and gated editor: docs/evidence/20261016_internal_notes_adapter_preparation.md; docs/evidence/20261016_gated_own_note_editor.md.
- Highlight draft SQL/caller/concurrency: docs/evidence/20261016_highlight_drafts_local_sql.md.
- Highlight draft adapters and independent editors: docs/evidence/20261016_highlight_draft_adapter_preparation.md; docs/evidence/20261016_gated_highlight_draft_editor.md.
- Disposable PostgreSQL runtime, isolation, resource failures and cleanup: docs/evidence/20261016_windows_local_postgresql_acceptance.md.
- Budget/expense/asset inventory and local chart trial: docs/evidence/20261016_budget_expense_asset_source_inventory.md.

### Source synchronization — 17 October 2026

User authorized full local/GitHub reconciliation. Local acceptance/root-lock commits and origin/lovable-sync through 524b088 are merged with history preserved; 38 focused tests passed, 2 skipped. Full root safeguards and existing plan are retained. Evidence: docs/evidence/20261017_github_local_reconciliation.md. Source sync is separate from managed deployment; pending SQL remains unapplied.

### Active delivery boundaries

Keep the original project/backend and existing labelled sample identities. Continue the agreed feasibility-to-authorized-start flow first; task, budget and reusable-asset work may proceed only where independent. Preserve eight departments, RLS, history, private files and the separate Android queue. Capture a few screenshots only after a visible feature successfully works, clearly distinguishing local trial from live persistence.

Public GitHub egress was explicitly approved by the user on 17 October 2026 for the prepared code, tests and documentation to github.com/narendok/ssmone1. The eleven local commits through e33f160 were pushed normally to main after fetch confirmed no remote-only commits and a clean working tree. This resolves the earlier automatic-review egress gate for this payload. Inspect actual source/remote history before future reconciliation; no force push/reset/deletion of private work. Managed deployment, privileged/access changes, production identities and Publish retain their separate specific approval gates.

### First feasibility backend installation — 17 October 2026

The user approved installation of the first bundle. It is now installed on the original backend via the direct Cloud SQL editor, with exact source hash and precommit checks: five review pins, revision/department uniqueness, four protected RPCs, private replay receipts, intended authenticated/service-role execution and denied anonymous execution/direct private receipt access. Existing graph ACL/RLS/policies remain unchanged. Committed catalog and zero business/receipt counts verified independently. A managed read-only missing-actor role/context test denied all four RPCs; this is not real-JWT ordinary-caller acceptance. Temporary owner-only transport was removed. Evidence: docs/evidence/20261017_first_feasibility_backend_installed.md and docs/evidence/20261017_feasibility_installed_catalog.json.

The generic managed migration tool failed through SQL truncation and unrelated organizations-history replay; direct SQL avoided that path. Do not generic db push, replay the separate 20261017053401 proposal, or edit migration history. History/source deployment alignment remains to be reviewed. All source paths retain historical source-only names/comments; the evidence above records actual installed state.

Concrete installed writer inventory contains only the three protected graph writer routines. No installed sample archive/restore or department remapping was found. Broad authenticated graph writes remain the explicit separate transition. Do not infer a universal gate from hypothetical dynamic privileged writers.

Source/transport details and independent local acceptance remain in docs/evidence/20261017_feasibility_atomic_transport.md. Direct-editor payload passed local PostgreSQL corruption/missing-chunk denial, private-stage access, atomic full installation/cleanup and handover/access acceptance. Local/GitHub source synchronized through 561f2ca before managed installation. The 1054-file managed export previously matched application/SQL/tests/auth/safeguard content; new local evidence/readback work is tracked separately until its next sync.

Next bounded increment: connect reviewer response save to the existing scoped caller receipt reader, requiring immutable requirement/revision/Master/request pins and reporting uncertain commits without retry; keep UI unavailable until caller and workflow acceptance. Continue the previously agreed private remarks/highlights, conflict/pass, client approval/baseline and explicit phase decision order, without auto-approval/start. Android remains separate.

Reviewer response save now requires immutable scope, exact returned identity and separate matching caller receipt readback. Uncertain/denied/malformed results do not retry or report unverified success. 45 focused tests passed, 2 preexisting skipped; typecheck and production build passed. UI gates remain false. Evidence: docs/evidence/20261017_reviewer_response_save_readback.md. The next private own-note/highlight-draft bundle passed default-closed and separate granted-configuration PostgreSQL tests; the user specifically approved its installation. See docs/evidence/20261017_private_review_draft_bundle.md. The exact approved private-draft bundle is now installed on the original backend. Five independent committed catalog checks passed, including zero draft rows, authenticated-only wrappers, denied direct table/helper access and retained first-bundle RPCs. Publication/colleague access/UI activation remain excluded; ordinary real-JWT operational acceptance is still pending.

### Sales handover acknowledgement safeguards — 17 October 2026

The existing gated server action now rejects incomplete/duplicate review acknowledgements against the selected team count and reports uncertain transport outcomes without automatic retry. It retains caller authentication, source/request pins and the unavailable UI gate. Fifteen focused tests, TypeScript and production build passed. This is source integration, not independent persisted readback or live operational acceptance. Evidence: docs/evidence/20261017_sales_handover_acknowledgement.md. Next required work remains scoped handover graph/notification readback and ordinary reviewer acceptance; do not substitute the mutation acknowledgement for either.

### Independent handover graph and notification readback — 17 October 2026

Prepared a default-closed own-Sales reader and separate authenticated-only access proposal, plus a disabled caller adapter. The one-statement reader validates exact enquiry/opportunity/customer/current Master/revision, receipt review pins, current active membership, one stored notification per review and request/source-bound audit. It returns metadata only; notification delivery/read acknowledgement and later direct-write safety are not proven. Twenty-four focused tests, TypeScript, production build and exact-source disposable SQL denial/drift/access tests passed. Evidence: docs/evidence/20261017_sales_handover_independent_readback.md. Neither file is installed; specific new reader-access approval is required. UI remains unavailable; existing writer transition and ordinary real-JWT acceptance remain pending.

### Installed handover reader and active continuation — 17 October 2026

After specific user approval, the exact reader/access files at 14fda15 were installed through the original project Cloud SQL editor. Independent committed catalog/privacy/null-context checks all passed; handover receipt count remains zero. The gated save path now requires separate matching caller readback, withholding success on missing/denied/lost/contradictory evidence without mutation retry. Thirty focused tests, TypeScript and production build passed. Evidence: docs/evidence/20261017_handover_reader_backend_installed.md and adjacent CSV/screenshot. Earlier source-only entries describe historical preparation; this entry records current installation. No real-JWT operational acceptance, notification delivery, UI activation or direct-write restriction is claimed.

User requested continuation with scheduler active. Thread heartbeat continue-ssm-one-portal-delivery is ACTIVE at a 30-minute interval, covering remaining agreed master-plan phases and existing approval boundaries, quiet on unchanged/non-actionable state. Continue ordinary caller acceptance/compatibility and the existing protected workflow order; no repeat design choice, duplicate fixtures, auto-approval/start or Publish. No new production users. Android remains separate.

### All-review readiness conflict guard — 17 October 2026

Read-only baseline composition now inspects every matching workstream review rather than the first, so a positive result cannot hide a negative or pending peer. Empty required scope is unavailable, and distinct blockers are retained without duplicate text. Twenty focused tests, TypeScript and production build passed. Existing BaselineDialog still fails closed on missing immutable source verification; approval remains false. No persisted conflict resolution, UI activation, client approval or baseline lock is claimed. Evidence: docs/evidence/20261017_all_review_readiness.md. The status table now reflects previously verified installations while retaining outstanding real-JWT/operational gates.

### Governed Smart BOM, Adaptive Purchase/Invoice Ingestion, and Asset Lifecycle Plan — 18 October 2026

Refined the BOM and purchase-import architecture to fulfill multi-stage engineering, enterprise asset governance, and arbitrary document ingestion:
1. **Dual-Lifecycle BOM Architecture**:
   - **Tentative BOM**: Engineering/feasibility draft permitting provisional MPNs, unverified candidate components, generic placeholders, and live stock "what-if" shortage simulations without claiming reservations.
   - **Released BOM**: Formally locked revision (Rev A, Rev B, etc.) bound to an approved baseline, requiring qualified catalog items, immutable without an authorized Engineering Change Order (ECO).
   - Multi-format exports: Indented BOM, Flattened Production BOM with aggregated reference designators, and Procurement Shortage Requisitions.
2. **Adaptive Purchase Order & Invoice Ingestion Engine**:
   - Ingests arbitrary/random spreadsheet layouts (CSV, Excel) from any supplier/distributor via fuzzy column matching with extensive alias dictionaries.
   - Leverages AI document extraction for PDF and image invoices to parse supplier, invoice, and line-item structures.
   - Interactive preview mapper with confidence scores (`High`, `Low`, `Unmapped`) and inline correction before processing.
3. **Governed Pre-Inventory Review Gate**:
   - Mandatory staging workspace reconciling vendor identities against `procurement.vendors`, normalizing MPNs against the component catalog, and detecting quantity/price variances against existing POs.
   - Human review actions (Accept, Reject/Ignore, Remap, Split) before generating drafts.
   - Accepted lines create grouped Purchase Drafts or Inwarding (GRN) drafts only.
4. **Controlled Receiving Boundary**:
   - Absolute separation between import and active stock: zero inventory is added directly from an import.
   - Material flows strictly through Stores Inwarding -> Inspection Lot (QC Hold) -> Quality Release before becoming issueable.
5. **Asset Register Import, Export & Compatibility**:
   - Bulk CSV/Excel onboarding and export for Production Machinery, Service Equipment, and IMTE/Calibration instruments.
   - Connects machine-to-component compatibility mappings (`compatible_component_ids`) distinct from custody assignments.


### Interrupted department projection recovered — 18 October 2026

Reconciled current user/Lovable inventory/BOM/asset source through ca780f5 without history rewrite. Repaired the canonical department page member projection type using verified rd_members.department_id; four DOM tests passed at their moved, non-route test location. Full compilation also exposed two newly synced BOM issues: an unclosed Save Dialog and an array-returning fetchProjectBoms caller incorrectly reading res.boms. Minimal repairs preserve the new BOM behavior. TypeScript and production build passed. Evidence: docs/evidence/20261018_department_projection_recovery.md. This is source/compile recovery; ordinary caller browser acceptance, delegated department editing, feasibility UI and remaining lifecycle gates stay pending. No managed SQL, grants, business records or Publish changed.

### Legacy project-start bypass closed in source — 18 October 2026

The old initiateSalesHandover action independently upserted a handover, marked a baseline project_initiated and wrote an audit without an accepted atomic start contract. It now retains authentication/Sales permission checks and fails closed without table operations; HandoverDialog displays the pending-contract reason and disables its submit. This prevents this facade bypassing recorded client approval, locked baseline and explicit Research/POC or justified Pilot decision. It does not change RLS/grants or prove direct-write denial. Thirty-eight focused tests passed, two existing skips; TypeScript and production build passed. Evidence: docs/evidence/20261018_project_handover_facade_gate.md. No live browser acceptance, project start or managed SQL. Assignment readback remains queued after the protected handover/ordinary-caller acceptance work; no action was auto-approved or started.

### Reviewer assignment persisted readback — 18 October 2026

Existing authenticated/Sales-authorized assignment now requires separate caller-visible SELECT matching returned ID, requirement, department, reviewer, pending status and complete revision/Master pins before reporting success. Unknown/lost mutation or unavailable/mismatched readback is uncertain and never automatically retried. Fifty focused tests passed, two existing skips; TypeScript and production build passed. Evidence: docs/evidence/20261018_feasibility_assignment_readback.md. This is matching stored scalar/provenance completeness, not expected-source concurrency, notification delivery or ordinary real-JWT acceptance; the UI remains gated and no backend access changed.

Next priority: reconcile the original-target direct-write compatibility/restore capture and remaining actual caller evidence for the installed handover flow. Do not rerun already installed bundles or replace operational acceptance with further source-only safeguards. Persisted conflicts/pass/client approval/baseline and explicit phase decision remain pending.

### Original-target runtime-write restriction review — 18 October 2026

Fresh read-only metadata confirms the protected routines remain installed but all three graph tables retain anon/authenticated I/U/D/TRUNCATE grants and broad Sales-manage ALL policies. Review exposed two gaps in the old proposal: TRUNCATE was not revoked, and dropping ALL policies could narrow SELECT for manage-only callers. The new atomic review file preserves original read predicates as SELECT-only and removes I/U/D/TRUNCATE, with a capture-bound guarded restore draft. Disposable exact-package/restore tests passed, including isolated Sales-manage-only reads and inherited privilege checks. No TRUNCATE operation or managed access change occurred. Evidence: docs/evidence/20261018_feasibility_runtime_write_boundary_review.md and adjacent raw/parsed catalog capture. Specific limited installation/rollback approval remains required; ordinary real-JWT caller acceptance and UI activation stay pending. Do not apply the earlier I/U/D-only proposal on its own.

### Approved restriction installed — 18 October 2026

The user specifically approved restriction and conditional restore at commit 19124c21a273ab29a119abda2faebe8c41e7396f. The exact pinned atomic SQL was loaded through the original Lovable Cloud SQL editor; clipboard equality verified the full payload. Execution returned Query succeeded. No restore was needed or run.

Independent post-install catalog comparison passed: direct INSERT/UPDATE/DELETE/TRUNCATE denied for anon/authenticated on all three graph tables; six SELECT-only policies retain the original predicates/read audiences. Owners, RLS, force-RLS, column ACLs, constraints and triggers match pre-install. All other captured grants, including service_role, remain unchanged. Five protected RPC bodies, owners, definer settings, search paths and execution ACLs match the capture. No business records or users were modified. TRUNCATE was never executed.

Evidence: 20261018_feasibility_graph_postinstall_catalog.csv/.json and 20261018_feasibility_runtime_boundary_installed.jpg. SQL verification returned FEASIBILITY_RUNTIME_WRITE_BOUNDARY_INSTALLED_PASS, three protected tables, six SELECT policies, RLS retained and runtime writes denied. This is managed catalog/privilege verification, not ordinary real-JWT operational acceptance. UI activation and ordinary-user positive/denied workflow acceptance remain pending.

### Common project analysis route integration — 18 October 2026

The user reiterated that the previously approved compact analysis UI must be completed, including department editing and basic internal/client projections. The requirement remains in the approved UI baseline and department project management sections; no new layout selection is needed.

A bounded internal read integration now places ProjectAnalysisSummary at the top of the existing project overview: linked baseline/handover context, recorded phase/health/priority, visible blocked tasks, next open work ordered by due date, and collapsed canonical department/task summaries. It uses the same project_tasks query key and fetchTasks contract as the existing common TaskBoard. Canonical department_id alone controls grouping; legacy department labels never confer scope. Failed reads show unavailable rather than zero work. No sample records, parallel task table, private remark reads, client publication, new edit grants or managed SQL were introduced.

Three DOM tests passed for canonical ID grouping despite contradictory labels, denied reads, and unclassified task handling. TypeScript passed. Production build verification is being recorded separately below. This is local source preparation, not managed browser acceptance or completion of the full approved design. Remaining: exact design composition/reference and dependency contracts, verified department membership/delegated editing, durable remarks/highlights integration, and an accepted opportunity/client/revision publication resolver. Existing task editing remains subject to backend RLS; no department authority or client access is inferred from this summary.

Validation result: production build passed for the bounded common analysis read integration; department editing and client publication remain pending as described above.

### Managed common-analysis preview and department authority preflight — 18 October 2026

Verified e08b7a0 in the original Lovable managed preview using the existing Platform Owner session and labelled PROJECT-2026-0005 (1e021716-d499-4933-b1cf-48631688344e). Common analysis loaded the existing three project tasks, eight canonical department summaries, current phase/health/priority, missing-baseline state and next open work. Hardware & R&D disclosure expanded to the same three stored tasks. This verifies managed rendering/read integration only, not department-member editing, client access, baseline approval, or durable mutation acceptance. Existing task titles mention HR/procurement but their stored canonical department IDs group them under Hardware; no data was changed or reclassified from titles. Evidence: 20261018_common_analysis_managed_preview.png.

Fresh original-target catalog-only inspection (read-only transaction, rolled back; no business rows/DDL/grants changed) confirms project_tasks RLS enabled with a projects.manage ALL policy and projects.view/projects.manage SELECT policy, PLUS legacy tasks_insert requiring only created_by=auth.uid() and tasks_delete allowing creator/admin/project_manager. Consequently projects.manage-only source assumptions are incomplete: adding a client filter or hiding controls is not a verified department write boundary. No department-scoped task mutation RPC appears in this captured task-named routine inventory. Metadata cannot exclude dynamic SQL or non-task-named routines; broader inspection remains necessary. The existing lifecycle_can_manage_department helper combines Drive department access and broad management/document capabilities and is not a proven task delegation contract.

The captured project_team_members table and employee/rd_member identities must be reconciled before an actor-to-employee-to-project/department task capability resolver is designed. Keep existing task records and IDs, exact statuses, priority and due_date; new protected create/update authority must validate current actor, active membership, explicit existing capability/delegation, project/department/assignee eligibility and permitted fields on the server, then require affected-row representation plus independent caller readback. Do not invent a department role grant or widen access by interpreting membership alone. Reassignment/removal races and retained legacy direct-write policies require explicit transition/restore testing before any specific approval request. Client projection remains separately publication/revision scoped. Catalog evidence: 20261018_project_task_authority_catalog.csv/.json.

No application change this checkpoint; prior three DOM tests/typecheck/build remain relevant and were not repeated unchanged. Remaining approved UI/workflow scope is still active, with managed authority evidence now replacing source-only assumptions. No test users, new sample records, live task writes, permissions or Publish.

### Basic common-project task view — 18 October 2026

Prepared an explicit readOnly presentation mode in the existing TaskBoard, and applied it to the common project overview board. The same caller-visible task query/cache/records remain in use. Basic view keeps filters, status columns, assignment/priority/date details and a read-only task dialog, while omitting creation/editing drawers/forms and disabling drag/drop mutation handlers. No client projection is inferred; this remains an internal RLS-authorized view. Existing full Tasks tab behavior remains unchanged and still depends on backend authority. This presentation mode is not an authorization boundary and does not remediate the captured legacy task policies.

Ten focused TaskBoard DOM tests passed using one threads worker. The first attempt timed out before a forks worker started (zero tests), then the focused retry passed. TypeScript passed before the production build started. Build completion is recorded below. Department-delegated editing, private remarks/shared reads and exact client publication/resolver remain pending; no new permission, SQL, business rows or Publish. No managed-browser acceptance is claimed for this increment until the synced build is inspected.

Basic task view validation completed: ten focused DOM tests, TypeScript and production rebuild passed after correcting a new dialog separator encoding. Source-only until managed preview verification; no department edit authority or client publication acceptance.

### Basic task managed preview verification — 18 October 2026

Verified fe6b93f after the original Lovable preview switched from static to live and completed workspace loading. Existing labelled PROJECT-2026-0005 displays Read-only task view and zero New task buttons in its common overview. Opening the existing SAMPLE ONLY hardware review task shows its stored description, To do status, high priority, Unassigned state and missing due date in Read-only internal task details. Closed the dialog without mutation. Screenshot: docs/evidence/20261018_basic_task_managed_preview.png. This is Platform Owner session rendering/read evidence, not ordinary department/client access or backend write denial.

Department assignment contract inspection confirms project_tasks.assignee_id joins rd_members, whereas project_team_members.employee_id joins employees. The captured rd_members columns contain no employee_id/user_id relation. Do not infer an identity bridge from matching free-text names or email, and do not reinterpret task assignee IDs as employee IDs. Before enabling project-team-only assignment, inspect accepted FK/helper/identity contracts and, if absent, prepare an explicit auditable mapping proposal with ambiguity/backfill/disabled-membership handling for separate review. employee_departments is the existing membership relation seen in migration source; its installed schema/policies and delegation support still require targeted verification. This dependency blocks only delegated assignment/edit authority; basic common reads remain available. Client publication and shared remarks remain separate outstanding contracts. No grants, migrations, sample rows or production users changed; no unchanged tests repeated.

### Managed identity/delegation inspection — 18 October 2026

Used one bounded read-only Lovable inspection in the original project for the concrete missing task-assignee identity bridge. Explicitly prohibited implementation, migrations, grants/policies, users/fixtures, file/plan edits and Publish. Lovable reports no installed rd_members-to-employees FK/mapping and no department-scoped task edit RPC/delegation. Its catalog findings agree with the independently captured rd_members columns and task-policy metadata. Source independently confirms project_task_notification_recipient(uuid) joins lower(employees.official_email)=lower(rd_members.email), orders employees.created_at and LIMIT 1; this heuristic is notification routing, not assignment authority.

Membership report: employee_departments uses employee_id/department_id with is_primary/created_at and no active/revoked state; project_team_members has project_id/employee_id, is_lead/project_role/access_level and no active/revoked state. Source types confirm those fields and employee FKs; Lovable additionally reports composite uniqueness and cascading FK behavior. Treat the additional catalog assertions as Lovable-reported until an independent metadata capture includes them. Presence plus current ACTIVE employment is the proposed effective-membership prerequisite; never infer historical revocation evidence or authority from free-text project_role/access_level alone. No broad inference of absence of dynamic/non-task-named authority is claimed.

GitHub reconciled normally after inspection: main unchanged at 3fea08c with no new Lovable source commits. No business records, roles, access or pending plans changed. No unchanged tests or screenshots repeated.

Next bounded implementation preparation: an explicit steward-reviewed rd_member/employee identity bridge preserving existing assignee IDs and history, no name/email auto-backfill, followed by a protected task capability/write contract validating active employee, exact project/department membership, explicit permission/delegation, eligible assignee and allowed fields. Capture original constraints/grants/policies and test restriction/restore/concurrency before seeking specific installation approval. Do not enable department editing from the email helper or existing broad/legacy task policies. Common/basic reads continue; shared remarks and client publication remain separately gated.

### Private task-member identity proposal — 18 October 2026

Prepared supabase/pending/20261018_task_member_identity_private_review_only.sql, NOT INSTALLED. This review proposal adds a separate owner-private identity-version relation referencing existing rd_members and employees; it preserves project_tasks.assignee_id and existing history. It performs zero backfill and never matches names/emails. It proposes one current link per member and employee, permits later versions after explicit revocation, requires an existing verifying actor and reason, and uses restrictive FKs to retain source identities. The proposed one-to-one semantics and effects on future employee/member deletion require review; they are not approved standards. No app-role schema/table access, mapping-management RPC, task delegation, notification remapping or UI activation is introduced. Existing owner/admin policy and audit behavior are not claimed to become immutable from this table alone.

Exact SQL executed in an isolated in-memory PGlite 0.5.10 / PostgreSQL 18.6 runtime: no initial mappings, duplicate current member/employee links denied, missing references denied, referenced-member deletion denied, revoked identity row retained alongside a new current row, RLS enabled, schema/table privileges denied and actual SELECT attempts denied for anon/authenticated/service_role. First fixture expected 23503 for restrictive deletion but PG18 returns 23001; test now accepts those documented integrity-violation variants without weakening success assertions. Test: supabase/pending/tests/task_member_identity_private_local.mjs (supply local PGlite module path). PASS marker TASK_IDENTITY_PRIVATE_PROPOSAL_LOCAL_PASS. Runtime fetched into temp only from npm with SHA-512 registry integrity verified; no portal package dependency changed. Evidence log: 20261018_task_identity_private_local.txt.

Limits: WASM PG18 is not the previous native PG17 harness or original managed acceptance. Native target-version syntax/behavior, exact installed prerequisites/catalog guards, transaction rollback/concurrency, approved identity stewardship, protected mapping audit/replay, old-writer compatibility/restore, and a department/project-scoped task capability/write contract remain required before an installation request. No permission approval is requested for this incomplete package and nothing is installed. No application change, so unchanged application tests/build were not repeated. Basic/common reads remain available. Client publication and private remarks access remain separate gates.

### Private identity proposal guarded install/rollback checks — 18 October 2026

The uninstalled identity proposal now rejects an existing identity schema, missing source tables, non-owner execution, disabled source RLS and non-UUID source IDs before creating objects. A postflight rejects retained application-role schema/table privileges and unexpected backfill. It still adds no callable mapping/write interface and changes no managed objects.

Exact updated SQL passed the earlier isolated link/history/access checks and new missing-source, disabled-RLS and late incompatible actor-FK failure fixtures. Each rejected transaction was rolled back and independently checked for absence of the private schema. The late failure occurs after schema creation, proving transactional cleanup in this PGlite/PostgreSQL 18 fixture rather than just an early guard. Evidence: 20261018_task_identity_guard_local.txt; marker TASK_IDENTITY_INSTALL_GUARDS_LOCAL_PASS. No native target-version, managed caller/concurrency, deployment, identity approval or department editing acceptance is inferred. Tests are synthetic and in-memory; no business data/users changed. No unchanged application build/tests repeated. Target-version validation, protected steward mapping/audit/replay and department-scoped task writes remain pending before installation approval can be requested.

### Private identity stewardship transaction proposal — 18 October 2026

Prepared supabase/pending/20261018_task_identity_steward_transaction_review_only.sql, NOT INSTALLED. The proposed function is owner-private with all PUBLIC/anon/authenticated/service_role execution denied; no public adapter, UI or application grant exists. It proposes requiring the existing admin role plus exactly one ACTIVE actor employee, an active canonical R&D member, ACTIVE target employee and present employee_departments row before request replay or mutation. This is proposed identity stewardship, not ordinary department editing authority or an approved new role standard.

Mappings use explicit IDs, expected current version and actor/request-key payload receipts. Global advisory serialization is proposed for this low-volume private stewardship operation; source employee/member/membership rows are held with SHARE locks. Rebinding revokes the prior version and inserts the replacement plus private receipt in one function call. Superseded receipts cannot replay as current; missing/removed scope is checked before replay. Existing task assignee IDs remain unchanged. No automatic identity matching/backfill or task permission is introduced. The private receipt/history is not a replacement for accepted company audit or independent caller readback.

Exact proposal SQL compiled and executed in synthetic PGlite 0.5.10/PostgreSQL 18.6 fixtures. Passed missing actor/non-steward denial, exact replay, changed reason conflict, removed-membership replay denial, inactive actor replay denial, duplicate employee mapping denial, expected-version conflict, superseded receipt denial, retained prior version and denied app execution. Injected receipt INSERT failure rolled back a rebind, leaving the original current mapping intact. Test: supabase/pending/tests/task_identity_steward_local.mjs; evidence 20261018_task_identity_steward_local.txt, marker TASK_IDENTITY_STEWARD_LOCAL_PASS. Native target-version, actual JWT/membership-policy acceptance, independent readback and true multi-connection concurrency remain unverified. No application tests/build repeated for this SQL-only proposal.

Before requesting installation: independently verify installed membership/key/helper prerequisites, review stewardship/one-to-one semantics, add exact deployment guards and protected audit/readback/revoke paths, test native target-version concurrency and legacy-writer compatibility, and compose the separate department/task capability contract. No new schema/permission installation approval is requested for this incomplete package. No managed SQL, identities, records or Publish changed.

### Native PostgreSQL 17 identity proposal validation — 18 October 2026

Restored a temporary native test runtime from @embedded-postgres/windows-x64 17.10.0-beta.17, verifying the npm registry SHA-512 archive integrity; executable reports PostgreSQL 17.10. This is a local third-party packaged runtime, not managed backend verification or proof of matching its exact minor/build. No package scripts ran and no application dependencies changed. A fresh disposable cluster used loopback-only binding, randomized port, SCRAM credentials and synthetic fixtures; runner stops the server and removes the temporary password in finally.

Exact private identity/steward proposal files passed the authority, replay, payload-conflict, removed-membership/inactive-actor denial, expected-version, superseded-receipt, injected-receipt rollback, history and denied-app-execution tests on native PG17.10. A separate two-connection test independently observed the second request waiting on the advisory lock, then verified equal result versions and exactly one actor/request receipt after commit. This establishes only overlapping same-key replay serialization. It does not establish role/membership revocation races, changed-payload overlap, different-member employee conflicts, managed JWT/RLS behavior or general concurrency acceptance. Evidence: 20261018_task_identity_native17_acceptance.txt and 20261018_task_identity_native17_overlap.txt. Test runner: supabase/pending/tests/run_task_identity_native_windows.ps1; native adapter uses existing local postgres library, accepts fixture configuration only and hardcodes loopback.

The package remains UNINSTALLED/owner-private. Before any installation request, finish deployment prerequisite guards for the steward layer, recheck role authority after queued locks, protected audit/readback/revocation and role/membership race coverage, plus original-target compatibility and the separate department task capability contract. No managed data, identity mapping, permissions, test users or Publish changed. No unchanged application build/tests repeated.

### Queued steward-role revocation regression — 18 October 2026

Native PostgreSQL 17.10 two-connection regression reproduced a real gap in the uninstalled draft: request B passed the initial role check then waited on request A's advisory lock; a third connection removed the synthetic steward role, yet B replayed A's receipt. Preserved failing evidence: 20261018_task_identity_role_race_reproduced.txt. No live authority or business record was involved.

record_mapping now rechecks public.has_role(actor,admin) immediately after acquiring the lock, before actor/source scope checks and receipt lookup. The same exact blocking test now denies B after the role removal; observed pg_locks independently confirms B was queued before removal. Fixed evidence: 20261018_task_identity_role_race_fixed.txt; marker TASK_IDENTITY_NATIVE_ROLE_REVOCATION_PASS. Native same-key overlap/replay and baseline private transaction acceptance also passed again on a fresh disposable cluster, which was stopped and its password removed by the runner. Fixture role helper now reads a mutable synthetic role table, rather than a constant identity predicate.

This proves only the tested queued-role revocation scenario; general membership/assignee races, permission-transaction ordering, changed-payload overlap and managed JWT/actual has_role implementation acceptance remain separate. Proposal stays owner-private, no application execution grants or installation, no task editing activation. Deployment guards, protected audit/readback/revoke and original-target transition remain pending. No unchanged application tests/build repeated.

### Private mapping receipt readback and withdrawal — 18 October 2026

Prepared 20261018_task_identity_readback_revoke_review_only.sql, NOT INSTALLED. Owner-private read_mapping_receipt independently joins an own-actor request to the exact member/employee/current version and rechecks current admin stewardship, exactly one ACTIVE actor employee, active target/member and current department membership in one stable statement. Wrong actor/source/version, removed membership and revoked/superseded mappings yield no receipt. This is mapping metadata only, not task capability or client publication.

Owner-private revoke_mapping requires current admin role after the same global advisory lock, an ACTIVE actor employee, explicit exact current member/version, reason and request key. It retains history and writes a private revocation receipt atomically, supports exact replay, and rejects changed payloads. Withdrawal deliberately remains possible when the target employee becomes inactive or loses membership; current steward authority is required, but stale subject eligibility must not prevent removing a link. No delete, app execution grant, public wrapper or UI is added.

Native PostgreSQL 17.10 exact-source checks passed: independent current readback; wrong actor/source/stale and removed-membership read denial; non-steward revoke denial; inactive-subject withdrawal; revocation replay/conflict; revoked mapping remains unreadable after subject reactivation; and injected revocation receipt failure rolls back withdrawal so the prior current receipt remains readable. Existing native mapping/replay/role-race overlap tests also passed. Evidence: 20261018_task_identity_readback_revoke_native17.txt. Test assertion was strengthened to reactivate the target before checking revoked-read denial, avoiding a false positive from inactive status; final native run uses the strengthened assertion.

Limits: still synthetic native fixtures, no managed JWT/actual policy acceptance, no company activity_log audit integration, no independent revocation-receipt reader, no full deployment prerequisites/restore or department task write contract. New private receipt/history tables are not claimed as accepted company audit or protected against owner changes. Before installation approval, complete these remaining contracts and role/member/assignee race coverage. No managed data/schema/permissions changed and no unchanged application tests/build repeated.

### Exact company-audit binding — local checkpoint, 18 October 2026

Fresh original-project catalog-only capture verifies managed server_version 17.6, activity_log columns/policies, employee_departments PK/FKs, project_team_members uniqueness/FKs and has_role reading public.user_roles. Transaction read-only/rolled back; no business rows selected. Local evidence: 20261018_audit_membership_catalog.csv/.json. Native PostgreSQL 17.10 tests are same-major, not exact managed minor/build acceptance.

Audit SELECT is admin-only, but authenticated INSERT checks only actor_user_id=auth.uid(). Uninstalled mapping/revocation proposals now pin actual inserted activity_log UUIDs in private receipts (UNIQUE restrictive FK); replay/readers require exact audit ID, actor/module/entity/action and canonical request/source/version JSON. No private reason text, name or email is copied into the audit payload. Existing audit grants/policies/audience unchanged. Added owner-private independent revocation readback. All application execution remains denied; nothing installed or UI-enabled.

Native tests passed duplicate audit text without substitution, altered pinned audit read/replay denial, actor-scoped withdrawal readback, no orphan audit after receipt failure, and injected audit failure rollback for mapping and withdrawal. Previous native replay/role-race/readback tests passed again. Log: 20261018_task_identity_audit_native17.txt. Managed JWT/RLS, deployment guards/restore, broader membership races and department task editing remain pending. No unchanged app tests/build or screenshots repeated.

Publication status: LOCAL ONLY. Automatic approval review rejected the proposed GitHub upload of backend authorization/membership metadata and internal audit evidence with direct main/lovable-sync updates, requiring specific user approval for that egress/branch update. No publication workaround attempted. Earlier synced checkpoint remains fff7ce9. Preserve these local files for review and continue unaffected work within existing authorization.

### Delayed-transaction chronology and source-sync approval — 18 October 2026

The user explicitly approved GitHub source/evidence upload to narendok/ssmone1 main and lovable-sync, resolving the earlier automatic-review egress gate. This authorizes source sync only; the identity proposal remains NOT INSTALLED and application execution denied.

Mapping transitions now capture clock_timestamp after serialization and use that same value for the old version withdrawal and new version verification. A native PostgreSQL 17.10 two-connection regression establishes an older open transaction, commits a newer mapping from another connection, then successfully rebinds it from the older transaction with ordered history. Existing audit binding, atomic failure rollback, independent receipt reads, same-key overlap and queued-role denial checks also passed. Evidence: 20261018_task_identity_chronology_native17.txt. This remains synthetic local acceptance; managed JWT/RLS, broader membership races, deployment prerequisites/restore and department task editing are pending. No managed changes, screenshots or unchanged application builds were performed.

### Queued department-membership removal regression — 18 October 2026

Native PostgreSQL 17.10 synthetic three-connection verification independently held the stewardship advisory lock, observed a mapping request waiting, removed the target employee department membership, and released the lock. The resumed request denied the missing membership and wrote no request receipt. Prior chronology, queued-role, same-key replay, audit binding and atomic rollback checks passed in the same fresh fixture. Evidence: 20261018_task_identity_membership_race_native17.txt. No SQL behavior change was needed. This proves the specific removal-before-resume case, not all membership/permission transaction orderings or managed JWT/RLS acceptance. Server stopped and temporary password removed by the runner.

Proposal remains NOT INSTALLED, with app execution denied and department editing pending. Deployment prerequisite/restore coverage and actual identity acceptance remain outstanding. Source/evidence sync uses the user's approved GitHub destination and branches; no business rows, credentials, managed data or permissions changed. Existing unrelated demo screenshots preserved untracked.

### Steward prerequisite guards — 18 October 2026

The uninstalled steward bundle now rejects missing private identity prerequisites, source tables without expected ownership/RLS, mismatched referenced UUID/text/JSON/boolean columns, changed employee-department composite primary key and a role helper without the captured boolean/stable/security-definer shape. These structural checks do not establish helper semantics, policy correctness or full target compatibility.

Exact SQL passed native PostgreSQL 17.10 positive fixtures. Four transactional negative fixtures independently changed activity RLS, audit actor column type, membership primary key and role-helper security mode; each was denied before a mapping request table existed and rolled back. Prior audit atomicity/readback and concurrency regressions passed. Evidence: 20261018_task_identity_steward_preflight_native17.txt. Fixture helper and source RLS shape were aligned with captured structural prerequisites; no actual managed authorization acceptance is claimed.

Still NOT INSTALLED; no app grant/UI activation or managed change. Full deployment/restore review, role-helper semantic verification, broader races and real caller acceptance remain pending. SQL-only increment: no unchanged UI tests/build or screenshots repeated. Source and synthetic evidence use the explicitly approved GitHub sync destination.

### Unverified peer readiness correction — 18 October 2026

Read-only baseline composition previously filtered reviews by verified workstream applicability. A stale/unpinned/unknown-scope peer carries no verified applicability, so it could disappear while a positive matching review produced READY. The composer now adds a blocker whenever any supplied review lacks verified applicability. It never enables approval (canApprove remains false). Immutable pinned Master history remains valid independently of a mutable header advancing; that existing behavior was preserved.

Twenty-three focused tests passed, including stale, unpinned and unknown-scope peers in both orders; TypeScript no-emit passed. Production Vite/Nitro build passed (exit 0); existing deprecation/module-directive warnings remain. No backend grants/data, live approval/start or UI activation changed. This is source-level gate validation, not managed caller/browser workflow acceptance. No pending-work screenshot was captured.

### Baseline/commercial catalog checkpoint — 18 October 2026

Fresh original-target metadata-only inspection confirms baseline INSERT remains broad Sales-manage/admin, and commercial authorization is a mutable unpinned row. No public function named for baseline/commercial/conflict was found (limited inventory, not proof of universal absence). Exact revision/Master conflict resolution, client consent receipt and protected baseline lock remain required; approval stays disabled. Technical findings and raw/parsed metadata are local in docs/evidence/20261018_baseline_contract_inspection.md and adjacent catalog files. No backend writes, privileges, business rows, plan activation or Publish changed. Managed build history still labels recent imports unsuccessful/out of date; no failure logs/root cause obtained, so local build success is not claimed as managed deployment.

### Exact immutable Master version-number readiness — 18 October 2026

Read-only planning now compares both the pinned Master UUID and the immutable source version number, rejecting missing/invalid source numbers and mismatched review numbers. The source field is derived from requirement_data.source, not a new database column. Mutable Master header advancement remains compatible with an exact historical pin. Thirty-one focused tests, TypeScript and production build passed. Evidence: docs/evidence/20261018_exact_master_number_readiness.md. No backend writes, approvals, phase starts or live UI activation; managed workflow acceptance and the final common/department/client views remain pending. Baseline metadata exports stay local and are excluded from this source sync.

### Managed preview diagnosis follow-up — 18 October 2026

Browser control recovered and the original project now selects the latest readiness commit with its sign-in page rendered. This is auth-shell rendering only, not authenticated feature acceptance. Lovable reports managed failure logs unavailable and made no source/backend changes. Independent comparison finds npm/installed Vite 8.3.4 versus Bun-locked 8.0.16; config 2.26.5 remains aligned. Resolution drift is verified, causation is not; no blind dependency change or managed generation was requested. Evidence: docs/evidence/20261018_managed_preview_diagnosis_followup.md. No unchanged build/test rerun, fixture, credentials, SQL, access change or Publish.

## Workspace names — 18 October 2026

Web product: **SSMone**. Android application/display name: **SSMone-App**. Preferred workspace entry paths:
- Web: `C:/Users/Admin/AndroidStudioProjects/SSMone/SSMone-Web`
- Android: `C:/Users/Admin/AndroidStudioProjects/SSMone/SSMone-App`

Both SSMone-Web and SSMone-App are actual physical directories under C:/Users/Admin/AndroidStudioProjects/SSMone, with separate Git repositories and histories. Neither entry is a junction or duplicate checkout; this parent is not a monorepo. The former SSMOneWeb and SSMApplication3 roots no longer exist. Preserve historical backups, application/package identity, backend/project IDs and official document names. Use these physical workspace paths for new Studio/Antigravity sessions and schedulers.

### SSMone authenticated common-view read checkpoint — 18 October 2026

An existing Platform Owner session now renders the renamed app and labelled PROJECT-2026-0005. Common analysis and common read-only TaskBoard show the same three tasks, recorded metadata, priorities/statuses and explicit missing baseline. Read-only navigation only; no mutation or new fixture. Evidence: docs/evidence/20261018_ssmone_common_view_read_checkpoint.md. This resolves the immediate authenticated rendering check, not ordinary department authorization, durable remarks, client link/publication, baseline approval or full final-design integration. No unchanged screenshot/build/test repeated.

### Common recorded project context — 18 October 2026

Added existing project type/revision/design reference to the common analysis without inventing a description, creating data or enabling editing/publication. Nine focused DOM tests, typecheck and production build passed. Design URLs are limited to absolute HTTP(S) without embedded credentials. Evidence: docs/evidence/20261018_common_recorded_project_context.md. Vitest requires physical-root cwd due an observed junction collection mismatch; AGENTS.md records the workaround. Original managed preview now renders this context for existing PROJECT-2026-0005 after Update preview/Refresh, using Platform Owner read access. Screenshot capture was unavailable; broader department/client workflow gates remain unchanged.

### Atomic private identity installation unit — 18 October 2026

The three review drafts each owned a transaction, so they were not a safe all-or-nothing installation unit. Added a deterministic single-transaction review bundle with LF-normalized source hashes and whole-bundle postflight for table/function inventory, ownership/RLS, denied application access and zero backfill. Original drafts are preserved as inputs, not separately installable pieces of this package. Exact-source drift check and injected exception before final COMMIT verified full schema rollback/no business audit; normal install and repeat-install denial passed with all prior native authority/audit/history/concurrency regressions. Initial injection-harness quoting error was corrected before the passing native PG17.10 run. Evidence: docs/evidence/20261018_task_identity_atomic_bundle_native17.txt.

Still NOT INSTALLED; no new approval requested for this incomplete overall task-editing package. Contract/recovery boundaries: supabase/pending/20261018_task_identity_private_bundle_contract.md. Fresh target compatibility, helper semantics, stewardship review and separate department task write authority remain pending. No managed SQL, app permission, data, UI activation, screenshot or unchanged app build/test.
