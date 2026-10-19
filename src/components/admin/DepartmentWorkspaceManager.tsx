import { useState, useEffect } from "react";
import {
  ArrowDown, ArrowUp, Building2, Calendar, Check, Edit2, Info, Layers, Plus,
  RefreshCw, Search, ShieldAlert, ShieldCheck, Tag, Trash2, X
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle
} from "@/components/ui/dialog";
import {
  fetchAllCanonicalDepartments,
  saveCanonicalDepartment,
  reorderCanonicalDepartments,
  toggleDepartmentActiveStatus,
  deleteCanonicalDepartment,
  type CanonicalDepartment,
} from "@/lib/canonical-departments";
import { DepartmentChroniclesFeed } from "@/components/departments/DepartmentChroniclesFeed";
import { DepartmentStagesManager } from "@/components/departments/DepartmentStagesManager";
import { toast } from "sonner";
import { useQueryClient } from "@tanstack/react-query";

export function DepartmentWorkspaceManager() {
  const queryClient = useQueryClient();
  const [departments, setDepartments] = useState<CanonicalDepartment[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "inactive">("all");

  // Dialog states
  const [editingDept, setEditingDept] = useState<CanonicalDepartment | null>(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [chroniclesDept, setChroniclesDept] = useState<CanonicalDepartment | null>(null);
  const [stagesDept, setStagesDept] = useState<CanonicalDepartment | null>(null);

  // Form states
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [description, setDescription] = useState("");
  const [aliases, setAliases] = useState("");
  const [isActive, setIsActive] = useState(true);
  const [docCodeEnabled, setDocCodeEnabled] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  const loadDepartments = async () => {
    setIsLoading(true);
    try {
      const data = await fetchAllCanonicalDepartments();
      setDepartments(data);
    } catch (err) {
      toast.error("Failed to load departments.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    void loadDepartments();
  }, []);

  const invalidateGlobalQueries = async () => {
    await queryClient.invalidateQueries({ queryKey: ["active-departments"] });
    await queryClient.invalidateQueries({ queryKey: ["canonical_departments"] });
  };

  const handleOpenCreate = () => {
    setName("");
    setCode("");
    setDescription("");
    setAliases("");
    setIsActive(true);
    setDocCodeEnabled(false);
    setIsCreateOpen(true);
  };

  const handleOpenEdit = (dept: CanonicalDepartment) => {
    setEditingDept(dept);
    setName(dept.name);
    setCode(dept.code || "");
    setDescription(dept.description || "");
    setAliases((dept.aliases || []).join(", "));
    setIsActive(dept.is_active !== false);
    setDocCodeEnabled(Boolean(dept.document_code_enabled));
  };

  const handleSave = async () => {
    if (!name.trim()) {
      toast.error("Department name is required.");
      return;
    }

    setIsSaving(true);
    try {
      const aliasList = aliases
        .split(",")
        .map((a) => a.trim())
        .filter(Boolean);

      await saveCanonicalDepartment({
        id: editingDept ? editingDept.id : undefined,
        name: name.trim(),
        code: code.trim().toUpperCase() || null,
        description: description.trim() || null,
        aliases: aliasList,
        is_active: isActive,
        document_code_enabled: docCodeEnabled,
        sort_order: editingDept ? editingDept.sort_order : departments.length + 1,
      });

      toast.success(
        editingDept
          ? `Department "${name}" updated successfully.`
          : `Department "${name}" created successfully.`
      );

      setIsCreateOpen(false);
      setEditingDept(null);
      await loadDepartments();
      await invalidateGlobalQueries();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to save department.");
    } finally {
      setIsSaving(false);
    }
  };

  const handleToggleStatus = async (dept: CanonicalDepartment) => {
    const nextStatus = !dept.is_active;
    try {
      await toggleDepartmentActiveStatus(dept.id, nextStatus);
      toast.success(
        nextStatus
          ? `Department "${dept.name}" activated.`
          : `Department "${dept.name}" deactivated (soft-deleted).`
      );
      await loadDepartments();
      await invalidateGlobalQueries();
    } catch (err) {
      toast.error("Failed to update status.");
    }
  };

  const handleDelete = async (dept: CanonicalDepartment) => {
    const promptMsg = `Are you sure you want to delete/deactivate "${dept.name}"? If it has linked historical records, it will be safely deactivated.`;
    if (confirm(promptMsg)) {
      try {
        const res = await deleteCanonicalDepartment(dept.id);
        if (res.deactivatedOnly) {
          toast.info(`Core department "${dept.name}" was deactivated to protect existing project records.`);
        } else {
          toast.success(`Department "${dept.name}" was removed.`);
        }
        await loadDepartments();
        await invalidateGlobalQueries();
      } catch (err) {
        toast.error("Failed to delete department.");
      }
    }
  };

  const handleMove = async (index: number, direction: "up" | "down") => {
    if (direction === "up" && index === 0) return;
    if (direction === "down" && index === departments.length - 1) return;

    const targetIndex = direction === "up" ? index - 1 : index + 1;
    const reordered = [...departments];
    const [moved] = reordered.splice(index, 1);
    reordered.splice(targetIndex, 0, moved);

    setDepartments(reordered);

    try {
      await reorderCanonicalDepartments(reordered.map((d) => d.id));
      toast.success("Department order updated.");
      await invalidateGlobalQueries();
    } catch (err) {
      toast.error("Failed to save department order.");
      await loadDepartments();
    }
  };

  const filtered = departments.filter((dept) => {
    if (filterStatus === "active" && dept.is_active === false) return false;
    if (filterStatus === "inactive" && dept.is_active !== false) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      return (
        dept.name.toLowerCase().includes(q) ||
        (dept.code && dept.code.toLowerCase().includes(q)) ||
        (dept.aliases && dept.aliases.some((a) => a.toLowerCase().includes(q)))
      );
    }
    return true;
  });

  const activeCount = departments.filter((d) => d.is_active !== false).length;
  const inactiveCount = departments.filter((d) => d.is_active === false).length;

  return (
    <div className="space-y-6">
      {/* Header and Summary stats */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-xl font-semibold flex items-center gap-2">
            <Building2 className="size-5 text-primary" />
            Department Workspace Master
          </h2>
          <p className="text-sm text-muted-foreground">
            Create, edit, reorder, and soft-delete/deactivate department workspaces dynamically.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={loadDepartments} className="gap-1.5">
            <RefreshCw className="size-3.5" /> Refresh
          </Button>
          <Button size="sm" onClick={handleOpenCreate} className="gap-1.5">
            <Plus className="size-3.5" /> Add Department
          </Button>
        </div>
      </div>

      <div className="grid gap-3 grid-cols-2 sm:grid-cols-4">
        <Card className="p-3">
          <p className="text-xs text-muted-foreground">Total Workspaces</p>
          <p className="text-2xl font-bold">{departments.length}</p>
        </Card>
        <Card className="p-3">
          <p className="text-xs text-muted-foreground">Active Workspaces</p>
          <p className="text-2xl font-bold text-emerald-600 dark:text-emerald-400">{activeCount}</p>
        </Card>
        <Card className="p-3">
          <p className="text-xs text-muted-foreground">Deactivated (Soft-deleted)</p>
          <p className="text-2xl font-bold text-muted-foreground">{inactiveCount}</p>
        </Card>
        <Card className="p-3">
          <p className="text-xs text-muted-foreground">Custom Extensions</p>
          <p className="text-2xl font-bold text-sky-600 dark:text-sky-400">
            {departments.filter((d) => d.is_custom || d.id.startsWith("dept-custom-")).length}
          </p>
        </Card>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
          <Input
            placeholder="Search departments by name, code, or alias…"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 h-9 text-xs"
          />
        </div>

        <div className="flex items-center gap-1 text-xs">
          <button
            onClick={() => setFilterStatus("all")}
            className={`rounded-md px-3 py-1.5 transition-colors ${
              filterStatus === "all"
                ? "bg-primary text-primary-foreground font-medium"
                : "bg-muted/60 text-muted-foreground hover:bg-muted"
            }`}
          >
            All ({departments.length})
          </button>
          <button
            onClick={() => setFilterStatus("active")}
            className={`rounded-md px-3 py-1.5 transition-colors ${
              filterStatus === "active"
                ? "bg-primary text-primary-foreground font-medium"
                : "bg-muted/60 text-muted-foreground hover:bg-muted"
            }`}
          >
            Active ({activeCount})
          </button>
          <button
            onClick={() => setFilterStatus("inactive")}
            className={`rounded-md px-3 py-1.5 transition-colors ${
              filterStatus === "inactive"
                ? "bg-primary text-primary-foreground font-medium"
                : "bg-muted/60 text-muted-foreground hover:bg-muted"
            }`}
          >
            Inactive ({inactiveCount})
          </button>
        </div>
      </div>

      {/* Departments Table */}
      <div className="overflow-hidden rounded-lg border bg-card">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b bg-muted/40 text-xs text-muted-foreground">
              <tr>
                <th className="p-3 w-16 text-center font-medium">Order</th>
                <th className="p-3 font-medium">Department Workspace</th>
                <th className="p-3 font-medium">Code</th>
                <th className="p-3 font-medium">Aliases</th>
                <th className="p-3 font-medium">Status</th>
                <th className="p-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filtered.map((dept, idx) => {
                const isActive = dept.is_active !== false;
                return (
                  <tr
                    key={dept.id}
                    className={`transition-colors hover:bg-muted/30 ${
                      !isActive ? "opacity-60 bg-muted/10" : ""
                    }`}
                  >
                    <td className="p-3 text-center">
                      <div className="flex items-center justify-center gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          disabled={idx === 0}
                          onClick={() => handleMove(idx, "up")}
                          className="size-6 text-muted-foreground hover:text-foreground"
                          title="Move up"
                        >
                          <ArrowUp className="size-3" />
                        </Button>
                        <span className="font-mono text-xs w-4">{idx + 1}</span>
                        <Button
                          variant="ghost"
                          size="icon"
                          disabled={idx === filtered.length - 1}
                          onClick={() => handleMove(idx, "down")}
                          className="size-6 text-muted-foreground hover:text-foreground"
                          title="Move down"
                        >
                          <ArrowDown className="size-3" />
                        </Button>
                      </div>
                    </td>

                    <td className="p-3">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-foreground">{dept.name}</span>
                        {dept.is_custom && (
                          <Badge variant="outline" className="text-[10px] py-0 px-1 border-sky-400 text-sky-600 dark:text-sky-400">
                            Custom
                          </Badge>
                        )}
                      </div>
                      {dept.description && (
                        <p className="text-xs text-muted-foreground line-clamp-1 mt-0.5">
                          {dept.description}
                        </p>
                      )}
                    </td>

                    <td className="p-3 font-mono text-xs">
                      {dept.code ? (
                        <Badge variant="secondary" className="font-mono text-[11px]">
                          {dept.code}
                        </Badge>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </td>

                    <td className="p-3">
                      <div className="flex flex-wrap gap-1 max-w-xs">
                        {dept.aliases && dept.aliases.length > 0 ? (
                          dept.aliases.slice(0, 3).map((a) => (
                            <span
                              key={a}
                              className="rounded bg-muted/60 px-1.5 py-0.5 text-[10px] text-muted-foreground"
                            >
                              {a}
                            </span>
                          ))
                        ) : (
                          <span className="text-muted-foreground text-xs">—</span>
                        )}
                        {dept.aliases && dept.aliases.length > 3 && (
                          <span className="text-[10px] text-muted-foreground">
                            +{dept.aliases.length - 3}
                          </span>
                        )}
                      </div>
                    </td>

                    <td className="p-3">
                      <button
                        onClick={() => handleToggleStatus(dept)}
                        className={`inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium cursor-pointer transition-colors ${
                          isActive
                            ? "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 hover:bg-emerald-500/25"
                            : "bg-muted text-muted-foreground hover:bg-muted/80"
                        }`}
                        title="Click to toggle active status"
                      >
                        <span
                          className={`size-1.5 rounded-full ${
                            isActive ? "bg-emerald-500" : "bg-muted-foreground"
                          }`}
                        />
                        {isActive ? "Active" : "Deactivated"}
                      </button>
                    </td>

                    <td className="p-3 text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setStagesDept(dept)}
                          className="h-7 px-2 text-xs gap-1 text-emerald-600 dark:text-emerald-400 hover:text-emerald-700"
                          title="Manage Stages & Responsibilities for this department"
                        >
                          <Layers className="size-3.5" />
                          <span className="hidden md:inline">Stages</span>
                        </Button>

                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setChroniclesDept(dept)}
                          className="h-7 px-2 text-xs gap-1 text-primary hover:text-primary"
                          title="Open Chronicles Feed for this department"
                        >
                          <Calendar className="size-3.5" />
                          <span className="hidden md:inline">Chronicles</span>
                        </Button>

                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleOpenEdit(dept)}
                          className="h-7 px-2 text-xs gap-1"
                        >
                          <Edit2 className="size-3.5" />
                          Edit
                        </Button>

                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleDelete(dept)}
                          className="h-7 px-2 text-xs text-destructive hover:text-destructive hover:bg-destructive/10"
                          title="Delete / Deactivate"
                        >
                          <Trash2 className="size-3.5" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                );
              })}

              {filtered.length === 0 && !isLoading && (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-muted-foreground text-sm">
                    No departments match your filter criteria.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create / Edit Dialog */}
      <Dialog
        open={isCreateOpen || Boolean(editingDept)}
        onOpenChange={(open) => {
          if (!open) {
            setIsCreateOpen(false);
            setEditingDept(null);
          }
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>
              {editingDept ? `Edit Department: ${editingDept.name}` : "Add Department Workspace"}
            </DialogTitle>
            <DialogDescription className="text-xs">
              Configure department naming, routing code, search aliases, and operational status.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div>
              <label className="text-xs font-medium">Department Name *</label>
              <Input
                placeholder="e.g. Battery Engineering, Legal & Compliance"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="mt-1 text-sm"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-medium">Department Code</label>
                <Input
                  placeholder="e.g. BAT, LEG, MECH"
                  value={code}
                  onChange={(e) => setCode(e.target.value.toUpperCase())}
                  className="mt-1 text-xs font-mono"
                  maxLength={10}
                />
              </div>

              <div>
                <label className="text-xs font-medium">Status</label>
                <div className="flex items-center gap-2 mt-2">
                  <input
                    type="checkbox"
                    id="deptIsActive"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                    className="rounded border-input text-primary"
                  />
                  <label htmlFor="deptIsActive" className="text-xs cursor-pointer">
                    Active workspace
                  </label>
                </div>
              </div>
            </div>

            <div>
              <label className="text-xs font-medium">Search Aliases</label>
              <Input
                placeholder="e.g. battery, bms, cells (comma separated)"
                value={aliases}
                onChange={(e) => setAliases(e.target.value)}
                className="mt-1 text-xs"
              />
              <p className="text-[11px] text-muted-foreground mt-1">
                Used to resolve URLs, task tags, and workspace switcher search queries.
              </p>
            </div>

            <div>
              <label className="text-xs font-medium">Operational Summary / Description</label>
              <Input
                placeholder="Short description of department responsibilities…"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="mt-1 text-xs"
              />
            </div>

            <div className="flex items-center gap-2 pt-1 border-t">
              <input
                type="checkbox"
                id="docCodeCheck"
                checked={docCodeEnabled}
                onChange={(e) => setDocCodeEnabled(e.target.checked)}
                className="rounded border-input text-primary"
              />
              <label htmlFor="docCodeCheck" className="text-xs text-muted-foreground cursor-pointer">
                Allow code in controlled-document prefixes (e.g. DOC-BAT-001)
              </label>
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              size="sm"
              disabled={isSaving}
              onClick={() => {
                setIsCreateOpen(false);
                setEditingDept(null);
              }}
            >
              Cancel
            </Button>
            <Button size="sm" disabled={isSaving || !name.trim()} onClick={handleSave}>
              {isSaving ? "Saving…" : editingDept ? "Save Changes" : "Create Workspace"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Chronicles Modal for specific department */}
      <Dialog
        open={Boolean(chroniclesDept)}
        onOpenChange={(open) => {
          if (!open) setChroniclesDept(null);
        }}
      >
        <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
          {chroniclesDept && (
            <DepartmentChroniclesFeed
              departmentId={chroniclesDept.id}
              departmentName={chroniclesDept.name}
            />
          )}
        </DialogContent>
      </Dialog>

      {/* Stages & Responsibilities Modal for specific department */}
      <Dialog
        open={Boolean(stagesDept)}
        onOpenChange={(open) => {
          if (!open) setStagesDept(null);
        }}
      >
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto p-4 sm:p-6">
          <DialogHeader className="mb-2">
            <DialogTitle className="flex items-center gap-2">
              <Layers className="size-5 text-primary" />
              {stagesDept?.name} — Stages & Responsibilities Management
            </DialogTitle>
            <DialogDescription className="text-xs">
              Allocate lifecycle stages, assign Lead or Participating roles, and customize engineering deliverables for {stagesDept?.name}.
            </DialogDescription>
          </DialogHeader>

          {stagesDept && (
            <DepartmentStagesManager
              departmentId={stagesDept.id}
              departmentName={stagesDept.name}
              isAdmin={true}
              className="border-0 shadow-none p-0"
              onChanged={() => {
                void loadDepartments();
              }}
            />
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
