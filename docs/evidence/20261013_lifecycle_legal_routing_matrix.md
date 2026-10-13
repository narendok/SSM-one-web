# Lifecycle document routing — Legal clarification matrix

**Status:** source-only catalog correction. This evidence does not create a department, person assignment, Drive location, register, revision, grant, policy, or deployment.

## Existing department evidence and source routing

The application source uses the following existing department codes. The prior read-only department evidence identified the active department records for Sales, Hardware & R&D, Production, Finance, and HR; this source correction deliberately does not infer or query an Operations / Legal record identifier.

| Template | Default responsible department | Existing source identifier evidence | Source scope | Current document-access state |
|---|---|---|---|---|
| Statement of Requirements | Sales (`SAL`) | Sales ID observed in prior read-only evidence (`db21…`) | Sales opportunity | SOR is one of the two reviewed Sales DOCX kinds; Save remains deployment-gated. |
| NDA review | Operations / Legal (`OPS`) | No Operations / Legal ID is asserted or created here | Sales opportunity | Legal responsible person must be explicitly assigned. Sales may initiate an NDA gate but receives no Legal read/edit grant. Local export only. |
| Commercial quotation | Sales (`SAL`) | Sales ID observed (`db21…`) | Sales opportunity | Local export only; current responsible person required. |
| Contract Review | Sales (`SAL`) | Sales ID observed (`db21…`) | Sales opportunity | Interdisciplinary responsibility remains explicit; reviewed Sales DOCX Save stays deployment-gated. |
| Product Requirements Specification | Hardware & R&D (`RND`) | Hardware & R&D ID observed (`8b8a…`) | Project | Explicit responsibility; local export only. |
| BOM review | Hardware & R&D (`RND`) | Hardware & R&D ID observed (`8b8a…`) | Project | Local export only. |
| DFMEA | Hardware & R&D (`RND`) | Hardware & R&D ID observed (`8b8a…`) | Project | Local export only. |
| Manufacturing Control Plan | Production & Calibration (`PROD`) | Production ID observed (`1e27…`) | Project | Local export only. |
| DVP&R | Hardware & R&D (`RND`) | Hardware & R&D ID observed (`8b8a…`) | Project | Explicit interdisciplinary responsibility; local export only. |
| Pre-Delivery Inspection | Production & Calibration (`PROD`) | Production ID observed (`1e27…`) | Project | Local export only. |
| Commercial tax invoice | Finance (`FIN`) | Finance ID observed (`f3ba…`) | Project | Local export only. |
| Annual skill matrix | Human Resources (`HR`) | HR ID observed (`a620…`) | Project | Local export only. |

## Exact source contract boundary

1. `src/lib/structured-lifecycle-document-plan.ts` is catalog/discovery data only. It now routes NDA to `OPS` and marks the responsible-person requirement explicit.
2. `src/lib/structured-lifecycle-document-access.ts` independently scopes NDA discovery to `OPS`. The Sales-proposal catalog still exposes only SOR and Contract Review, so a Sales role cannot gain NDA access through the catalog.
3. `src/components/projects/ProjectStructuredDocuments.tsx` reads only the recorded project department and explicitly states that visibility is not authorization. It neither resolves a person nor fetches a private document.
4. The accepted future resolver remains required for every private action: exact project/source, document kind, department, active assigned person, locked private location, immutable template pin, and current human revision. `document_control_registers.owner_employee_id` / `reviewer_employee_id` are the only verified responsible-person anchors.
5. The source contains no installed configurable Legal responsibility registry. Reassigning NDA/letterhead responsibility later therefore remains deployment-pending and must not be represented as an existing access path.

## Source versus live limits

- **Sales HTML history:** unchanged and remains governed by existing creator/requester or `sales.manage` read rules; it is not Legal document authority.
- **DOCX:** all private save/history/download/direct-link functions remain OFF. SOR and Contract Review are still the only reviewed Sales DOCX kinds. Local export is not a Drive save.
- **Procurement:** pending deployment and gate OFF.
- **Archive:** live blocked; no archive behavior changed.

Frozen DOCX contracts and historical HTML behavior are unchanged by this catalog correction.