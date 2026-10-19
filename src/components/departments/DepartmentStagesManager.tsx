import { useState } from "react";
import {
  AlertCircle,
  ArrowRight,
  CheckCircle2,
  ChevronRight,
  Clock,
  Compass,
  Crown,
  Edit2,
  FileCheck2,
  Layers,
  ListChecks,
  Plus,
  RefreshCw,
  RotateCcw,
  Sparkles,
  Tag,
  Trash2,
  Users,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import {
  getAssignedStagesForDepartment,
  getDepartmentStagesSummary,
  assignStageToDepartment,
  unassignStageFromDepartment,
  updateDepartmentStageRole,
  updateDepartmentStageStatus,
  updateDepartmentStageDeliverables,
  resetDepartmentStageResponsibilities,
  type DepartmentStageAssignment,
  type StageResponsibilityRole,
} from "@/lib/department-stage-responsibilities";
import { LIFECYCLE_STAGES, type StageStatus } from "@/lib/department-chronicles";
import { toast } from "sonner";

interface Props {
  departmentId: string;
  departmentName?: string;
  isAdmin?: boolean;
  compact?: boolean;
  className?: string;
  onChanged?: () => void;
}

const ROLE_CONFIG: Record<
  StageResponsibilityRole,
  { label: string; bg: string; text: string; border: string; icon: typeof Crown; desc: string }
> = {
  lead: {
    label: "Stage Lead",
    bg: "bg-emerald-500/15",
    text: "text-emerald-700 dark:text-emerald-400",
    border: "border-emerald-500/30",
    icon: Crown,
    desc: "Primary driver and owner for this stage",
  },
  coordinating: {
    label: "Coordinating",
    bg: "bg-blue-500/15",
    text: "text-blue-700 dark:text-blue-400",
    border: "border-blue-500/30",
    icon: Compass,
    desc: "Project management & cross-functional coordination",
  },
  participating: {
    label: "Participating",
    bg: "bg-purple-500/15",
    text: "text-purple-700 dark:text-purple-400",
    border: "border-purple-500/30",
    icon: Users,
    desc: "Supporting engineering / review contributor",
  },
};

const STATUS_CONFIG: Record<
  StageStatus,
  { label: string; bg: string; text: string; dot: string; next: StageStatus }
> = {
  completed: {
    label: "Completed",
    bg: "bg-emerald-500/15",
    text: "text-emerald-700 dark:text-emerald-400",
    dot: "bg-emerald-500",
    next: "in_progress",
  },
  in_progress: {
    label: "In Progress",
    bg: "bg-blue-500/15",
    text: "text-blue-700 dark:text-blue-400",
    dot: "bg-blue-500",
    next: "blocked",
  },
  blocked: {
    label: "Blocked",
    bg: "bg-rose-500/15",
    text: "text-rose-700 dark:text-rose-400",
    dot: "bg-rose-500",
    next: "waiting",
  },
  waiting: {
    label: "Waiting",
    bg: "bg-slate-500/15",
    text: "text-slate-700 dark:text-slate-400",
    dot: "bg-slate-400",
    next: "completed",
  },
  bypassed: {
    label: "Bypassed",
    bg: "bg-amber-500/15",
    text: "text-amber-700 dark:text-amber-400",
    dot: "bg-amber-500",
    next: "completed",
  },
};

export function DepartmentStagesManager({
  departmentId,
  departmentName = "Department",
  isAdmin = false,
  compact = false,
  className = "",
  onChanged,
}: Props) {
  const [viewMode, setViewMode] = useState<"assigned" | "all">("assigned");
  const [refreshKey, setRefreshKey] = useState(0);

  // Modal states
  const [editingStage, setEditingStage] = useState<DepartmentStageAssignment | null>(null);
  const [isAssignOpen, setIsAssignOpen] = useState(false);

  // Form states for assign/edit
  const [formStageNumber, setFormStageNumber] = useState<number>(1);
  const [formRole, setFormRole] = useState<StageResponsibilityRole>("lead");
  const [formStatus, setFormStatus] = useState<StageStatus>("in_progress");
  const [formDeliverables, setFormDeliverables] = useState<string>("");
  const [formNotes, setFormNotes] = useState<string>("");

  const assignedStages = getAssignedStagesForDepartment(departmentId);
  const summaryStages = getDepartmentStagesSummary(departmentId);

  const triggerChange = () => {
    setRefreshKey((k) => k + 1);
    if (onChanged) onChanged();
  };

  const handleOpenAssign = (preselectedStageNumber?: number) => {
    const stageNum = preselectedStageNumber || 1;
    setFormStageNumber(stageNum);
    setFormRole("participating");
    setFormStatus("in_progress");
    const stg = LIFECYCLE_STAGES.find((s) => s.stageNumber === stageNum);
    setFormDeliverables(`${stg?.shortName || "Stage"} engineering deliverables`);
    setFormNotes("");
    setIsAssignOpen(true);
  };

  const handleOpenEdit = (assignment: DepartmentStageAssignment) => {
    setEditingStage(assignment);
    setFormStageNumber(assignment.stageNumber);
    setFormRole(assignment.role);
    setFormStatus(assignment.status);
    setFormDeliverables(assignment.deliverables.join("\n"));
    setFormNotes(assignment.notes || "");
  };

  const handleSaveAssignment = () => {
    const deliverablesList = formDeliverables
      .split("\n")
      .map((d) => d.trim())
      .filter(Boolean);

    if (deliverablesList.length === 0) {
      toast.error("Please specify at least one deliverable or responsibility.");
      return;
    }

    assignStageToDepartment(
      departmentId,
      formStageNumber,
      formRole,
      deliverablesList,
      formStatus,
      formNotes.trim()
    );

    toast.success(
      `Stage ${formStageNumber} assigned to ${departmentName} as ${ROLE_CONFIG[formRole].label}`
    );
    setIsAssignOpen(false);
    setEditingStage(null);
    triggerChange();
  };

  const handleUnassign = (stageNumber: number) => {
    const ok = unassignStageFromDepartment(departmentId, stageNumber);
    if (ok) {
      toast.success(`Stage ${stageNumber} unassigned from ${departmentName}`);
      triggerChange();
    }
  };

  const handleCycleStatus = (assignment: DepartmentStageAssignment) => {
    const nextStatus = STATUS_CONFIG[assignment.status]?.next || "completed";
    updateDepartmentStageStatus(departmentId, assignment.stageNumber, nextStatus);
    toast.success(`Stage ${assignment.stageNumber} status updated to ${STATUS_CONFIG[nextStatus].label}`);
    triggerChange();
  };

  const handleQuickRoleChange = (stageNumber: number, role: StageResponsibilityRole) => {
    updateDepartmentStageRole(departmentId, stageNumber, role);
    toast.success(`Stage ${stageNumber} responsibility updated to ${ROLE_CONFIG[role].label}`);
    triggerChange();
  };

  const handleReset = () => {
    if (confirm(`Reset ${departmentName}'s stage responsibilities back to Master Plan baseline?`)) {
      resetDepartmentStageResponsibilities();
      toast.success("Stage responsibilities reset to Master Plan defaults");
      triggerChange();
    }
  };

  return (
    <Card className={`border shadow-sm ${className}`}>
      <CardHeader className="pb-3.5">
        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <Layers className="size-4 text-primary" />
              <CardTitle className="text-base font-semibold">
                {departmentName} Stages & Responsibilities
              </CardTitle>
              <Badge variant="outline" className="text-xs">
                {assignedStages.length} Assigned Stage{assignedStages.length === 1 ? "" : "s"}
              </Badge>
            </div>
            <CardDescription className="text-xs mt-1">
              Lifecycle stages given to {departmentName} as per responsibilities. Assign, customize deliverables, or update stage statuses anytime.
            </CardDescription>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto flex-wrap">
            <Button
              size="sm"
              variant="outline"
              onClick={() => handleOpenAssign()}
              className="h-8 text-xs gap-1"
            >
              <Plus className="size-3.5" />
              Assign Stage
            </Button>

            <Button
              size="sm"
              variant="ghost"
              onClick={handleReset}
              className="h-8 text-xs text-muted-foreground hover:text-foreground gap-1"
              title="Reset to Master Plan baseline"
            >
              <RotateCcw className="size-3.5" />
              Reset
            </Button>
          </div>
        </div>

        {/* View mode toggle */}
        <div className="flex items-center gap-1.5 pt-2 border-t mt-3 text-xs">
          <button
            onClick={() => setViewMode("assigned")}
            className={`rounded-md px-3 py-1 font-medium transition-colors ${
              viewMode === "assigned"
                ? "bg-primary text-primary-foreground"
                : "bg-muted/60 text-muted-foreground hover:bg-muted"
            }`}
          >
            Assigned Stages ({assignedStages.length})
          </button>
          <button
            onClick={() => setViewMode("all")}
            className={`rounded-md px-3 py-1 font-medium transition-colors ${
              viewMode === "all"
                ? "bg-primary text-primary-foreground"
                : "bg-muted/60 text-muted-foreground hover:bg-muted"
            }`}
          >
            All 9 Stages Matrix (Overview)
          </button>
        </div>
      </CardHeader>

      <CardContent className="space-y-3 pt-1">
        {viewMode === "assigned" ? (
          assignedStages.length === 0 ? (
            <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-8 text-center text-muted-foreground">
              <Layers className="size-7 opacity-40 mb-2" />
              <p className="text-sm font-medium">No stages assigned to {departmentName} yet</p>
              <p className="text-xs max-w-sm mt-1">
                Use the &quot;Assign Stage&quot; button above to allocate lifecycle stages according to this department&apos;s responsibilities.
              </p>
              <Button
                size="sm"
                variant="outline"
                onClick={() => handleOpenAssign()}
                className="mt-3 text-xs gap-1"
              >
                <Plus className="size-3.5" /> Assign First Stage
              </Button>
            </div>
          ) : (
            <div className="grid gap-3 sm:grid-cols-1 lg:grid-cols-2">
              {assignedStages.map((stg) => {
                const stageDef = LIFECYCLE_STAGES.find((s) => s.stageNumber === stg.stageNumber);
                const roleCfg = ROLE_CONFIG[stg.role] || ROLE_CONFIG.participating;
                const statusCfg = STATUS_CONFIG[stg.status] || STATUS_CONFIG.in_progress;
                const RoleIcon = roleCfg.icon;

                return (
                  <div
                    key={stg.id}
                    className="rounded-lg border bg-card p-3.5 space-y-3 transition-colors hover:border-primary/40 relative group"
                  >
                    {/* Header Row */}
                    <div className="flex items-start justify-between gap-2">
                      <div className="space-y-0.5 min-w-0">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <Badge variant="outline" className="font-mono text-[11px] font-semibold">
                            Stage {stg.stageNumber}
                          </Badge>
                          <span className="text-xs font-semibold text-foreground truncate">
                            {stageDef?.shortName || `Stage ${stg.stageNumber}`}
                          </span>
                        </div>
                        <p className="text-[11px] text-muted-foreground line-clamp-1">
                          {stageDef?.name}
                        </p>
                      </div>

                      {/* 1-Click Status Badge */}
                      <button
                        onClick={() => handleCycleStatus(stg)}
                        title="Click to cycle status (Completed → In Progress → Blocked → Waiting → Bypassed)"
                        className={`inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-[11px] font-medium border cursor-pointer transition-all hover:scale-105 shrink-0 ${statusCfg.bg} ${statusCfg.text}`}
                      >
                        <span className={`size-1.5 rounded-full ${statusCfg.dot}`} />
                        {statusCfg.label}
                      </button>
                    </div>

                    {/* Role Selector & Description */}
                    <div className="flex items-center justify-between gap-2 rounded-md bg-muted/30 px-2.5 py-1.5 text-xs">
                      <div className="flex items-center gap-1.5">
                        <RoleIcon className={`size-3.5 ${roleCfg.text}`} />
                        <span className="font-medium text-foreground">Role:</span>
                        <Select
                          value={stg.role}
                          onValueChange={(val) =>
                            handleQuickRoleChange(stg.stageNumber, val as StageResponsibilityRole)
                          }
                        >
                          <SelectTrigger className="h-6 w-28 text-[11px] px-2 py-0 border-0 bg-transparent font-medium text-foreground">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="lead">Stage Lead</SelectItem>
                            <SelectItem value="coordinating">Coordinating</SelectItem>
                            <SelectItem value="participating">Participating</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>

                      <span className="text-[10px] text-muted-foreground hidden sm:inline">
                        {roleCfg.desc}
                      </span>
                    </div>

                    {/* Deliverables List */}
                    <div className="space-y-1.5">
                      <div className="flex items-center justify-between text-[11px] text-muted-foreground font-medium">
                        <span className="flex items-center gap-1">
                          <ListChecks className="size-3 text-primary" /> Key Responsibilities & Deliverables:
                        </span>
                        <span>{stg.deliverables.length}</span>
                      </div>
                      <ul className="space-y-1 text-xs">
                        {stg.deliverables.map((deliv, dIdx) => (
                          <li
                            key={dIdx}
                            className="flex items-start gap-1.5 text-muted-foreground leading-snug"
                          >
                            <CheckCircle2 className="size-3 text-primary shrink-0 mt-0.5" />
                            <span className="text-foreground/90">{deliv}</span>
                          </li>
                        ))}
                      </ul>
                    </div>

                    {/* Notes if present */}
                    {stg.notes && (
                      <p className="text-[11px] text-muted-foreground italic bg-muted/20 p-2 rounded border-l-2 border-primary/40">
                        {stg.notes}
                      </p>
                    )}

                    {/* Bottom Action Footer */}
                    <div className="flex items-center justify-end gap-1 pt-1 border-t text-xs">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleOpenEdit(stg)}
                        className="h-6 px-2 text-[11px] gap-1 text-muted-foreground hover:text-foreground"
                      >
                        <Edit2 className="size-3" /> Edit
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleUnassign(stg.stageNumber)}
                        className="h-6 px-2 text-[11px] gap-1 text-rose-600 hover:text-rose-700 hover:bg-rose-500/10"
                      >
                        <Trash2 className="size-3" /> Remove
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          )
        ) : (
          /* All 9 Stages Matrix Overview */
          <div className="space-y-2">
            <p className="text-xs text-muted-foreground">
              Master 9-stage lifecycle overview. Highlights stages currently given to {departmentName}. Click &quot;+ Give Stage&quot; to allocate any unassigned stage.
            </p>

            <div className="divide-y rounded-md border bg-card text-xs">
              {summaryStages.map((stg) => {
                const assigned = stg.isAssigned;
                const assignment = stg.assignment;
                const roleCfg = assignment ? ROLE_CONFIG[assignment.role] : null;

                return (
                  <div
                    key={stg.stageNumber}
                    className={`flex flex-col sm:flex-row sm:items-center justify-between p-3 gap-2 transition-colors ${
                      assigned ? "bg-muted/20" : "opacity-75 hover:bg-muted/10"
                    }`}
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <span className="font-mono font-semibold px-2 py-0.5 rounded bg-muted text-[11px] shrink-0">
                        Stage {stg.stageNumber}
                      </span>
                      <div className="min-w-0">
                        <p className="font-medium text-foreground truncate">{stg.stageName}</p>
                        <p className="text-[11px] text-muted-foreground">
                          {assigned && assignment
                            ? `${assignment.deliverables.length} deliverables assigned · ${STATUS_CONFIG[assignment.status].label}`
                            : "Not assigned to this department"}
                        </p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 self-end sm:self-auto shrink-0">
                      {assigned && roleCfg ? (
                        <>
                          <Badge
                            variant="secondary"
                            className={`text-[10px] gap-1 ${roleCfg.bg} ${roleCfg.text}`}
                          >
                            <roleCfg.icon className="size-3" />
                            {roleCfg.label}
                          </Badge>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleOpenEdit(assignment!)}
                            className="h-7 px-2 text-xs"
                          >
                            Edit
                          </Button>
                        </>
                      ) : (
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleOpenAssign(stg.stageNumber)}
                          className="h-7 px-2.5 text-xs gap-1 border-primary/30 text-primary hover:bg-primary/5"
                        >
                          <Plus className="size-3" /> Give Stage
                        </Button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </CardContent>

      {/* Assign or Edit Stage Dialog */}
      <Dialog
        open={isAssignOpen || Boolean(editingStage)}
        onOpenChange={(open) => {
          if (!open) {
            setIsAssignOpen(false);
            setEditingStage(null);
          }
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Layers className="size-4 text-primary" />
              {editingStage
                ? `Edit Stage ${editingStage.stageNumber} Responsibilities`
                : `Assign Stage to ${departmentName}`}
            </DialogTitle>
            <DialogDescription className="text-xs">
              Configure responsibility role, execution status, and key deliverables for {departmentName}.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3.5 py-2 text-xs">
            {/* Stage Selector */}
            <div>
              <label className="font-medium text-foreground block mb-1">Lifecycle Stage</label>
              {editingStage ? (
                <div className="p-2 rounded bg-muted/40 font-mono text-xs">
                  {LIFECYCLE_STAGES.find((s) => s.stageNumber === editingStage.stageNumber)?.name}
                </div>
              ) : (
                <Select
                  value={String(formStageNumber)}
                  onValueChange={(val) => setFormStageNumber(Number(val))}
                >
                  <SelectTrigger className="h-8 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {LIFECYCLE_STAGES.map((s) => (
                      <SelectItem key={s.stageNumber} value={String(s.stageNumber)}>
                        Stage {s.stageNumber}: {s.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            </div>

            {/* Role & Status Row */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="font-medium text-foreground block mb-1">Responsibility Role</label>
                <Select
                  value={formRole}
                  onValueChange={(val) => setFormRole(val as StageResponsibilityRole)}
                >
                  <SelectTrigger className="h-8 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="lead">Stage Lead (Owner)</SelectItem>
                    <SelectItem value="coordinating">Coordinating (PM)</SelectItem>
                    <SelectItem value="participating">Participating (Support)</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div>
                <label className="font-medium text-foreground block mb-1">Stage Status</label>
                <Select
                  value={formStatus}
                  onValueChange={(val) => setFormStatus(val as StageStatus)}
                >
                  <SelectTrigger className="h-8 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="completed">Completed</SelectItem>
                    <SelectItem value="in_progress">In Progress</SelectItem>
                    <SelectItem value="blocked">Blocked</SelectItem>
                    <SelectItem value="waiting">Waiting</SelectItem>
                    <SelectItem value="bypassed">Bypassed</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Deliverables (one per line) */}
            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="font-medium text-foreground">
                  Responsibilities & Deliverables
                </label>
                <span className="text-[10px] text-muted-foreground">One item per line</span>
              </div>
              <Textarea
                rows={4}
                value={formDeliverables}
                onChange={(e) => setFormDeliverables(e.target.value)}
                placeholder="e.g.&#10;Thermal dissipation calculation&#10;SolidWorks IP67 seal groove optimization"
                className="text-xs resize-none"
              />
            </div>

            {/* Notes */}
            <div>
              <label className="font-medium text-foreground block mb-1">
                Scope / Alignment Notes (Optional)
              </label>
              <Input
                value={formNotes}
                onChange={(e) => setFormNotes(e.target.value)}
                placeholder="e.g. Lead signed off in coordination with PM"
                className="h-8 text-xs"
              />
            </div>
          </div>

          <DialogFooter className="gap-2 sm:gap-0">
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setIsAssignOpen(false);
                setEditingStage(null);
              }}
            >
              Cancel
            </Button>
            <Button size="sm" onClick={handleSaveAssignment}>
              Save Stage Assignment
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
