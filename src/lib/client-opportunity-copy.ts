import { z } from "zod";
import { masterSpecificationDraftSchema } from "./master-specification";

const uuid = z.string().uuid();
const boundedText = (max: number) => z.string().trim().min(1).max(max);

const customerRequirementSourceSchema = z.object({
  id: uuid,
  revisionNumber: z.number().int().positive(),
  title: boundedText(240),
  requirementNumber: z.string().trim().min(1).max(120).nullable(),
  customerReference: z.string().trim().max(240).nullable(),
  summary: z.string().trim().max(12_000).nullable(),
}).strict();

const publishedHighlightSchema = z.object({
  departmentName: boundedText(160),
  body: boundedText(12_000),
  sourceRevisionId: uuid,
  sourceRevisionNumber: z.number().int().positive(),
  publishedAt: z.string().datetime(),
}).strict();

export const clientOpportunityCopyInputSchema = z.object({
  opportunity: z.object({
    id: uuid,
    opportunityNumber: boundedText(120),
    customerId: uuid,
    customerName: boundedText(300),
  }).strict(),
  masterRevision: z.object({
    id: uuid,
    number: z.number().int().positive(),
    specificationNumber: boundedText(120),
    data: masterSpecificationDraftSchema,
  }).strict(),
  customerRequirements: z.array(customerRequirementSourceSchema).max(200),
  publishedHighlights: z.array(publishedHighlightSchema).max(100),
}).strict();

export type ClientOpportunityCopyInput = z.infer<typeof clientOpportunityCopyInputSchema>;

/** Pure allowlist projection only; it does not authorize or resolve a client link. */
export function projectClientOpportunityCopy(input: ClientOpportunityCopyInput) {
  const source = clientOpportunityCopyInputSchema.parse(input);
  const clientHighlights = source.publishedHighlights
    .filter((highlight) => highlight.sourceRevisionId === source.masterRevision.id && highlight.sourceRevisionNumber === source.masterRevision.number)
    .map(({ departmentName, body, sourceRevisionId, sourceRevisionNumber, publishedAt }) => ({
      departmentName,
      body,
      sourceRevision: { id: sourceRevisionId, number: sourceRevisionNumber },
      publishedAt,
    }));

  return {
    opportunity: { number: source.opportunity.opportunityNumber, customerName: source.opportunity.customerName },
    masterSpecification: {
      number: source.masterRevision.specificationNumber,
      sourceRevision: { id: source.masterRevision.id, number: source.masterRevision.number },
      proposedName: source.masterRevision.data.proposedName,
      industryApplication: source.masterRevision.data.industryApplication,
      requirementSummary: source.masterRevision.data.requirementSummary,
      powerAndUnits: source.masterRevision.data.powerAndUnits,
      interfaces: source.masterRevision.data.interfaces,
      connectivityAndGnss: source.masterRevision.data.connectivityAndGnss,
      environmentAndIp: source.masterRevision.data.environmentAndIp,
      volumes: source.masterRevision.data.volumes,
      schedule: source.masterRevision.data.schedule,
      requestedStandards: source.masterRevision.data.requestedStandards,
      exclusions: source.masterRevision.data.exclusions,
    },
    customerRequirements: source.customerRequirements.map((requirement) => ({
      title: requirement.title,
      number: requirement.requirementNumber,
      customerReference: requirement.customerReference,
      summary: requirement.summary,
      sourceRevision: { id: requirement.id, number: requirement.revisionNumber },
    })),
    clientHighlights,
  };
}

/** No resolver exists until recipient binding, scope, expiry, revocation, and audit are accepted. */
export const clientOpportunityCopyLinkAvailability = {
  available: false,
  reason: "A client copy link is unavailable until a recipient-bound, opportunity-scoped, expiring and revocable access contract is accepted.",
} as const;