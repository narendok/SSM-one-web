import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Plus, Search, Factory, Wrench, Gauge, Building, Filter, CheckCircle2, AlertTriangle, ShieldAlert, Laptop, Eye, Tag, Link2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { savePhase8Record } from "@/lib/phase8.functions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "sonner";
import { PermissionGate } from "@/components/PermissionGate";

export type AssetClass = "PRODUCTION_MACHINERY" | "SERVICE_MAINTENANCE" | "IMTE_CALIBRATION" | "FACILITY_OFFICE" | "ALL";

interface AssetRecord {
  id: string;
  asset_code: string;
  name: string;
  category_id: string | null;
  status: string;
  manufacturer: string | null;
  model_number: string | null;
  serial_number: string | null;
  acquisition_date: string | null;
  acquisition_cost: number | null;
  facility_location_id: string | null;
  custodian_user_id: string | null;
  specifications: Record<string, any>;
  created_at: string;
  location?: { name: string; code: string } | null;
}

export function AssetRegisterWorkspace() {
  const qc = useQueryClient();
  const [activeTab, setActiveTab] = useState<AssetClass>("PRODUCTION_MACHINERY");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [createOpen, setCreateOpen] = useState(false);
  const [detailAsset, setDetailAsset] = useState<AssetRecord | null>(null);

  // Queries
  const { data: assets = [], isLoading } = useQuery({
    queryKey: ["assets_workspace"],
    queryFn: async () => {
      const { data, error } = await (supabase as any)
        .from("assets")
        .select("*, location:facility_locations(name, code)")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as AssetRecord[];
    },
  });

  const { data: locations = [] } = useQuery({
    queryKey: ["facility_locations_options"],
    queryFn: async () => {
      const { data, error } = await (supabase as any).from("facility_locations").select("id, name, code").eq("is_active", true);
      if (error) return [];
      return data as { id: string; name: string; code: string }[];
    },
  });

  const { data: components = [] } = useQuery({
    queryKey: ["components_for_asset_compat"],
    queryFn: async () => {
      const { data, error } = await (supabase as any).from("components").select("id, name, part_number").order("name").limit(300);
      if (error) return [];
      return data as { id: string; name: string; part_number: string }[];
    },
  });

  // Filtered Assets
  const filtered = useMemo(() => {
    return assets.filter((a) => {
      const specs = a.specifications || {};
      const aClass = specs.asset_class || (
        a.name.toLowerCase().includes("smt") || a.name.toLowerCase().includes("reflow") ||
        a.name.toLowerCase().includes("crimp") || a.name.toLowerCase().includes("stripp") ||
        a.name.toLowerCase().includes("soldering") || a.name.toLowerCase().includes("cnc") ||
        a.name.toLowerCase().includes("laser") || a.name.toLowerCase().includes("oven")
          ? "PRODUCTION_MACHINERY"
          : a.name.toLowerCase().includes("jig") || a.name.toLowerCase().includes("tester") ||
            a.name.toLowerCase().includes("multimeter") || a.name.toLowerCase().includes("camera")
          ? "SERVICE_MAINTENANCE"
          : a.name.toLowerCase().includes("calibrat") || a.name.toLowerCase().includes("torque") ||
            a.name.toLowerCase().includes("gauge")
          ? "IMTE_CALIBRATION"
          : "FACILITY_OFFICE"
      );

      if (activeTab !== "ALL" && aClass !== activeTab) return false;
      if (statusFilter !== "all" && a.status !== statusFilter) return false;
      if (search) {
        const q = search.toLowerCase();
        if (
          !a.name.toLowerCase().includes(q) &&
          !a.asset_code.toLowerCase().includes(q) &&
          !(a.manufacturer ?? "").toLowerCase().includes(q) &&
          !(a.model_number ?? "").toLowerCase().includes(q) &&
          !(a.serial_number ?? "").toLowerCase().includes(q)
        )
          return false;
      }
      return true;
    });
  }, [assets, activeTab, statusFilter, search]);

  const stats = useMemo(() => {
    const prod = assets.filter((a) => {
      const c = a.specifications?.asset_class;
      return c === "PRODUCTION_MACHINERY" || (!c && (a.name.toLowerCase().includes("smt") || a.name.toLowerCase().includes("oven") || a.name.toLowerCase().includes("crimp") || a.name.toLowerCase().includes("machine")));
    }).length;
    const srv = assets.filter((a) => {
      const c = a.specifications?.asset_class;
      return c === "SERVICE_MAINTENANCE" || (!c && (a.name.toLowerCase().includes("jig") || a.name.toLowerCase().includes("test") || a.name.toLowerCase().includes("service")));
    }).length;
    const imte = assets.filter((a) => a.specifications?.asset_class === "IMTE_CALIBRATION" || a.status === "CALIBRATION_DUE").length;
    return { total: assets.length, production: prod, service: srv, imte };
  }, [assets]);

  return (
    <div className="space-y-6 p-4 md:p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight flex items-center gap-2">
            <Factory className="h-6 w-6 text-primary" /> Asset &amp; Machinery Register
          </h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Governed serialized equipment, production machinery for production leads, and maintenance/test assets for service teams.
          </p>
        </div>
        <PermissionGate permission="assets.edit">
          <Button onClick={() => setCreateOpen(true)} className="gap-1.5">
            <Plus className="h-4 w-4" /> Register New Asset / Machine
          </Button>
        </PermissionGate>
      </div>

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as AssetClass)} className="space-y-4">
        <TabsList className="grid grid-cols-2 md:grid-cols-4 w-full md:w-auto h-auto p-1 bg-muted/60">
          <TabsTrigger value="PRODUCTION_MACHINERY" className="flex items-center gap-1.5 py-2">
            <Factory className="h-4 w-4 text-primary" />
            <span>Production Machinery</span>
            <Badge variant="secondary" className="ml-1 text-[10px] px-1.5">{stats.production}</Badge>
          </TabsTrigger>
          <TabsTrigger value="SERVICE_MAINTENANCE" className="flex items-center gap-1.5 py-2">
            <Wrench className="h-4 w-4 text-amber-600" />
            <span>Service &amp; Maintenance</span>
            <Badge variant="secondary" className="ml-1 text-[10px] px-1.5">{stats.service}</Badge>
          </TabsTrigger>
          <TabsTrigger value="IMTE_CALIBRATION" className="flex items-center gap-1.5 py-2">
            <Gauge className="h-4 w-4 text-blue-600" />
            <span>Calibration &amp; IMTE</span>
            <Badge variant="secondary" className="ml-1 text-[10px] px-1.5">{stats.imte}</Badge>
          </TabsTrigger>
          <TabsTrigger value="ALL" className="flex items-center gap-1.5 py-2">
            <Building className="h-4 w-4 text-purple-600" />
            <span>All Enterprise Assets</span>
            <Badge variant="secondary" className="ml-1 text-[10px] px-1.5">{stats.total}</Badge>
          </TabsTrigger>
        </TabsList>

        {/* Toolbar */}
        <Card className="p-3">
          <div className="flex flex-col sm:flex-row items-center gap-3">
            <div className="relative flex-1 w-full">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search machine, model, serial, asset ID…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-8"
              />
            </div>
            <div className="w-full sm:w-[220px]">
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger><SelectValue placeholder="Status filter" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All statuses</SelectItem>
                  <SelectItem value="ACTIVE">Active</SelectItem>
                  <SelectItem value="IN_SERVICE">In service</SelectItem>
                  <SelectItem value="UNDER_MAINTENANCE">Under maintenance</SelectItem>
                  <SelectItem value="CALIBRATION_DUE">Calibration due</SelectItem>
                  <SelectItem value="QUARANTINED">Quarantined</SelectItem>
                  <SelectItem value="RETIRED">Retired</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </Card>

        {/* Assets Table */}
        <Card className="overflow-hidden">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Asset Code</TableHead>
                <TableHead>Equipment / Machine</TableHead>
                <TableHead>Manufacturer / Model</TableHead>
                <TableHead>Serial Number</TableHead>
                <TableHead>Location</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Compatible Parts</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading && (
                <TableRow><TableCell colSpan={8} className="text-center py-8 text-muted-foreground">Loading asset records…</TableCell></TableRow>
              )}
              {!isLoading && filtered.length === 0 && (
                <TableRow><TableCell colSpan={8} className="text-center py-10 text-muted-foreground">
                  No assets found matching current criteria. Click <strong>Register New Asset</strong> to add one.
                </TableCell></TableRow>
              )}
              {filtered.map((a) => {
                const compatCount = (a.specifications?.compatible_component_ids || []).length;
                return (
                  <TableRow key={a.id}>
                    <TableCell className="font-mono text-xs font-semibold">{a.asset_code}</TableCell>
                    <TableCell>
                      <button onClick={() => setDetailAsset(a)} className="font-medium hover:text-primary text-left">
                        {a.name}
                      </button>
                      <div className="text-[10px] text-muted-foreground">
                        {a.specifications?.asset_class?.replace(/_/g, " ") || "General equipment"}
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="text-sm">{a.manufacturer ?? "—"}</div>
                      <div className="text-xs text-muted-foreground font-mono">{a.model_number ?? ""}</div>
                    </TableCell>
                    <TableCell className="font-mono text-xs">{a.serial_number ?? "—"}</TableCell>
                    <TableCell>{a.location?.name ?? a.location?.code ?? "Floor / Shop"}</TableCell>
                    <TableCell>
                      <StatusBadge status={a.status} />
                    </TableCell>
                    <TableCell>
                      {compatCount > 0 ? (
                        <Badge variant="outline" className="text-[10px] gap-1 text-primary border-primary/30">
                          <Link2 className="h-3 w-3" /> {compatCount} part{compatCount > 1 ? "s" : ""}
                        </Badge>
                      ) : (
                        <span className="text-xs text-muted-foreground">—</span>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" onClick={() => setDetailAsset(a)} className="gap-1">
                        <Eye className="h-3.5 w-3.5" /> Details
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </Card>
      </Tabs>

      {/* Create Modal */}
      <CreateAssetDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        locations={locations}
        components={components}
        onSaved={() => qc.invalidateQueries({ queryKey: ["assets_workspace"] })}
      />

      {/* Detail / Compatibility Modal */}
      {detailAsset && (
        <AssetDetailDialog
          asset={detailAsset}
          open={!!detailAsset}
          onOpenChange={(op) => !op && setDetailAsset(null)}
          components={components}
          onUpdated={() => {
            qc.invalidateQueries({ queryKey: ["assets_workspace"] });
            setDetailAsset(null);
          }}
        />
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  switch (status) {
    case "ACTIVE":
    case "IN_SERVICE":
      return <Badge className="bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-300">Active</Badge>;
    case "UNDER_MAINTENANCE":
      return <Badge className="bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950 dark:text-amber-300">Maintenance</Badge>;
    case "CALIBRATION_DUE":
      return <Badge className="bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300">Cal Due</Badge>;
    case "QUARANTINED":
      return <Badge variant="destructive">Quarantined</Badge>;
    case "RETIRED":
      return <Badge variant="secondary">Retired</Badge>;
    default:
      return <Badge variant="outline">{status.replace(/_/g, " ")}</Badge>;
  }
}

interface CreateAssetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  locations: { id: string; name: string; code: string }[];
  components: { id: string; name: string; part_number: string }[];
  onSaved: () => void;
}

function CreateAssetDialog({ open, onOpenChange, locations, components, onSaved }: CreateAssetProps) {
  const [name, setName] = useState("");
  const [assetClass, setAssetClass] = useState<AssetClass>("PRODUCTION_MACHINERY");
  const [manufacturer, setManufacturer] = useState("");
  const [modelNumber, setModelNumber] = useState("");
  const [serialNumber, setSerialNumber] = useState("");
  const [status, setStatus] = useState("ACTIVE");
  const [facilityLocationId, setFacilityLocationId] = useState("");
  const [notes, setNotes] = useState("");
  const [compatPartIds, setCompatPartIds] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    if (!name.trim()) return toast.error("Asset / Machine name is required");
    setSaving(true);
    try {
      const assetCode = `AST-${Date.now().toString().slice(-6)}`;
      const qrPayload = `SSM-AST-${crypto.randomUUID()}`;
      const payload = {
        asset_code: assetCode,
        name: name.trim(),
        manufacturer: manufacturer.trim() || null,
        model_number: modelNumber.trim() || null,
        serial_number: serialNumber.trim() || null,
        status,
        facility_location_id: facilityLocationId || null,
        qr_payload: qrPayload,
        specifications: {
          asset_class: assetClass,
          notes: notes.trim() || null,
          compatible_component_ids: compatPartIds,
        },
      };

      await savePhase8Record({ data: { table: "assets", payload } });
      toast.success(`Asset ${assetCode} registered successfully`);
      onOpenChange(false);
      onSaved();
    } catch (e: any) {
      toast.error(e.message || "Failed to register asset");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Register Enterprise Asset / Production Machinery</DialogTitle>
          <DialogDescription>
            Register serialized plant machinery, service equipment, or tooling with location and part compatibility.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4 py-2">
          <div className="grid sm:grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold">Equipment / Asset Name *</Label>
              <Input placeholder="e.g. SMT Reflow Oven 8-Zone" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold">Asset Classification *</Label>
              <Select value={assetClass} onValueChange={(v) => setAssetClass(v as AssetClass)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="PRODUCTION_MACHINERY">🏭 Production Machinery (SMT, Oven, Crimper)</SelectItem>
                  <SelectItem value="SERVICE_MAINTENANCE">🔧 Service &amp; Test Equipment (Jigs, Scopes)</SelectItem>
                  <SelectItem value="IMTE_CALIBRATION">📐 Calibration / IMTE Instruments</SelectItem>
                  <SelectItem value="FACILITY_OFFICE">🏢 Facility &amp; Plant Utilities</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid sm:grid-cols-3 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs">Manufacturer</Label>
              <Input placeholder="e.g. Yamaha / Heller" value={manufacturer} onChange={(e) => setManufacturer(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Model Number</Label>
              <Input placeholder="e.g. YS-12" value={modelNumber} onChange={(e) => setModelNumber(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Serial Number</Label>
              <Input placeholder="e.g. SN-98234-A" value={serialNumber} onChange={(e) => setSerialNumber(e.target.value)} />
            </div>
          </div>

          <div className="grid sm:grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs">Operating Status</Label>
              <Select value={status} onValueChange={setStatus}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="ACTIVE">Active</SelectItem>
                  <SelectItem value="IN_SERVICE">In Service</SelectItem>
                  <SelectItem value="UNDER_MAINTENANCE">Under Maintenance</SelectItem>
                  <SelectItem value="CALIBRATION_DUE">Calibration Due</SelectItem>
                  <SelectItem value="QUARANTINED">Quarantined</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Facility Location</Label>
              <Select value={facilityLocationId} onValueChange={setFacilityLocationId}>
                <SelectTrigger><SelectValue placeholder="Choose plant location" /></SelectTrigger>
                <SelectContent>
                  {locations.map((loc) => (
                    <SelectItem key={loc.id} value={loc.id}>{loc.code} — {loc.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-1.5">
            <Label className="text-xs">Compatible Components, Harnesses &amp; Consumables</Label>
            <Select onValueChange={(pId) => {
              if (!compatPartIds.includes(pId)) setCompatPartIds((prev) => [...prev, pId]);
            }}>
              <SelectTrigger><SelectValue placeholder="Select compatible components / harnesses" /></SelectTrigger>
              <SelectContent>
                {components.map((c) => (
                  <SelectItem key={c.id} value={c.id}>{c.part_number} — {c.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>

            {compatPartIds.length > 0 && (
              <div className="flex flex-wrap gap-1.5 mt-2">
                {compatPartIds.map((cId) => {
                  const part = components.find((c) => c.id === cId);
                  return (
                    <Badge key={cId} variant="secondary" className="gap-1 text-xs">
                      {part ? `${part.part_number} (${part.name})` : cId}
                      <button
                        type="button"
                        onClick={() => setCompatPartIds((prev) => prev.filter((id) => id !== cId))}
                        className="ml-1 hover:text-destructive"
                      >
                        ×
                      </button>
                    </Badge>
                  );
                })}
              </div>
            )}
          </div>

          <div className="space-y-1.5">
            <Label className="text-xs">Technical Remarks &amp; Tooling Notes</Label>
            <Textarea placeholder="Maintenance schedule, applicator size, nozzle requirements…" value={notes} onChange={(e) => setNotes(e.target.value)} />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button disabled={saving} onClick={handleSave}>{saving ? "Saving…" : "Save Record"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

interface AssetDetailProps {
  asset: AssetRecord;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  components: { id: string; name: string; part_number: string }[];
  onUpdated: () => void;
}

function AssetDetailDialog({ asset, open, onOpenChange, components, onUpdated }: AssetDetailProps) {
  const specs = asset.specifications || {};
  const compatIds: string[] = specs.compatible_component_ids || [];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center gap-2">
            <StatusBadge status={asset.status} />
            <span className="font-mono text-xs text-muted-foreground">{asset.asset_code}</span>
          </div>
          <DialogTitle className="text-xl mt-1">{asset.name}</DialogTitle>
          <DialogDescription>
            {specs.asset_class?.replace(/_/g, " ") || "Enterprise equipment"}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-2 text-sm">
          <div className="grid grid-cols-2 gap-3 p-3 rounded-lg bg-muted/40">
            <div>
              <span className="text-xs text-muted-foreground block">Manufacturer</span>
              <span className="font-medium">{asset.manufacturer || "—"}</span>
            </div>
            <div>
              <span className="text-xs text-muted-foreground block">Model Number</span>
              <span className="font-medium font-mono">{asset.model_number || "—"}</span>
            </div>
            <div>
              <span className="text-xs text-muted-foreground block">Serial Number</span>
              <span className="font-medium font-mono">{asset.serial_number || "—"}</span>
            </div>
            <div>
              <span className="text-xs text-muted-foreground block">Facility Location</span>
              <span className="font-medium">{asset.location?.name || "Floor / Plant"}</span>
            </div>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase text-muted-foreground tracking-wider mb-2">
              Compatible Components, Harnesses &amp; Tooling
            </h4>
            {compatIds.length === 0 ? (
              <p className="text-xs text-muted-foreground italic">No linked components or harnesses.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {compatIds.map((id) => {
                  const part = components.find((c) => c.id === id);
                  return (
                    <Badge key={id} variant="outline" className="text-xs py-1 px-2 border-primary/20">
                      <Link2 className="h-3 w-3 mr-1 text-primary" />
                      {part ? `${part.part_number} — ${part.name}` : id}
                    </Badge>
                  );
                })}
              </div>
            )}
          </div>

          {specs.notes && (
            <div>
              <h4 className="text-xs font-semibold uppercase text-muted-foreground tracking-wider mb-1">
                Technical Notes &amp; Maintenance
              </h4>
              <p className="text-xs text-muted-foreground bg-muted/20 p-2.5 rounded border">{specs.notes}</p>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Close</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
