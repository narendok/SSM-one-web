import { connectedLifecycleResponsibilityDefaults, type LifecycleDepartmentCode } from "./connected-lifecycle-responsibility-plan";

export type ResponsibilityOverrideIntent = {
  projectId: string;
  projectStageRecordId: string;
  companyProcessStageId: string;
  expectedStageUpdatedAt: string;
  leadDepartmentId: string;
  coordinatingDepartmentId: string | null;
  participatingDepartmentIds: string[];
  requestKey: string;
};

export type ResponsibilityOverrideContract = {
  state: "INACTIVE";
  title: string;
  unavailableReason: string;
  protectedInputs: string[];
  preservedRecords: string[];
  requiredTransactionGuarantees: string[];
};

export const lifecycleResponsibilityOverrideContract: ResponsibilityOverrideContract = {
  state: "INACTIVE",
  title: "Persistent stage responsibility overrides",
  unavailableReason: "No accepted protected contract currently persists stage responsibility overrides. Local planning adjustments remain unsaved.",
  protectedInputs: [
    "Exact project, project-stage record, and company-stage IDs",
    "Expected project-stage record updated timestamp",
    "Active lead, coordinating, and participating department IDs",
    "Caller request key",
  ],
  preservedRecords: [
    "Existing project-stage owner and reviewer assignments",
    "Existing linked tasks, handover notes, evidence, statuses, and completion history",
    "Existing templates and generated lifecycle records",
  ],
  requiredTransactionGuarantees: [
    "Server-derived authenticated actor and project/department authorization before receipt replay",
    "Project then stage then request lock order with authorization repeated after waits",
    "Exact optimistic stage revision conflict detection",
    "Actor-bound canonical request-key replay and changed-payload conflict denial",
    "Append-only immutable audit with no task, handoff, notification, approval, or release side effect",
  ],
};

export function defaultResponsibilityLead(stageCode: string): LifecycleDepartmentCode | null {
  return connectedLifecycleResponsibilityDefaults.find((item) =>
    stageCode >= `HW_${String(item.stageRange[0]).padStart(2, "0")}`
      && stageCode <= `HW_${String(item.stageRange[1]).padStart(2, "0")}`,
  )?.leadDepartment ?? null;
}

export function responsibilityOverrideAvailability() {
  return { available: false, contract: lifecycleResponsibilityOverrideContract } as const;
}