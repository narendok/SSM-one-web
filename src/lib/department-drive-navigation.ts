import type { DriveCategoryTemplate, DriveNode } from "@/lib/drive";

export type DepartmentDriveTaxonomyKey = "common" | "internal" | "client" | "other";
export type DepartmentDriveTaxonomyEntry = {
  key: DepartmentDriveTaxonomyKey;
  label: string;
  description: string;
  rootFolderKind: "DEPARTMENT_STANDARDS" | "INTERNAL_PROJECTS" | "CLIENT_PROJECTS" | null;
  categoryCount: number;
  categoryIds: string[];
  mappedFolderId: string | null;
  mappingState: "mapped" | "unmapped";
};

const taxonomy: Array<Omit<DepartmentDriveTaxonomyEntry, "categoryCount" | "categoryIds" | "mappedFolderId" | "mappingState">> = [
  {
    key: "common",
    label: "Common documents",
    description: "Department rules, SOPs, KPIs, authority matrices, standards, and controlled records.",
    rootFolderKind: "DEPARTMENT_STANDARDS",
  },
  {
    key: "internal",
    label: "Internal projects",
    description: "Authorized folders for internal project work.",
    rootFolderKind: "INTERNAL_PROJECTS",
  },
  {
    key: "client",
    label: "Client projects",
    description: "Authorized folders for client project work.",
    rootFolderKind: "CLIENT_PROJECTS",
  },
  {
    key: "other",
    label: "Other department work",
    description: "No verified folder mapping is available yet.",
    rootFolderKind: null,
  },
];

export function buildDepartmentDriveTaxonomy(
  roots: Pick<DriveNode, "id" | "folder_kind">[],
  categories: DriveCategoryTemplate[],
): DepartmentDriveTaxonomyEntry[] {
  const common = categories.filter((category) => category.placement === "COMMON" && category.is_active);
  return taxonomy.map((entry) => {
    const scoped = entry.key === "common"
      ? common
      : categories.filter((category) => category.is_active && (
        (entry.key === "internal" && category.placement === "INTERNAL_PROJECT") ||
        (entry.key === "client" && category.placement === "CLIENT_PROJECT")
      ));
    const root = entry.rootFolderKind
      ? roots.find((candidate) => candidate.folder_kind === entry.rootFolderKind)
      : null;
    const hasVerifiedMapping = Boolean(root);
    return {
      ...entry,
      categoryCount: scoped.length,
      categoryIds: scoped.map((category) => category.id),
      mappedFolderId: hasVerifiedMapping ? root?.id ?? null : null,
      mappingState: hasVerifiedMapping ? "mapped" : "unmapped",
    };
  });
}

export function isAllowedDepartmentDriveRoot(kind: string): kind is Exclude<DepartmentDriveTaxonomyEntry["rootFolderKind"], null> {
  return ["DEPARTMENT_STANDARDS", "INTERNAL_PROJECTS", "CLIENT_PROJECTS"].includes(kind);
}
