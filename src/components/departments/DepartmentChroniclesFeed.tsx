import { useState } from "react";
import { formatDistanceToNow, format } from "date-fns";
import {
  Calendar, CheckCircle2, ChevronRight, Edit3, Filter, Flag, Info,
  Megaphone, MessageSquare, MoreHorizontal, Pin, Plus, Search, Tag, Trash2, X
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
  deleteDepartmentChronicle,
  type DepartmentChronicle,
  type ChronicleCategory,
} from "@/lib/department-chronicles";
import { useAuth } from "@/hooks/useAuth";
import { toast } from "sonner";

interface Props {
  departmentId?: string;
  departmentName?: string;
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

export function DepartmentChroniclesFeed({
  departmentId = "all",
  departmentName,
  className,
}: Props) {
  const { user } = useAuth();
  const [chronicles, setChronicles] = useState<DepartmentChronicle[]>(() =>
    fetchDepartmentChronicles(departmentId)
  );
  const [selectedCategory, setSelectedCategory] = useState<string>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [editingEntry, setEditingEntry] = useState<DepartmentChronicle | null>(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);

  // Form state
  const [formTitle, setFormTitle] = useState("");
  const [formCategory, setFormCategory] = useState<ChronicleCategory>("update");
  const [formContent, setFormContent] = useState("");
  const [formAuthorName, setFormAuthorName] = useState(user?.email?.split("@")[0] || "Department Lead");
  const [formAuthorRole, setFormAuthorRole] = useState("Staff");
  const [formPinned, setFormPinned] = useState(false);

  const refresh = () => {
    setChronicles(fetchDepartmentChronicles(departmentId));
  };

  const handleOpenCreate = () => {
    setFormTitle("");
    setFormCategory("update");
    setFormContent("");
    setFormAuthorName(user?.email?.split("@")[0] || "Department Lead");
    setFormAuthorRole("Lead");
    setFormPinned(false);
    setIsCreateOpen(true);
  };

  const handleOpenEdit = (entry: DepartmentChronicle) => {
    setEditingEntry(entry);
    setFormTitle(entry.title);
    setFormCategory(entry.category);
    setFormContent(entry.content);
    setFormAuthorName(entry.authorName);
    setFormAuthorRole(entry.authorRole);
    setFormPinned(Boolean(entry.pinned));
  };

  const handleSave = () => {
    if (!formTitle.trim()) {
      toast.error("Please provide a title for the chronicle entry.");
      return;
    }
    if (!formContent.trim()) {
      toast.error("Please provide details or notes for the chronicle entry.");
      return;
    }

    if (editingEntry) {
      updateDepartmentChronicle(editingEntry.id, {
        title: formTitle.trim(),
        category: formCategory,
        content: formContent.trim(),
        authorName: formAuthorName.trim() || "Lead",
        authorRole: formAuthorRole.trim() || "Staff",
        pinned: formPinned,
      });
      toast.success("Chronicle entry updated successfully");
      setEditingEntry(null);
    } else {
      createDepartmentChronicle({
        departmentId: departmentId || "all",
        title: formTitle.trim(),
        category: formCategory,
        content: formContent.trim(),
        authorName: formAuthorName.trim() || "Lead",
        authorRole: formAuthorRole.trim() || "Staff",
        pinned: formPinned,
      });
      toast.success("Chronicle entry posted successfully");
      setIsCreateOpen(false);
    }
    refresh();
  };

  const handleDelete = (id: string, title: string) => {
    if (confirm(`Are you sure you want to delete "${title}"?`)) {
      deleteDepartmentChronicle(id);
      toast.success("Chronicle entry deleted");
      refresh();
    }
  };

  const filtered = chronicles.filter((c) => {
    if (selectedCategory !== "all" && c.category !== selectedCategory) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      return (
        c.title.toLowerCase().includes(q) ||
        c.content.toLowerCase().includes(q) ||
        c.authorName.toLowerCase().includes(q)
      );
    }
    return true;
  });

  return (
    <Card className={className}>
      <CardHeader className="pb-3">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <CardTitle className="text-base flex items-center gap-2">
              <Calendar className="size-4 text-primary" />
              {departmentName ? `${departmentName} Chronicles` : "Department Chronicles & Milestones"}
            </CardTitle>
            <CardDescription className="text-xs">
              Chronological log of department milestones, technical decisions, and operational updates.
            </CardDescription>
          </div>
          <Button size="sm" onClick={handleOpenCreate} className="h-8 gap-1.5 shrink-0">
            <Plus className="size-3.5" />
            Add Chronicle
          </Button>
        </div>

        {/* Filter bar */}
        <div className="flex flex-wrap items-center gap-2 pt-2">
          <div className="relative flex-1 min-w-[180px]">
            <Search className="absolute left-2.5 top-2.5 size-3.5 text-muted-foreground" />
            <Input
              placeholder="Search chronicles…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="h-8 pl-8 text-xs"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery("")}
                className="absolute right-2.5 top-2.5 text-muted-foreground hover:text-foreground"
              >
                <X className="size-3.5" />
              </button>
            )}
          </div>

          <div className="flex items-center gap-1 overflow-x-auto text-xs">
            <button
              onClick={() => setSelectedCategory("all")}
              className={`rounded-md px-2.5 py-1 transition-colors ${
                selectedCategory === "all"
                  ? "bg-primary text-primary-foreground font-medium"
                  : "bg-muted/60 text-muted-foreground hover:bg-muted"
              }`}
            >
              All ({chronicles.length})
            </button>
            {(Object.keys(CATEGORY_CONFIG) as ChronicleCategory[]).map((cat) => {
              const count = chronicles.filter((c) => c.category === cat).length;
              return (
                <button
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`rounded-md px-2.5 py-1 capitalize transition-colors ${
                    selectedCategory === cat
                      ? "bg-primary text-primary-foreground font-medium"
                      : "bg-muted/60 text-muted-foreground hover:bg-muted"
                  }`}
                >
                  {cat} ({count})
                </button>
              );
            })}
          </div>
        </div>
      </CardHeader>

      <CardContent>
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-8 text-center text-muted-foreground">
            <Calendar className="size-8 opacity-40 mb-2" />
            <p className="text-sm font-medium">No chronicles recorded</p>
            <p className="text-xs max-w-sm mt-1">
              {searchQuery || selectedCategory !== "all"
                ? "No entries match the current filter criteria."
                : "Record your first milestone or team decision using the 'Add Chronicle' button above."}
            </p>
          </div>
        ) : (
          <div className="space-y-3 relative before:absolute before:inset-0 before:left-3.5 before:w-0.5 before:bg-border before:z-0">
            {filtered.map((entry) => {
              const config = CATEGORY_CONFIG[entry.category] || CATEGORY_CONFIG.update;
              const Icon = config.icon;
              return (
                <div
                  key={entry.id}
                  className="relative z-10 pl-8 group"
                >
                  {/* Timeline dot */}
                  <div
                    className={`absolute left-1.5 top-2.5 size-4 rounded-full border-2 bg-background flex items-center justify-center ${config.text} ${config.border}`}
                  >
                    <div className="size-1.5 rounded-full bg-current" />
                  </div>

                  <div className="rounded-lg border bg-card p-3.5 transition-colors hover:border-primary/40 space-y-2">
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex items-center gap-2 flex-wrap">
                        <Badge
                          variant="outline"
                          className={`text-[11px] gap-1 py-0 px-2 font-medium ${config.bg} ${config.text} ${config.border}`}
                        >
                          <Icon className="size-3" />
                          {config.label}
                        </Badge>
                        {entry.pinned && (
                          <Badge variant="secondary" className="text-[10px] gap-1 py-0 px-1.5">
                            <Pin className="size-2.5" /> Pinned
                          </Badge>
                        )}
                        <h4 className="text-sm font-semibold text-foreground">
                          {entry.title}
                        </h4>
                      </div>

                      <div className="flex items-center gap-1 opacity-80 group-hover:opacity-100 shrink-0">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-7 text-muted-foreground hover:text-foreground"
                          onClick={() => handleOpenEdit(entry)}
                          title="Edit chronicle"
                        >
                          <Edit3 className="size-3.5" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-7 text-destructive hover:text-destructive hover:bg-destructive/10"
                          onClick={() => handleDelete(entry.id, entry.title)}
                          title="Delete chronicle"
                        >
                          <Trash2 className="size-3.5" />
                        </Button>
                      </div>
                    </div>

                    <p className="text-xs text-muted-foreground leading-relaxed whitespace-pre-line">
                      {entry.content}
                    </p>

                    <div className="flex items-center justify-between pt-1 border-t border-border/50 text-[11px] text-muted-foreground">
                      <div className="flex items-center gap-1.5">
                        <span className="font-medium text-foreground">{entry.authorName}</span>
                        <span>·</span>
                        <span className="italic">{entry.authorRole}</span>
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

      {/* Create / Edit Dialog */}
      <Dialog
        open={isCreateOpen || Boolean(editingEntry)}
        onOpenChange={(open) => {
          if (!open) {
            setIsCreateOpen(false);
            setEditingEntry(null);
          }
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>
              {editingEntry ? "Edit Chronicle Entry" : "New Department Chronicle"}
            </DialogTitle>
            <DialogDescription className="text-xs">
              Log an official milestone, decision, or update for this department.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div>
              <label className="text-xs font-medium">Title / Milestone</label>
              <Input
                placeholder="e.g., PCBA Thermal Simulation Pass"
                value={formTitle}
                onChange={(e) => setFormTitle(e.target.value)}
                className="mt-1 text-sm"
              />
            </div>

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

            <div>
              <label className="text-xs font-medium">Details & Remarks</label>
              <Textarea
                placeholder="Describe what was decided, verified, or updated…"
                value={formContent}
                onChange={(e) => setFormContent(e.target.value)}
                rows={4}
                className="mt-1 text-xs"
              />
            </div>

            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="pinChronicle"
                checked={formPinned}
                onChange={(e) => setFormPinned(e.target.checked)}
                className="rounded border-input text-primary"
              />
              <label htmlFor="pinChronicle" className="text-xs text-muted-foreground cursor-pointer">
                Pin to top of feed
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
              {editingEntry ? "Save Changes" : "Post Chronicle"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
