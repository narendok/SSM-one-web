import { describe, expect, it } from "vitest";
import { buildDepartmentDriveTaxonomy, isAllowedDepartmentDriveRoot } from "./department-drive-navigation";

const categories = [
  { id: "common", placement: "COMMON", is_active: true },
  { id: "internal", placement: "INTERNAL_PROJECT", is_active: true },
  { id: "client", placement: "CLIENT_PROJECT", is_active: true },
  { id: "inactive", placement: "COMMON", is_active: false },
] as any;

describe("department Drive taxonomy", () => {
  it("maps the four visible groups only to their matching verified roots", () => {
    const result = buildDepartmentDriveTaxonomy([
      { id: "standards", folder_kind: "DEPARTMENT_STANDARDS" },
      { id: "internal-root", folder_kind: "INTERNAL_PROJECTS" },
      { id: "client-root", folder_kind: "CLIENT_PROJECTS" },
    ], categories);
    expect(result.map((entry) => entry.label)).toEqual([
      "Common documents",
      "Internal projects",
      "Client projects",
      "Other department work",
    ]);
    expect(result[0]).toMatchObject({ mappedFolderId: "standards", categoryIds: ["common"] });
    expect(result[1]).toMatchObject({ mappedFolderId: "internal-root", categoryIds: ["internal"] });
    expect(result[2]).toMatchObject({ mappedFolderId: "client-root", categoryIds: ["client"] });
    expect(result[3]).toMatchObject({ mappingState: "unmapped", categoryIds: [] });
  });

  it("reports missing authoritative roots instead of guessing or moving historical folders", () => {
    const result = buildDepartmentDriveTaxonomy([], categories);
    expect(result.every((entry) => entry.mappingState === "unmapped")).toBe(true);
  });

  it("keeps a client project group mapped for a client-only department", () => {
    const result = buildDepartmentDriveTaxonomy([{ id: "client-root", folder_kind: "CLIENT_PROJECTS" }], categories);
    expect(result[2]).toMatchObject({ mappedFolderId: "client-root", mappingState: "mapped" });
    expect(result[1]).toMatchObject({ mappingState: "unmapped" });
  });

  it("allows only the verified department/project root keys", () => {
    expect(isAllowedDepartmentDriveRoot("DEPARTMENT_STANDARDS")).toBe(true);
    expect(isAllowedDepartmentDriveRoot("CLIENT_PROJECTS")).toBe(true);
    expect(isAllowedDepartmentDriveRoot("HR_PRIVATE")).toBe(false);
  });
});
