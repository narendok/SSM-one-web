import JSZip from "jszip";
import { SaxesParser, type SaxesAttributePlain, type SaxesTag } from "saxes";

export const DOCX_MIME_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

export type VerifiedStructuredLifecycleDocx = {
  sha256Checksum: string;
  sizeBytes: number;
  paragraphs: number;
  tables: number;
};

export type StructuredLifecycleDocxVerifierLimits = {
  maxBytes?: number;
  maxZipEntries?: number;
  maxUncompressedBytes?: number;
};

const defaultLimits: Required<StructuredLifecycleDocxVerifierLimits> = {
  maxBytes: 10 * 1024 * 1024,
  maxZipEntries: 256,
  maxUncompressedBytes: 32 * 1024 * 1024,
};
const relationshipsNamespace = "http://schemas.openxmlformats.org/package/2006/relationships";
const officeDocumentRelationship = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument";
const wordDocumentContentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml";
const textDecoder = new TextDecoder();

type ZipEntryMetadata = { compressedSize: number; uncompressedSize: number };
type Relationship = { target: string; type: string; targetMode: string | null };

function fail(message: string): never {
  throw new Error(`DOCX verification failed: ${message}`);
}

function attributes(tag: SaxesTag) {
  return Object.values(tag.attributes as Record<string, SaxesAttributePlain>).reduce<Record<string, string>>((result, attribute) => {
    result[attribute.name] = attribute.value;
    return result;
  }, {});
}

function parseXml(xml: string, path: string, onTag: (tag: SaxesTag, values: Record<string, string>) => void) {
  let error: Error | null = null;
  const parser = new SaxesParser({ xmlns: false });
  parser.ondoctype = () => { error = new Error("DTD is forbidden"); };
  parser.onerror = (parserError) => { error = parserError; parser.resume(); };
  parser.onopentag = (tag) => { if (!error) onTag(tag, attributes(tag)); };
  parser.write(xml).close();
  if (error) fail(`${path} is not safe XML`);
}

function normalizedPath(path: string) {
  const stack: string[] = [];
  for (const segment of path.replaceAll("\\", "/").split("/")) {
    if (!segment || segment === ".") continue;
    if (segment === "..") return null;
    stack.push(segment);
  }
  return stack.join("/");
}

function relationshipSourcePath(relsPath: string) {
  if (relsPath === "_rels/.rels") return "";
  const match = /^(.*)\/_rels\/([^/]+)\.rels$/.exec(relsPath);
  return match ? `${match[1]}/${match[2]}` : null;
}

function resolveRelationshipTarget(relsPath: string, target: string) {
  if (/^(?:[a-z][a-z0-9+.-]*:|\\\\|\/\/|\/)/i.test(target.trim())) return null;
  const source = relationshipSourcePath(relsPath);
  if (source === null) return null;
  const base = source ? source.slice(0, source.lastIndexOf("/") + 1) : "";
  return normalizedPath(`${base}${target}`);
}

function checkedLimits(limits: StructuredLifecycleDocxVerifierLimits) {
  const effective = { ...defaultLimits, ...limits };
  if (!Object.values(effective).every((value) => Number.isSafeInteger(value) && value > 0)) fail("limits must be positive safe integers");
  if (effective.maxUncompressedBytes < effective.maxBytes) fail("uncompressed byte limit cannot be smaller than file limit");
  return effective;
}

function entryMetadata(entry: JSZip.JSZipObject) {
  const data = (entry as JSZip.JSZipObject & { _data?: ZipEntryMetadata })._data;
  if (!data || !Number.isSafeInteger(data.compressedSize) || !Number.isSafeInteger(data.uncompressedSize) || data.compressedSize < 0 || data.uncompressedSize < 0) fail("ZIP entry metadata is invalid");
  return data;
}

function relationships(xml: string, path: string) {
  const values: Relationship[] = [];
  parseXml(xml, path, (tag, attrs) => {
    if (tag.name === "Relationships" && attrs.xmlns !== relationshipsNamespace) fail(`${path} has an invalid relationships namespace`);
    if (tag.name === "Relationship") {
      if (!attrs.Id || !attrs.Type || !attrs.Target) fail(`${path} has an incomplete relationship`);
      values.push({ type: attrs.Type, target: attrs.Target, targetMode: attrs.TargetMode ?? null });
    }
  });
  return values;
}

async function sha256(bytes: Uint8Array) {
  const stableBytes = new Uint8Array(bytes.byteLength);
  stableBytes.set(bytes);
  const digest = await crypto.subtle.digest("SHA-256", stableBytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * Pure bounded OOXML inspection. It cannot read storage, issue receipts, or
 * elevate a caller; a future accepted server-only object reader must bind its
 * returned facts to an immutable object identity before materialization.
 */
export async function verifyStructuredLifecycleDocxBytes(
  input: Uint8Array,
  limits: StructuredLifecycleDocxVerifierLimits = {},
): Promise<VerifiedStructuredLifecycleDocx> {
  const effective = checkedLimits(limits);
  if (!(input instanceof Uint8Array) || input.byteLength === 0) fail("file is empty");
  if (input.byteLength > effective.maxBytes) fail("file exceeds the byte limit");
  if (input.byteLength < 4 || input[0] !== 0x50 || input[1] !== 0x4b) fail("file is not a ZIP package");

  let zip: JSZip;
  try {
    zip = await JSZip.loadAsync(input, { checkCRC32: false });
  } catch {
    fail("file is not a valid ZIP package");
  }
  const entries = Object.values(zip.files).filter((entry) => !entry.dir);
  if (entries.length === 0 || entries.length > effective.maxZipEntries) fail("ZIP entry count is outside the allowed limit");
  let declaredTotal = 0;
  for (const entry of entries) {
    const original = entry.unsafeOriginalName ?? entry.name;
    if (!normalizedPath(original) || original.includes("..") || original.startsWith("/") || original.startsWith("\\")) fail("ZIP contains an unsafe original path");
    const metadata = entryMetadata(entry);
    declaredTotal += metadata.uncompressedSize;
    if (!Number.isSafeInteger(declaredTotal) || declaredTotal > effective.maxUncompressedBytes || metadata.uncompressedSize > effective.maxUncompressedBytes) fail("ZIP declared expansion exceeds the allowed limit");
  }

  const xmlParts = new Map<string, string>();
  for (const entry of entries.filter((candidate) => candidate.name === "[Content_Types].xml" || /\.(?:xml|rels)$/i.test(candidate.name))) {
    const metadata = entryMetadata(entry);
    if (metadata.uncompressedSize > effective.maxUncompressedBytes) fail("XML part exceeds the allowed limit");
    const bytes = await entry.async("uint8array");
    if (bytes.byteLength !== metadata.uncompressedSize) fail("ZIP entry size changed while reading");
    xmlParts.set(entry.name, textDecoder.decode(bytes));
  }

  const contentTypes = xmlParts.get("[Content_Types].xml");
  const rootRelationships = xmlParts.get("_rels/.rels");
  if (!contentTypes || !rootRelationships) fail("missing OOXML package metadata");
  let mainDocumentPath: string | null = null;
  parseXml(contentTypes, "[Content_Types].xml", (tag, attrs) => {
    if (tag.name === "Types" && attrs.xmlns !== "http://schemas.openxmlformats.org/package/2006/content-types") fail("content types has an invalid namespace");
    if (tag.name === "Override" && attrs.ContentType === wordDocumentContentType && attrs.PartName?.startsWith("/")) mainDocumentPath = normalizedPath(attrs.PartName.slice(1));
  });
  if (!mainDocumentPath || !xmlParts.has(mainDocumentPath)) fail("missing Word document content type or main part");

  const rootOfficeRelationship = relationships(rootRelationships, "_rels/.rels").find((relationship) => relationship.type === officeDocumentRelationship);
  if (!rootOfficeRelationship || rootOfficeRelationship.targetMode || resolveRelationshipTarget("_rels/.rels", rootOfficeRelationship.target) !== mainDocumentPath) fail("root officeDocument relationship does not bind the declared main document");
  for (const [path, xml] of xmlParts.entries()) {
    if (!path.endsWith(".rels")) continue;
    for (const relationship of relationships(xml, path)) {
      if (relationship.targetMode?.toLowerCase() === "external" || !resolveRelationshipTarget(path, relationship.target)) fail("external or unsafe relationship detected");
    }
  }

  const documentXml = xmlParts.get(mainDocumentPath);
  if (!documentXml) fail("missing editable Word document XML");
  let paragraphs = 0;
  let tables = 0;
  parseXml(documentXml, mainDocumentPath, (tag) => {
    if (tag.name === "w:p" || tag.local === "p") paragraphs += 1;
    if (tag.name === "w:tbl" || tag.local === "tbl") tables += 1;
    if (["w:altChunk", "w:object", "w:control", "w:script"].includes(tag.name)) fail("active Word content is forbidden");
  });
  if (paragraphs === 0) fail("document has no editable paragraphs");
  return { sha256Checksum: await sha256(input), sizeBytes: input.byteLength, paragraphs, tables };
}