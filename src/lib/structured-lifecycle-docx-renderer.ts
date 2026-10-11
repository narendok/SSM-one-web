import {
  BorderStyle,
  Document,
  Packer,
  PageOrientation,
  Paragraph,
  Table,
  TableCell,
  TableRow,
  TextRun,
  WidthType,
} from "docx";
import { structuredLifecycleTemplatePreviews, tableRowsForOutput, type LocalTableKey, type StructuredLifecycleTemplateKind, type StructuredTemplateSource } from "./lifecycle-structured-template-previews";
import { validateStructuredSalesLocalPayload } from "./structured-sales-local-payload";
import { validateSpecializedLocalPreviewPayload } from "./lifecycle-structured-template-previews";

export type StructuredLifecycleDocx = {
  fileName: string;
  mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
  bytes: Uint8Array;
  provenance: {
    documentKind: StructuredLifecycleTemplateKind;
    templateKey: string;
    templateVersion: number;
    schemaStatus: "UNVERIFIED_LOCAL_SCHEMA";
    opportunityNumber: string;
    specificationNumber: string;
    specificationVersion: number;
  } | null;
};

const tableColumns: Partial<Record<LocalTableKey, readonly string[]>> = {
  QUOTE_LINE_ROWS: ["Line", "Description", "Quantity", "Unit price", "Currency", "Lead time"],
  VOLUME_TIER_ROWS: ["Minimum quantity", "Maximum quantity", "Unit price"],
  BOM_COST_ROWS: ["Item", "MPN", "Manufacturer", "Description", "Package", "Quantity", "Lead time", "Unit cost", "Currency", "AEC-Q evidence"],
  DFMEA_ROWS: ["Function", "Failure mode", "Effect", "Cause", "Prevention", "Detection", "Severity", "Occurrence", "Detection", "RPN", "Owner", "Action"],
  CONTROL_PLAN_ROWS: ["Process step", "Characteristic", "Specification", "Method", "Equipment", "Sampling", "Reaction plan", "Owner"],
  DVPR_ROWS: ["Test", "Applicability", "Sample count", "Acceptance criteria", "Result", "Evidence", "Standards reference"],
  PDI_ROWS: ["Checkpoint", "Expected condition", "Actual observation", "Evidence", "Disposition"],
  TAX_INVOICE_ROWS: ["Description", "Quantity", "Unit price", "Currency", "Tax rate"],
};

const tableBorder = { style: BorderStyle.SINGLE, size: 1, color: "808080" };
const cellBorders = { top: tableBorder, bottom: tableBorder, left: tableBorder, right: tableBorder };
const portraitPageWidth = 9026;
const landscapePageWidth = 14414;
const wideTableKeys = new Set<LocalTableKey>(["BOM_COST_ROWS", "DFMEA_ROWS"]);

function displayed(value: string | null | undefined) {
  return value === undefined || value === null || value === "" ? "TBC" : value;
}

function fileName(kind: StructuredLifecycleTemplateKind, source: StructuredTemplateSource | null) {
  const project = source?.opportunityNumber ?? "UNVERIFIED";
  return `${project}-${kind.toLowerCase().replaceAll("_", "-")}-local-draft.docx`.replace(/[^A-Za-z0-9._-]+/g, "_");
}

function plainTextParagraph(value: string, bold = false) {
  const lines = value.split(/\r?\n/);
  return new Paragraph({
    children: lines.flatMap((line, index) => [
      new TextRun({ text: line || " ", bold }),
      ...(index < lines.length - 1 ? [new TextRun({ break: 1 })] : []),
    ]),
  });
}

function cell(value: string, width: number, bold = false) {
  return new TableCell({
    borders: cellBorders,
    width: { size: width, type: WidthType.DXA },
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    children: [plainTextParagraph(displayed(value), bold)],
  });
}

function gridTable(headers: readonly string[], rows: readonly string[][], pageWidth = portraitPageWidth) {
  const width = Math.max(1, Math.floor(pageWidth / headers.length));
  const widths = headers.map((_header, index) => index === headers.length - 1 ? pageWidth - width * index : width);
  return new Table({
    width: { size: pageWidth, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ tableHeader: true, cantSplit: true, children: headers.map((header, index) => cell(header, widths[index] ?? width, true)) }),
      ...(rows.length
        ? rows.map((row) => new TableRow({ children: headers.map((_header, index) => cell(row[index] ?? "TBC", widths[index] ?? width)) }))
        : [new TableRow({ children: headers.map((_header, index) => cell("TBC", widths[index] ?? width)) })]),
    ],
  });
}

function validatedEdits(kind: StructuredLifecycleTemplateKind, edits: Record<string, string>) {
  const result = kind === "SOR" || kind === "CONTRACT_REVIEW" || kind === "PRS"
    ? validateStructuredSalesLocalPayload(kind, edits)
    : validateSpecializedLocalPreviewPayload(kind, edits);
  if (!result.ok) throw new Error(result.errors.map((issue) => `${issue.path}: ${issue.message}`).join(" "));
  return result.payload as Record<string, string>;
}

/**
 * Generates a native OOXML working document. The output deliberately carries
 * no approval or release semantics and is not connected to Drive persistence.
 */
export async function renderStructuredLifecycleDocx(
  kind: StructuredLifecycleTemplateKind,
  source: StructuredTemplateSource | null,
  edits: Record<string, string> = {},
): Promise<StructuredLifecycleDocx> {
  const template = structuredLifecycleTemplatePreviews.find((candidate) => candidate.kind === kind);
  if (!template) throw new Error("Unsupported structured lifecycle template.");
  const payload = validatedEdits(kind, edits);
  const provenanceRows = source
    ? [
        ["Opportunity", source.opportunityNumber],
        ["Customer", source.customerName],
        ["Master Specification", `${source.specificationNumber} rev ${source.versionNumber}`],
        ["Master Specification revision ID", source.versionId],
        ["Template identity", `${template.template.templateKey} v${template.template.version}`],
        ["Editable schema identity", "UNVERIFIED — local browser schema; no immutable server schema pin is available"],
      ]
    : [["Source status", "UNVERIFIED — source unavailable"]];

  const children: Array<Paragraph | Table> = [
    new Paragraph({ children: [new TextRun({ text: template.label, bold: true, size: 32 })] }),
    plainTextParagraph("LOCAL WORKING DOCX — NOT APPROVED, ISSUED, OR RELEASED."),
    new Paragraph({ children: [new TextRun({ text: "Exact source and template provenance", bold: true })] }),
    gridTable(["Trace", "Pinned value"], provenanceRows),
    new Paragraph({ children: [new TextRun({ text: "Read-only source context", bold: true })] }),
    gridTable(
      ["Source field", "Value"],
      template.sourceFields.map((field) => [field, displayed(source?.sourceFields[field])]),
    ),
    new Paragraph({ children: [new TextRun({ text: "Editable working fields", bold: true })] }),
  ];

  for (const field of template.editableFields) {
    children.push(new Paragraph({ children: [new TextRun({ text: field.label, bold: true })] }));
    if (field.kind === "table") {
      const key = field.key as LocalTableKey;
      children.push(gridTable(
        tableColumns[key] ?? [field.label],
        tableRowsForOutput(key, payload[field.key]),
        wideTableKeys.has(key) ? landscapePageWidth : portraitPageWidth,
      ));
    } else {
      children.push(plainTextParagraph(displayed(payload[field.key])));
    }
  }
  if (!template.editableFields.length) children.push(plainTextParagraph("TBC — no editable fields are available in this scope."));
  children.push(plainTextParagraph("Unresolved values remain TBC. Manual values are working content only and cannot create approval, issuance, release, legal commitment, or compliance evidence."));

  const document = new Document({
    creator: "SSM One",
    title: `${template.label} local working document`,
    description: "Editable source-pinned working DOCX; not approved, issued, or released.",
    sections: [{
      properties: {
        page: {
          size: { width: 11906, height: 16838, orientation: PageOrientation.LANDSCAPE },
          margin: { top: 1134, right: 1440, bottom: 1134, left: 1440 },
        },
      },
      children,
    }],
  });
  return {
    fileName: fileName(kind, source),
    mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    bytes: new Uint8Array(await Packer.toBuffer(document)),
    provenance: source ? {
      documentKind: kind,
      templateKey: template.template.templateKey,
      templateVersion: template.template.version,
      schemaStatus: "UNVERIFIED_LOCAL_SCHEMA",
      opportunityNumber: source.opportunityNumber,
      specificationNumber: source.specificationNumber,
      specificationVersion: source.versionNumber,
    } : null,
  };
}