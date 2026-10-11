import JSZip from "jszip";

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

const textDecoder = new TextDecoder();

function fail(message: string): never {
  throw new Error(`DOCX verification failed: ${message}`);
}

function isUnsafeRelationshipTarget(target: string) {
  const normalized = target.trim().toLowerCase();
  return /^(?:[a-z][a-z0-9+.-]*:|\\\\|\/\/)/.test(normalized) || normalized.startsWith("/");
}

async function sha256(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * Verifies a bounded OOXML Word package before a future trusted server bridge
 * may record immutable storage facts. It is pure: it neither reads storage nor
 * records a receipt, so it cannot expand authorization on its own.
 */
export async function verifyStructuredLifecycleDocxBytes(
  input: Uint8Array,
  limits: StructuredLifecycleDocxVerifierLimits = {},
): Promise<VerifiedStructuredLifecycleDocx> {
  const effective = { ...defaultLimits, ...limits };
  if (!(input instanceof Uint8Array) || input.byteLength === 0) fail("file is empty");
  if (input.byteLength > effective.maxBytes) fail("file exceeds the byte limit");
  if (input.byteLength < 4 || input[0] !== 0x50 || input[1] !== 0x4b) fail("file is not a ZIP package");

  let zip: JSZip;
  try {
    zip = await JSZip.loadAsync(input, { checkCRC32: true });
  } catch {
    fail("file is not a valid ZIP package");
  }

  const entries = Object.values(zip.files).filter((entry) => !entry.dir);
  if (entries.length === 0 || entries.length > effective.maxZipEntries) fail("ZIP entry count is outside the allowed limit");
  if (entries.some((entry) => entry.name.includes("..") || entry.name.startsWith("/") || entry.name.startsWith("\\"))) fail("ZIP contains an unsafe path");

  let totalUncompressedBytes = 0;
  const contents = new Map<string, string>();
  for (const entry of entries) {
    const bytes = await entry.async("uint8array");
    totalUncompressedBytes += bytes.byteLength;
    if (totalUncompressedBytes > effective.maxUncompressedBytes) fail("ZIP expands beyond the allowed limit");
    if (/\.(?:xml|rels)$/i.test(entry.name) || entry.name === "[Content_Types].xml") contents.set(entry.name, textDecoder.decode(bytes));
  }

  const contentTypes = contents.get("[Content_Types].xml");
  const documentXml = contents.get("word/document.xml");
  const relationships = contents.get("word/_rels/document.xml.rels");
  if (!contentTypes?.includes("application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml")) fail("missing Word document content type");
  if (!documentXml?.includes("<w:document")) fail("missing editable Word document XML");
  if (!relationships?.includes("officeDocument")) fail("missing Word document relationship");
  if (/<!doctype|<html\b|<script\b/i.test(documentXml) || /<!doctype|<html\b/i.test(contentTypes)) fail("HTML payload detected");

  const targets = [...relationships.matchAll(/\bTarget="([^"]+)"/g)].map((match) => match[1] ?? "");
  if (targets.some(isUnsafeRelationshipTarget)) fail("external or absolute relationship target detected");
  if (/\bTargetMode="External"/i.test(relationships)) fail("external relationship detected");

  const paragraphs = (documentXml.match(/<w:p(?:\s|>)/g) ?? []).length;
  const tables = (documentXml.match(/<w:tbl(?:\s|>)/g) ?? []).length;
  if (paragraphs === 0) fail("document has no editable paragraphs");

  return { sha256Checksum: await sha256(input), sizeBytes: input.byteLength, paragraphs, tables };
}