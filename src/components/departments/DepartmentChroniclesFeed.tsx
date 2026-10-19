import { useState, useMemo } from "react";
import { formatDistanceToNow, format } from "date-fns";
import {
  AlertCircle,
  ArrowRightLeft,
  Calendar,
  CheckCircle2,
  ChevronDown,
  Clock,
  Edit3,
  Filter,
  Flag,
  FolderGit2,
  HelpCircle,
  Info,
  Layers,
  Megaphone,
  MessageSquare,
  Pin,
  Plus,
  RefreshCw,
  RotateCcw,
  Search,
  Tag,
  Trash2,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle
} from "@/components/ui/dialog";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue
} from "@/components/ui/select";
import {
  fetchDepartmentChronicles,
  createDepartmentChronicle,
  updateDepartmentChronicle,
  quickUpdateChronicleStatus,
  quickUpdateChronicleStage,
  deleteDepartmentChronicle,
  resetDepartmentChronicles,
  LIFECYCLE_STAGES,
  type DepartmentChronicle,
  type ChronicleCategory,
  type StageStatus,
} from "@/lib/department-chronicles";
import { getAssignedStagesForDepartment } from "@/lib/department-stage-responsibilities";
import { useAuth } from "@/hooks/useAuth";
import { toast } from "sonner";

interface Props {
  departmentId?: string;
  departmentName?: string;
  defaultStageNumber?: number;
  className?: string;
}

const CATEGORY_CONFIG: Record<
  ChronicleCategory,
  { label: string; bg: string; text: string; border: string; icon: typeof Flag }
> = {
  milestone: {
    label: "Milestone",
    bg: "bg-emerald-500/10",
    text: "text-emerald-700 dark:text-emerald-400",
    border: "border-emerald-500/30",
    icon: CheckCircle2,
  },
  decision: {
    label: "Decision",
    bg: "bg-violet-500/10",
    text: "text-violet-700 dark:text-violet-400",
    border: "border-violet-500/30",
    icon: Flag,
  },
  update: {
    label: "Update",
    bg: "bg-sky-500/10",
    text: "text-sky-700 dark:text-sky-400",
    border: "border-sky-500/30",
    icon: MessageSquare,
  },
  notice: {
    label: "Notice",
    bg: "bg-amber-500/10",
    text: "text-amber-700 dark:text-amber-400",
    border: "border-amber-500/30",
    icon: Megaphone,
  },
  incident: {
    label: "Incident",
    bg: "bg-rose-500/10",
    text: "text-rose-700 dark:text-rose-400",
    border: "border-rose-500/30",
    icon: Info,
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

export function DepartmentChroniclesFeed({
  departmentId = "all",
  departmentName,
  defaultStageNumber,
  className,
}: Props) {
  const { user } = useAuth();
  const [chronicles, setChronicles] = useState<DepartmentChronicle[]>(() =>
    fetchDepartmentChronicles(departmentId, defaultStageNumber)
  );

  // Filters
  const assignedStages = useMemo(
    () => (departmentId && departmentId !== "all" ? getAssignedStagesForDepartment(departmentId) : []),
    [departmentId]
  );
  const [onlyAssignedStages, setOnlyAssignedStages] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string>("all");
  const [selectedStage, setSelectedStage] = useState<string>(
    defaultStageNumber ? String(defaultStageNumber) : "all"
  );
  const [selectedStatus, setSelectedStatus] = useState<string>("all");
  const [searchQuery, setSearchQuery] = useState("");

  // Dialog & editing state
  const [editingEntry, setEditingEntry] = useState<DepartmentChronicle | null>(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);

  // Form fields
  const [formTitle, setFormTitle] = useState("");
  const [formCategory, setFormCategory] = useState<ChronicleCategory>("milestone");
  const [formStageNumber, setFormStageNumber] = useState<number>(defaultStageNumber || 1);
  const [formStageStatus, setFormStageStatus] = useState<StageStatus>("completed");
  const [formDepartmentId, setFormDepartmentId] = useState<string>(departmentId !== "all" ? departmentId : "mechanical");
  const [formProjectCode, setFormProjectCode] = useState("PRJ-TLM-002");
  const [formContent, setFormContent] = useState("");
  const [formDeliverables, setFormDeliverables] = useState("");
  const [formAuthorName, setFormAuthorName] = useState(user?.email?.split("@")[0] || "Department Lead");
  const [formAuthorRole, setFormAuthorRole] = useState("Engineering Lead");
  const [formPinned, setFormPinned] = useState(false);

  const refresh = () => {
    const stageNum = selectedStage !== "all" ? Number(selectedStage) : undefined;
    setChronicles(fetchDepartmentChronicles(departmentId, stageNum));
  };

  const handleOpenCreate = () => {
    setFormTitle("");
    setFormCategory("milestone");
    setFormStageNumber(selectedStage !== "all" ? Number(selectedStage) : 1);
    setFormStageStatus("completed");
    setFormDepartmentId(departmentId !== "all" ? departmentId : "mechanical");
    setFormProjectCode("PRJ-TLM-002");
    setFormContent("");
    setFormDeliverables("");
    setFormAuthorName(user?.email?.split("@")[0] || "Lead");
    setFormAuthorRole("Lead");
    setFormPinned(false);
    setIsCreateOpen(true);
  };

  const handleOpenEdit = (entry: DepartmentChronicle) => {
    setEditingEntry(entry);
    setFormTitle(entry.title);
    setFormCategory(entry.category);
    setFormStageNumber(entry.stageNumber || 1);
    setFormStageStatus(entry.stageStatus || "completed");
    setFormDepartmentId(entry.departmentId);
    setFormProjectCode(entry.projectCode || "PRJ-TLM-002");
    setFormContent(entry.content);
    setFormDeliverables((entry.deliverables || []).join("\n"));
    setFormAuthorName(entry.authorName);
    setFormAuthorRole(entry.authorRole);
    setFormPinned(Boolean(entry.pinned));
  };

  const handleSave = () => {
    if (!formTitle.trim()) {
      toast.error("Please provide a milestone title.");
      return;
    }
    if (!formContent.trim()) {
      toast.error("Please provide milestone details or notes.");
      return;
    }

    const deliverablesList = formDeliverables
      .split("\n")
      .map((d) => d.trim())
      .filter(Boolean);

    if (editingEntry) {
      updateDepartmentChronicle(editingEntry.id, {
        title: formTitle.trim(),
        category: formCategory,
        stageNumber: formStageNumber,
        stageStatus: formStageStatus,
        departmentId: formDepartmentId,
        projectCode: formProjectCode,
        content: formContent.trim(),
        deliverables: deliverablesList,
        authorName: formAuthorName.trim() || "Lead",
        authorRole: formAuthorRole.trim() || "Staff",
        pinned: formPinned,
      });
      toast.success("Milestone chronicle updated successfully");
      setEditingEntry(null);
    } else {
      createDepartmentChronicle({
        departmentId: formDepartmentId,
        projectCode: formProjectCode,
        stageNumber: formStageNumber,
        stageStatus: formStageStatus,
        title: formTitle.trim(),
        category: formCategory,
        content: formContent.trim(),
        deliverables: deliverablesList,
        authorName: formAuthorName.trim() || "Lead",
        authorRole: formAuthorRole.trim() || "Staff",
        pinned: formPinned,
      });
      toast.success("Milestone chronicle posted successfully");
      setIsCreateOpen(false);
    }
    refresh();
  };

  const handleQuickStatusCycle = (entry: DepartmentChronicle, e: React.MouseEvent) => {
    e.stopPropagation();
    const currentStatus = entry.stageStatus || "completed";
    const nextStatus = STATUS_CONFIG[currentStatus].next;
    quickUpdateChronicleStatus(entry.id, nextStatus);
    toast.success(`Updated status to "${STATUS_CONFIG[nextStatus].label}"`);
    refresh();
  };

  const handleQuickStageChange = (entry: DepartmentChronicle, newStageNumber: number) => {
    quickUpdateChronicleStage(entry.id, newStageNumber);
    toast.success(`Moved milestone to Stage ${newStageNumber}`);
    refresh();
  };

  const handleDelete = (id: string, title: string) => {
    if (confirm(`Are you sure you want to delete milestone: "${title}"?`)) {
      deleteDepartmentChronicle(id);
      toast.success("Milestone removed from chronicles");
      refresh();
    }
  };

  const handleResetToStandard = () => {
    if (confirm("Reset chronicles back to the standard 9-stage lifecycle milestones?")) {
      resetDepartmentChronicles();
      toast.success("Chronicles reset to standard 9-stage milestones");
      refresh();
    }
  };

  const filtered = chronicles.filter((c) => {
    if (onlyAssignedStages && assignedStages.length > 0) {
      if (!c.stageNumber || !assignedStages.some((a) => a.stageNumber === c.stageNumber)) return false;
    }
    if (selectedCategory !== "all" && c.category !== selectedCategory) return false;
    if (selectedStage !== "all" && c.stageNumber !== Number(selectedStage)) return false;
    if (selectedStatus !== "all" && c.stageStatus !== selectedStatus) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      return (
        c.title.toLowerCase().includes(q) ||
        c.content.toLowerCase().includes(q) ||
        c.authorName.toLowerCase().includes(q) ||
        (c.projectCode && c.projectCode.toLowerCase().includes(q)) ||
        (c.stageName && c.stageName.toLowerCase().includes(q))
      );
    }
    return true;
  });

  return (
    <Card className={className}>
      <CardHeader className="pb-3 space-y-3">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <CardTitle className="text-base flex items-center gap-2">
              <Layers className="size-4 text-primary" />
              {departmentName ? `${departmentName} Chronicles & Stage Milestones` : "Product Lifecycle Chronicles & Milestones"}
            </CardTitle>
            <CardDescription className="text-xs">
              Chronological log of all 9 lifecycle stage milestones, gate reviews, and technical decisions. Click any status or stage to change here and there.
            </CardDescription>
            {assignedStages.length > 0 && (
              <div className="flex items-center gap-2 pt-1.5">
                <button
                  type="button"
                  onClick={() => setOnlyAssignedStages(!onlyAssignedStages)}
                  className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-[11px] font-medium border transition-colors ${
                    onlyAssignedStages
                      ? "bg-primary text-primary-foreground border-primary"
                      : "bg-muted/60 text-muted-foreground border-border hover:bg-muted"
                  }`}
                >
                  <Tag className="size-3" />
                  {onlyAssignedStages
                    ? `Showing ${assignedStages.length} Assigned Stages Only`
                    : `Show Only Assigned Stages (${assignedStages.length})`}
                </button>
              </div>
            )}
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <Button
              variant="outline"
              size="sm"
              onClick={handleResetToStandard}
              className="h-8 text-xs gap-1 text-muted-foreground hover:text-foreground"
              title="Reset all milestones back to standard 9-stage baseline"
            >
              <RotateCcw className="size-3" />
              Reset Stages
            </Button>
            <Button size="sm" onClick={handleOpenCreate} className="h-8 gap-1.5">
              <Plus className="size-3.5" />
              Add Milestone
            </Button>
          </div>
        </div>

        {/* Multi-tier Filter Bar */}
        <div className="grid gap-2.5 sm:grid-cols-2 lg:grid-cols-4 pt-1">
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-2.5 top-2.5 size-3.5 text-muted-foreground" />
            <Input
              placeholder="Search title, project, remarks…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="h-8 pl-8 text-xs"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery("")}
                className="absolute right-2.5 top-2.5 text-muted-foreground hover:text-foreground"
              >
                <X className="size-3" />
              </button>
            )}
          </div>

          {/* Stage Filter */}
          <Select value={selectedStage} onValueChange={(val) => { setSelectedStage(val); }}>
            <SelectTrigger className="h-8 text-xs">
              <SelectValue placeholder="All 9 Stages" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All 9 Stages ({chronicles.length})</SelectItem>
              {LIFECYCLE_STAGES.map((s) => {
                const assigned = assignedStages.find((a) => a.stageNumber === s.stageNumber);
                const roleBadge = assigned ? (assigned.role === "lead" ? "★ Lead" : assigned.role === "coordinating" ? "★ Coord" : "★ Part") : "";
                return (
                  <SelectItem key={s.stageNumber} value={String(s.stageNumber)}>
                    {s.name} {roleBadge ? `(${roleBadge})` : ""} ({chronicles.filter((c) => c.stageNumber === s.stageNumber).length})
                  </SelectItem>
                );
              })}
            </SelectContent>
          </Select>

          {/* Status Filter */}
          <Select value={selectedStatus} onValueChange={setSelectedStatus}>
            <SelectTrigger className="h-8 text-xs">
              <SelectValue placeholder="All Statuses" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Statuses</SelectItem>
              <SelectItem value="completed">Completed</SelectItem>
              <SelectItem value="in_progress">In Progress</SelectItem>
              <SelectItem value="blocked">Blocked</SelectItem>
              <SelectItem value="waiting">Waiting</SelectItem>
              <SelectItem value="bypassed">Bypassed</SelectItem>
            </SelectContent>
          </Select>

          {/* Category Filter */}
          <Select value={selectedCategory} onValueChange={setSelectedCategory}>
            <SelectTrigger className="h-8 text-xs">
              <SelectValue placeholder="All Categories" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Categories</SelectItem>
              <SelectItem value="milestone">Milestones</SelectItem>
              <SelectItem value="decision">Decisions</SelectItem>
              <SelectItem value="update">Updates</SelectItem>
              <SelectItem value="notice">Notices</SelectItem>
              <SelectItem value="incident">Incidents</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </CardHeader>

      <CardContent>
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-10 text-center text-muted-foreground">
            <Layers className="size-8 opacity-40 mb-2" />
            <p className="text-sm font-medium">No stage milestones found</p>
            <p className="text-xs max-w-sm mt-1">
              {searchQuery || selectedStage !== "all" || selectedStatus !== "all"
                ? "No entries match your active filters. Try clearing the filters or click 'Reset Stages'."
                : "Record your first stage milestone using the 'Add Milestone' button."}
            </p>
          </div>
        ) : (
          <div className="space-y-3.5 relative before:absolute before:inset-0 before:left-3.5 before:w-0.5 before:bg-border before:z-0">
            {filtered.map((entry) => {
              const catConfig = CATEGORY_CONFIG[entry.category] || CATEGORY_CONFIG.update;
              const statusCfg = STATUS_CONFIG[entry.stageStatus || "completed"] || STATUS_CONFIG.completed;
              const Icon = catConfig.icon;

              return (
                <div key={entry.id} className="relative z-10 pl-8 group">
                  {/* Timeline dot */}
                  <div
                    className={`absolute left-1.5 top-3 size-4 rounded-full border-2 bg-background flex items-center justify-center ${catConfig.text} ${catConfig.border}`}
                  >
                    <div className="size-1.5 rounded-full bg-current" />
                  </div>

                  <div className="rounded-lg border bg-card p-3.5 transition-colors hover:border-primary/40 space-y-2.5">
                    {/* Header Row */}
                    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        {/* Stage Badge with dropdown indicator */}
                        {entry.stageNumber && (
                          <div className="flex items-center gap-1">
                            <Select
                              value={String(entry.stageNumber)}
                              onValueChange={(val) => handleQuickStageChange(entry, Number(val))}
                            >
                              <SelectTrigger className="h-6 px-2 text-[11px] font-semibold bg-muted/80 border-primary/20 hover:bg-muted gap-1 rounded">
                                <SelectValue>{`Stage ${entry.stageNumber}: ${LIFECYCLE_STAGES.find((s) => s.stageNumber === entry.stageNumber)?.shortName || ""}`}</SelectValue>
                              </SelectTrigger>
                              <SelectContent>
                                {LIFECYCLE_STAGES.map((s) => (
                                  <SelectItem key={s.stageNumber} value={String(s.stageNumber)}>
                                    {s.name}
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                          </div>
                        )}

                        {/* Interactive Status Pill - Click to cycle status */}
                        <button
                          onClick={(e) => handleQuickStatusCycle(entry, e)}
                          className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium cursor-pointer transition-colors ${statusCfg.bg} ${statusCfg.text} hover:opacity-80`}
                          title={`Status: ${statusCfg.label}. Click to cycle to ${STATUS_CONFIG[statusCfg.next].label}.`}
                        >
                          <span className={`size-1.5 rounded-full ${statusCfg.dot}`} />
                          {statusCfg.label}
                        </button>

                        {/* Category badge */}
                        <Badge
                          variant="outline"
                          className={`text-[10px] gap-1 py-0 px-1.5 font-medium ${catConfig.bg} ${catConfig.text} ${catConfig.border}`}
                        >
                          <Icon className="size-2.5" />
                          {catConfig.label}
                        </Badge>

                        {/* Project Code */}
                        {entry.projectCode && (
                          <Badge variant="secondary" className="text-[10px] font-mono py-0 px-1.5">
                            <FolderGit2 className="size-2.5 mr-1" />
                            {entry.projectCode}
                          </Badge>
                        )}

                        {/* Department Tag */}
                        {entry.departmentId && entry.departmentId !== "all" && (
                          <span className="text-[10px] uppercase font-mono text-muted-foreground bg-muted/60 px-1.5 py-0.5 rounded">
                            {entry.departmentId}
                          </span>
                        )}

                        {entry.pinned && (
                          <Badge variant="secondary" className="text-[10px] gap-1 py-0 px-1.5">
                            <Pin className="size-2.5" /> Pinned
                          </Badge>
                        )}
                      </div>

                      {/* Action buttons */}
                      <div className="flex items-center gap-1 shrink-0 self-end sm:self-auto">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-7 text-muted-foreground hover:text-foreground"
                          onClick={() => handleOpenEdit(entry)}
                          title="Edit milestone & deliverables"
                        >
                          <Edit3 className="size-3.5" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-7 text-destructive hover:text-destructive hover:bg-destructive/10"
                          onClick={() => handleDelete(entry.id, entry.title)}
                          title="Delete milestone"
                        >
                          <Trash2 className="size-3.5" />
                        </Button>
                      </div>
                    </div>

                    {/* Milestone Title */}
                    <h4 className="text-sm font-semibold text-foreground">
                      {entry.title}
                    </h4>

                    {/* Content / Remarks */}
                    <p className="text-xs text-muted-foreground leading-relaxed whitespace-pre-line">
                      {entry.content}
                    </p>

                    {/* Deliverables Checklist (if present) */}
                    {entry.deliverables && entry.deliverables.length > 0 && (
                      <div className="rounded border bg-muted/20 p-2.5 space-y-1.5 text-xs">
                        <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider">
                          Key Deliverables / Gate Criteria:
                        </p>
                        <ul className="space-y-1">
                          {entry.deliverables.map((deliv, dIdx) => (
                            <li key={dIdx} className="flex items-start gap-1.5 text-foreground/90">
                              <CheckCircle2 className="size-3 text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                              <span>{deliv}</span>
                            </li>
                          ))}
                        </ul>
                      </div>
                    )}

                    {/* Footer Info */}
                    <div className="flex items-center justify-between pt-1 border-t border-border/50 text-[11px] text-muted-foreground">
                      <div className="flex items-center gap-1.5">
                        <span className="font-medium text-foreground">{entry.authorName}</span>
                        <span>·</span>
                        <span className="italic">{entry.authorRole}</span>
                        {entry.projectName && (
                          <>
                            <span className="hidden md:inline">·</span>
                            <span className="hidden md:inline text-muted-foreground line-clamp-1">{entry.projectName}</span>
                          </>
                        )}
                      </div>
                      <span title={format(new Date(entry.createdAt), "PPpp")}>
                        {formatDistanceToNow(new Date(entry.createdAt), { addSuffix: true })}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>

      {/* Create / Edit Milestone Dialog */}
      <Dialog
        open={isCreateOpen || Boolean(editingEntry)}
        onOpenChange={(open) => {
          if (!open) {
            setIsCreateOpen(false);
            setEditingEntry(null);
          }
        }}
      >
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {editingEntry ? "Edit Stage Milestone" : "Add Stage Milestone"}
            </DialogTitle>
            <DialogDescription className="text-xs">
              Change stage, status, deliverables, and remarks for this product lifecycle milestone.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3.5 py-2">
            <div>
              <label className="text-xs font-medium">Milestone Title *</label>
              <Input
                placeholder="e.g., iCAT AIS-140 Homologation Certification Received"
                value={formTitle}
                onChange={(e) => setFormTitle(e.target.value)}
                className="mt-1 text-sm"
              />
            </div>

            {/* Stage & Status Row */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-medium">Lifecycle Stage</label>
                <Select
                  value={String(formStageNumber)}
                  onValueChange={(val) => setFormStageNumber(Number(val))}
                >
                  <SelectTrigger className="mt-1 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {LIFECYCLE_STAGES.map((s) => (
                      <SelectItem key={s.stageNumber} value={String(s.stageNumber)}>
                        {s.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div>
                <label className="text-xs font-medium">Stage Status</label>
                <Select
                  value={formStageStatus}
                  onValueChange={(val) => setFormStageStatus(val as StageStatus)}
                >
                  <SelectTrigger className="mt-1 text-xs">
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

            {/* Department & Project Row */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-medium">Department</label>
                <Select
                  value={formDepartmentId}
                  onValueChange={setFormDepartmentId}
                >
                  <SelectTrigger className="mt-1 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="mechanical">Mechanical</SelectItem>
                    <SelectItem value="rnd">Hardware & R&D</SelectItem>
                    <SelectItem value="procurement">Procurement</SelectItem>
                    <SelectItem value="production">Production</SelectItem>
                    <SelectItem value="operations">Operations / QA</SelectItem>
                    <SelectItem value="sales">Sales</SelectItem>
                    <SelectItem value="all">Cross-Department</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div>
                <label className="text-xs font-medium">Project</label>
                <Select
                  value={formProjectCode}
                  onValueChange={setFormProjectCode}
                >
                  <SelectTrigger className="mt-1 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="PRJ-TLM-002">PRJ-TLM-002 (Mahindra Auto)</SelectItem>
                    <SelectItem value="PRJ-TLM-001">PRJ-TLM-001 (Tata Motors CV)</SelectItem>
                    <SelectItem value="GENERAL">General Platform</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Category & Author Row */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-medium">Category</label>
                <Select
                  value={formCategory}
                  onValueChange={(val) => setFormCategory(val as ChronicleCategory)}
                >
                  <SelectTrigger className="mt-1 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="milestone">Milestone</SelectItem>
                    <SelectItem value="decision">Decision</SelectItem>
                    <SelectItem value="update">Update</SelectItem>
                    <SelectItem value="notice">Notice</SelectItem>
                    <SelectItem value="incident">Incident</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div>
                <label className="text-xs font-medium">Author Name</label>
                <Input
                  value={formAuthorName}
                  onChange={(e) => setFormAuthorName(e.target.value)}
                  className="mt-1 text-xs"
                />
              </div>
            </div>

            {/* Remarks / Details */}
            <div>
              <label className="text-xs font-medium">Milestone Description & Evidence Remarks *</label>
              <Textarea
                placeholder="Describe what was achieved, decided, or tested in this stage…"
                value={formContent}
                onChange={(e) => setFormContent(e.target.value)}
                rows={3}
                className="mt-1 text-xs"
              />
            </div>

            {/* Deliverables / Checklist Items */}
            <div>
              <label className="text-xs font-medium">Stage Deliverables / Checklist (One per line)</label>
              <Textarea
                placeholder="e.g.&#10;iCAT AIS-140 Homologation Certificate&#10;NABL Battery Safety Test Report&#10;Environmental Chamber Shock Log"
                value={formDeliverables}
                onChange={(e) => setFormDeliverables(e.target.value)}
                rows={3}
                className="mt-1 text-xs font-mono"
              />
            </div>

            {/* Pinned */}
            <div className="flex items-center gap-2 pt-1">
              <input
                type="checkbox"
                id="pinMilestone"
                checked={formPinned}
                onChange={(e) => setFormPinned(e.target.checked)}
                className="rounded border-input text-primary"
              />
              <label htmlFor="pinMilestone" className="text-xs text-muted-foreground cursor-pointer">
                Pin to top of chronicle list
              </label>
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setIsCreateOpen(false);
                setEditingEntry(null);
              }}
            >
              Cancel
            </Button>
            <Button size="sm" onClick={handleSave}>
              {editingEntry ? "Save Changes" : "Create Milestone"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
