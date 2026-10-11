export type LifecycleDepartmentCode = "RND" | "PROC" | "PROD" | "OPS" | "SAL";

export type LifecycleResponsibilityDefault = {
  key: string;
  title: string;
  stageRange: readonly [number, number];
  leadDepartment: LifecycleDepartmentCode;
  coordinatingDepartment: LifecycleDepartmentCode | null;
  participatingDepartments: LifecycleDepartmentCode[];
  deliverables: string[];
  handoff: string | null;
};

export type LifecyclePreparationPreview = {
  key: string;
  title: string;
  stageRange: readonly [number, number];
  leadDepartment: LifecycleDepartmentCode;
  participatingDepartments: LifecycleDepartmentCode[];
  deliverables: string[];
  dependency: string | null;
  purchaseHandoff: "NOT_APPLICABLE" | "HARDWARE_APPROVED_HANDOFF_REQUIRED";
};

export type CompanyStageRead = {
  id: string;
  stage_code: string;
  title: string;
  sort_order: number;
  requires_gated_handover: boolean;
};

export type LifecycleStageReadiness = {
  stage: CompanyStageRead | null;
  responsibility: LifecycleResponsibilityDefault | null;
  prerequisites: string[];
  blockers: string[];
};

export const connectedLifecycleResponsibilityDefaults: LifecycleResponsibilityDefault[] = [
  {
    key: "intake",
    title: "Intake",
    stageRange: [1, 3],
    leadDepartment: "SAL",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["RND"],
    deliverables: ["Customer need and volume context", "Initial project scope"],
    handoff: "Planning context only; no approval is implied.",
  },
  {
    key: "feasibility",
    title: "Feasibility",
    stageRange: [4, 6],
    leadDepartment: "RND",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["SAL", "PROC"],
    deliverables: ["Cross-functional feasibility inputs", "Technical risk and supply review"],
    handoff: "PM coordinates the working handoff; it is not a release decision.",
  },
  {
    key: "baseline",
    title: "Baseline",
    stageRange: [7, 8],
    leadDepartment: "OPS",
    coordinatingDepartment: "SAL",
    participatingDepartments: ["RND"],
    deliverables: ["Requirement baseline reference", "Sales cost and volume context"],
    handoff: "Sales context is reused; Sales approval is not a default responsibility.",
  },
  {
    key: "poc",
    title: "POC",
    stageRange: [9, 12],
    leadDepartment: "RND",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["PROC"],
    deliverables: ["POC build evidence", "Technical BOM qualification working set"],
    handoff: "Hardware owns technical BOM qualification; no procurement approval is inferred.",
  },
  {
    key: "pilot",
    title: "Pilot",
    stageRange: [13, 16],
    leadDepartment: "RND",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["PROD", "PROC", "OPS"],
    deliverables: ["Pilot build inputs", "Manufacturing and quality feedback"],
    handoff: "Recorded handoff requirements remain governed by their existing stage record.",
  },
  {
    key: "validation",
    title: "Validation",
    stageRange: [17, 21],
    leadDepartment: "OPS",
    coordinatingDepartment: "RND",
    participatingDepartments: ["PROD"],
    deliverables: ["Validation evidence", "Quality review inputs"],
    handoff: "Quality participation does not confirm validation acceptance or release.",
  },
  {
    key: "release_readiness",
    title: "Release readiness",
    stageRange: [22, 24],
    leadDepartment: "RND",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["PROC", "PROD"],
    deliverables: ["Qualified technical BOM source", "Readiness evidence set"],
    handoff: "Purchase receives an approved handoff only through its existing governed path.",
  },
  {
    key: "production",
    title: "Production",
    stageRange: [25, 29],
    leadDepartment: "PROD",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["RND", "OPS"],
    deliverables: ["Production work preparation", "Quality and calibration inputs"],
    handoff: "This planning responsibility is not production release authority.",
  },
  {
    key: "dispatch",
    title: "Dispatch",
    stageRange: [30, 32],
    leadDepartment: "PROD",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["PROC", "SAL"],
    deliverables: ["Dispatch preparation", "Customer-facing delivery context"],
    handoff: "No shipment, acceptance, or customer notification is created here.",
  },
  {
    key: "service",
    title: "Service",
    stageRange: [33, 37],
    leadDepartment: "SAL",
    coordinatingDepartment: "OPS",
    participatingDepartments: ["RND", "OPS"],
    deliverables: ["Field-feedback intake", "Service and corrective-action context"],
    handoff: "Existing service records retain their own workflow and history.",
  },
];

export const connectedLifecyclePreparationDefaults: LifecyclePreparationPreview[] = connectedLifecycleResponsibilityDefaults.map((responsibility) => ({
  key: responsibility.key,
  title: responsibility.title,
  stageRange: responsibility.stageRange,
  leadDepartment: responsibility.leadDepartment,
  participatingDepartments: responsibility.participatingDepartments,
  deliverables: responsibility.deliverables,
  dependency: responsibility.key === "intake"
    ? null
    : `Visible ${connectedLifecycleResponsibilityDefaults[Math.max(0, connectedLifecycleResponsibilityDefaults.indexOf(responsibility) - 1)]?.title ?? "previous"} stage records remain the planning dependency.`,
  purchaseHandoff: responsibility.key === "release_readiness"
    ? "HARDWARE_APPROVED_HANDOFF_REQUIRED"
    : "NOT_APPLICABLE",
}));

export function lifecycleStageNumber(stageCode: string) {
  const match = /^HW_(\d{2})$/.exec(stageCode);
  return match ? Number(match[1]) : null;
}

export function responsibilityDefaultForStage(stageCode: string) {
  const stageNumber = lifecycleStageNumber(stageCode);
  if (stageNumber === null) return null;
  return connectedLifecycleResponsibilityDefaults.find(({ stageRange }) =>
    stageNumber >= stageRange[0] && stageNumber <= stageRange[1],
  ) ?? null;
}

export function stagesForResponsibilityDefault(
  stages: CompanyStageRead[],
  responsibility: LifecycleResponsibilityDefault,
) {
  return stages.filter((stage) => responsibilityDefaultForStage(stage.stage_code)?.key === responsibility.key);
}

export function preparationDefaultForStage(stageCode: string) {
  const stageNumber = lifecycleStageNumber(stageCode);
  if (stageNumber === null) return null;
  return connectedLifecyclePreparationDefaults.find(({ stageRange }) =>
    stageNumber >= stageRange[0] && stageNumber <= stageRange[1],
  ) ?? null;
}

export function stagePreparationSummary(stages: CompanyStageRead[], stageCode: string) {
  const preparation = preparationDefaultForStage(stageCode);
  const matchingStages = preparation
    ? stages.filter((stage) => preparationDefaultForStage(stage.stage_code)?.key === preparation.key)
    : [];
  return { preparation, matchingStages };
}

/**
 * Builds a read-only stage planning summary from a recorded project-stage code.
 * It deliberately does not derive completion, approval, or release from any
 * stage or task status.
 */
export function lifecycleStageReadiness(stages: CompanyStageRead[], stageCode: string, hasRequirementBaseline: boolean): LifecycleStageReadiness {
  const stage = stages.find((candidate) => candidate.stage_code === stageCode) ?? null;
  const responsibility = responsibilityDefaultForStage(stageCode);
  const prerequisites = [
    "Pinned requirement baseline",
    ...(responsibility && responsibility.stageRange[0] > 1 ? ["Visible records from the preceding lifecycle workstream"] : []),
    ...(stage?.requires_gated_handover ? ["Existing governed handover record"] : []),
  ];
  const blockers = [
    ...(!hasRequirementBaseline ? ["No requirement baseline is linked to this project."] : []),
    ...(!stage ? [`Recorded project stage ${stageCode} is not an accessible active company lifecycle stage.`] : []),
    ...(!responsibility ? ["No default workstream is mapped to the recorded project stage."] : []),
  ];
  return { stage, responsibility, prerequisites, blockers };
}

export function lifecycleResponsibilitySettingsStatus() {
  return {
    available: false,
    message: "Local planning adjustments are unsaved. Persistent overrides and stage-triggered preparation remain unavailable until protected contracts are accepted.",
  } as const;
}