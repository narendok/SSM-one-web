# Historical source extraction only. Do not overwrite the optimized active catalogue; maintain SSM_ONE_DOCUMENT_CATALOGUE.md/json separately.
"""Create a planning inventory from every item in the final DOCX annexure.

This writes local reference documents only. It is not a database seed/migration.
"""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
reference = json.loads((root / "sources/final_structure_2026-10-03.json").read_text(encoding="utf-8"))
groups = {
    "9.1": ("Sales", "Sales / commercial"),
    "9.2": ("Hardware / R&D", "Hardware engineering"),
    "9.3": ("Hardware / R&D", "Firmware / software"),
    "9.4": ("Hardware / R&D", "Mechanical engineering"),
    "9.5": ("Procurement", "Suppliers / stores / incoming quality"),
    "9.6": ("Operations", "QMS / quality governance"),
    "9.7": ("Finance", "Finance; restricted infrastructure contributions"),
    "9.8": ("Human Resources", "HR / competence"),
    "9.9": ("Operations", "Governance / risk"),
}
overrides = {
    "B0455": ("Sales + Finance", "Commercial review; finance retains accounting authority"),
    "B0474": ("Hardware / R&D", "Design verification; Operations coordinates independent review"),
    "B0491": ("Hardware / R&D + Production + Facility", "Mechanical design; production tool maintenance; Facility custody"),
    "B0515": ("Production", "Calibration / MSA"),
    "B0516": ("Procurement + Production", "Stores FIFO and production consumption instructions"),
    "B0518": ("Production", "Workplace / 5S"),
    "B0519": ("Production", "Capacity / takt planning"),
    "B0520": ("Production", "Product disposition; Operations coordinates CAPA"),
    "B0521": ("Production", "Line startup"),
    "B0522": ("Production", "Process equipment PM / OEE; Facility supports infrastructure"),
    "B0523": ("Production", "Production KPI"),
    "B0525": ("Operations + Production", "QMS audit; Production calibration review"),
    "B0526": ("Production", "OEE / yield / scrap review"),
    "B0530": ("Production", "Process flow"),
    "B0531": ("Production", "PFMEA; engineering / QMS contributions"),
    "B0532": ("Production", "Control plan; incoming inspection linked to Procurement"),
    "B0533": ("Operations", "CAPA coordination; each originating team owns its NCR evidence"),
    "B0534": ("Production", "EOL / FQC / PDI"),
    "B0535": ("Production", "Process defect tracking"),
    "B0540": ("Operations + Facility + Finance", "Split security/infrastructure/liability by purpose; no blanket shared register"),
    "B0543": ("Facility / Maintenance", "Authorized IT infrastructure workstream; admin-only system configuration"),
    "B0545": ("Finance + Facility", "Separate financial records from project IT tickets"),
    "B0553": ("Human Resources + Operations", "HR workforce compliance; Operations coordinates applicable licenses"),
    "B0566": ("Facility / Maintenance", "Utilities / DG maintenance"),
    "B0567": ("Facility / Maintenance + Operations", "Waste handling / authorized disposal; Operations governance"),
    "B0568": ("Facility / Maintenance", "Physical security / facility contracts; restricted commercial details"),
    "B0571": ("Facility / Maintenance", "Electricity / water records; Finance payment review"),
    "B0575": ("Facility / Maintenance", "Pest control schedule / evidence"),
}
categories = {
    "Common Departmental & Operational / Maintenance Documents": "01_Common_Controlled_Documents",
    "Periodic & Conditional Operational Reviews": "02_Periodic_and_Conditional_Reviews",
    "Project-Specific Deliverables & Artifacts": "03_Project_Deliverables",
}
items = []
section = category = None
annexure_ids = []
for block in reference["records"]:
    if int(block["id"][1:]) < 448 or not block.get("text", "").strip():
        continue
    if block.get("style") == "Heading2":
        section = block["text"].split(" ", 1)[0]
        continue
    if block.get("style") == "Heading3":
        category = categories[block["text"]]
        continue
    if section is None:
        continue
    dept, workstream = overrides.get(block["id"], groups[section])
    value = block["text"].strip()
    is_note = value.startswith("(Note:")
    status = "Workflow-managed record family; schema/template still to verify" if is_note else "Target catalogue entry; actual template/evidence not verified"
    if "B0561" <= block["id"] <= "B0565":
        status = "Reference only; applicability and valid certificate/license not established"
    if block["id"] in {"B0571", "B0575", "B0577"}:
        status = "Source shorthand; fields, owner routing and template still to define"
    item = {"source_block": block["id"], "source_section": section, "source_text": value,
            "drive_category": category, "proposed_department_owner": dept,
            "workstream": workstream, "planning_status": status}
    items.append(item)
    annexure_ids.append(block["id"])

assert len(items) == len(set(annexure_ids)), "Duplicate source blocks"
assert set(groups) == {item["source_section"] for item in items}, "Missing annexure section"
expected = [b["id"] for b in reference["records"] if int(b["id"][1:]) >= 448 and b.get("text", "").strip() and not b.get("style", "").startswith("Heading")]
assert expected == annexure_ids, "Missing or reordered source inventory rows"
catalogue = {"status": "PLANNING REFERENCE ONLY — NOT A LIVE CONFIGURATION OR DATABASE SEED",
             "source_sha256": reference["sha256"], "source": reference["source"],
             "entries": items, "source_inventory_count": len(items)}
(root / "sources/ORIGINAL_DOCUMENT_CATALOGUE_2026-10-03.json").write_text(json.dumps(catalogue, ensure_ascii=False, indent=2), encoding="utf-8")
lines = ["# Final source document catalogue — 2026-10-03", "",
         "Status: **planning reference; no templates, records, certificates or permissions created.**", "",
         f"All **{len(items)}** item/note blocks from the source annexure are retained below. Codes and descriptions are copied as reference labels, not new official identifiers. Owner mapping is a recommendation within the eight agreed departments, not a live access grant.", "",
         "The source's combined entries remain combined here. Implementation may split them into linked record families (for example infrastructure versus liability risks), while retaining the original source block. Missing template files and certificates must be shown as missing/unverified, not as completed records.", "",
         "See [implementation plan](SSM_ONE_WEB_PORTAL_MASTER_PLAN.md) and the [machine-readable reference](FINAL_DOCUMENT_CATALOGUE_2026-10-03.json).", "",
         f"Source SHA-256: `{reference['sha256']}`", ""]
last = None
def cell(value):
    return value.replace("|", "\\|").replace("\n", " ")
for item in items:
    marker = (item["source_section"], item["drive_category"])
    if marker != last:
        lines.extend([f"## Source {marker[0]} — {marker[1]}", "",
                      "| Source block | Source artifact / record family | Proposed owner / workstream | Readiness |",
                      "| --- | --- | --- | --- |"])
        last = marker
    lines.append("| " + " | ".join(cell(v) for v in [item["source_block"], item["source_text"], item["proposed_department_owner"] + ": " + item["workstream"], item["planning_status"]]) + " |")
    next_index = items.index(item) + 1
    if next_index == len(items) or (items[next_index]["source_section"], items[next_index]["drive_category"]) != marker:
        lines.append("")
lines.extend(["## Additional workflow evidence to configure", "",
              "The annexure is not the entire requirement list. The following families also come from the main source and must be included in the delivery backlog:", "",
              "| Source | Additional records | Delivery group |", "| --- | --- | --- |",
              "| B0116–B0123, B0147–B0175 | PMSS, scoped client SOR/intake, NDA receipt, feasibility contributions, approved PRS baseline, PO/LOI and commercial confirmation | Packs 1–2 |",
              "| B0176–B0205 | POC manifest, tentative electronic/mechanical BOM, pilot PR/RFQ/PO/PCB/stencil/casing references, bring-up, client feedback, laboratory request and pre-compliance evidence | Packs 3–4 |",
              "| B0206–B0237 | Final release manifest and pinned files, applicable approval evidence, forecasts/capacity/long-lead plan, WO/route, raw/assembled PCB traceability, jig/EOL results, serial genealogy, dispatch and invoice links | Packs 4–5 |",
              "| B0246–B0378 | Assignment/handover events, deadline policies, reminder/escalation receipts, authorized departmental settings | Packs 2–6 |",
              "| B0379–B0403 | Client scope revision, ECO/ECN impact assessment, failure/rework decisions, effectivity and obsolescence dispositions | Packs 3–5 |",
              "| B0407–B0444 | PM/TPM, downtime/repair, instrument/calibration, customer tooling custody, utility/contingency drills, competency/TNI/training/reassessment, private BGV/grievance cases and DMAIC reviews | Pack 6 |", "",
              "No real customer/employee data or engineering test outcome is inferred from these names. Sample records must be visibly synthetic and created only in an approved test scope.", ""])
(root / "sources/ORIGINAL_DOCUMENT_CATALOGUE_2026-10-03.md").write_text("\n".join(lines), encoding="utf-8")
print(json.dumps({"items": len(items), "sections": len(groups), "annexure_coverage": "complete", "source_sha256": reference["sha256"]}))
