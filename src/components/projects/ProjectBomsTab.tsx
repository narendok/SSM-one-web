import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link, useNavigate } from "@tanstack/react-router";
import { useServerFn } from "@tanstack/react-start";
import { FileSpreadsheet, FolderInput, ChevronRight, ArrowLeft, Upload, FolderOpen, CircuitBoard, Building2 } from "lucide-react";
import { fetchProjectBoms, fetchProjectBomItems, type ProjectBomSummary, type ProjectBomItemRow } from "@/lib/project-bom.functions";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

const KIND_STYLE: Record<string, string> = {
  exact: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30",
  close: "bg-blue-500/15 text-blue-700 dark:text-blue-400 border-blue-500/30",
  substitute: "bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30",
  missing: "bg-destructive/15 text-destructive border-destructive/30",
};

function money(n: number | null | undefined) {
  if (n == null) return "—";
  return n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// Master tentative BOMs for Automotive Telematics Journeys
const SAMPLE_TELEMATICS_BOMS: { header: ProjectBomSummary; items: ProjectBomItemRow[] }[] = [
  {
    header: {
      id: "bom-sample-electronic",
      project_id: "prj-tlm-002",
      bom_number: "BOM-TLM-2026-E01",
      name: "Electronic Architecture BOM (BLE 5.2 + Quectel LTE Cat 1 + 3.7V Secondary Battery)",
      revision: "2.1-BLE",
      status: "active",
      total_cost: 42.85,
      line_count: 8,
      source_filename: "PCB_TLM_V2.1_BLE_Schematic_BOM.xlsx",
      source_drive_node_id: "node-bom-elec",
      created_at: "2026-03-01T10:00:00.000Z",
      updated_at: "2026-03-10T14:00:00.000Z",
    },
    items: [
      {
        id: "item-e-1",
        bom_id: "bom-sample-electronic",
        line_number: 1,
        refs: "U1",
        mpn: "NRF52833-QIAA-R7",
        description: "Bluetooth 5.2 Low Energy SoC, ARM Cortex-M4 with FPU, 512KB Flash, 128KB RAM",
        value: "nRF52833",
        footprint: "aQFN-73",
        quantity: 1,
        unit_cost: 3.45,
        total_cost: 3.45,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "NRF52833-QIAA",
        matched_name: "Nordic Semiconductor Transceiver",
      },
      {
        id: "item-e-2",
        bom_id: "bom-sample-electronic",
        line_number: 2,
        refs: "MOD1",
        mpn: "EG915NEUAA-N05-SNNSA",
        description: "LTE Cat 1 Cellular IoT Module with fallback, eSIM & GNSS interface",
        value: "EG915N-EU",
        footprint: "LGA-126",
        quantity: 1,
        unit_cost: 11.2,
        total_cost: 11.2,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "QUECTEL-EG915N",
        matched_name: "Quectel 4G Cat 1 Wireless Module",
      },
      {
        id: "item-e-3",
        bom_id: "bom-sample-electronic",
        line_number: 3,
        refs: "U2",
        mpn: "STM32F401CEU6",
        description: "ARM Cortex-M4 Microcontroller 84MHz, 512KB Flash, CAN & USB interface",
        value: "STM32F401",
        footprint: "UFQFPN-48",
        quantity: 1,
        unit_cost: 2.85,
        total_cost: 2.85,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "STM32F401CEU6",
        matched_name: "STMicroelectronics MCU",
      },
      {
        id: "item-e-4",
        bom_id: "bom-sample-electronic",
        line_number: 4,
        refs: "U3",
        mpn: "BQ24075RGTR",
        description: "1.5A USB/DC Li-ion Battery Charger with Power-Path Management & Thermal Regulation",
        value: "BQ24075",
        footprint: "VQFN-16",
        quantity: 1,
        unit_cost: 1.65,
        total_cost: 1.65,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "TI-BQ24075",
        matched_name: "Texas Instruments Battery Charger",
      },
      {
        id: "item-e-5",
        bom_id: "bom-sample-electronic",
        line_number: 5,
        refs: "U4",
        mpn: "TPS62840DLYR",
        description: "750mA High-Efficiency Ultra-Low Iq (60nA) Step-Down Buck Converter",
        value: "TPS62840",
        footprint: "WSON-6",
        quantity: 1,
        unit_cost: 0.95,
        total_cost: 0.95,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "TI-TPS62840",
        matched_name: "Texas Instruments Buck Converter",
      },
      {
        id: "item-e-6",
        bom_id: "bom-sample-electronic",
        line_number: 6,
        refs: "BAT1",
        mpn: "LIC-103450-1200",
        description: "Secondary Rechargeable 3.7V 1200mAh Lithium-Ion Pouch Cell with NTC thermistor & internal PCM",
        value: "3.7V 1200mAh",
        footprint: "10x34x50mm",
        quantity: 1,
        unit_cost: 4.8,
        total_cost: 4.8,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "EEMB-LIC103450",
        matched_name: "NABL/UN38.3 Qualified Battery Cell",
      },
      {
        id: "item-e-7",
        bom_id: "bom-sample-electronic",
        line_number: 7,
        refs: "ANT1",
        mpn: "2065600100",
        description: "Cellular 4G LTE High-Efficiency Flexible Adhesive Antenna with 100mm micro-coax",
        value: "4G Flex Antenna",
        footprint: "40x15mm",
        quantity: 1,
        unit_cost: 1.45,
        total_cost: 1.45,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "MOLEX-2065600100",
        matched_name: "Molex Automotive Antenna",
      },
      {
        id: "item-e-8",
        bom_id: "bom-sample-electronic",
        line_number: 8,
        refs: "ANT2",
        mpn: "2450AT18D0100",
        description: "2.4GHz High Gain Ceramic Chip Antenna for BLE 5.2 Long-Range Transmission",
        value: "2.4GHz Chip",
        footprint: "3216 (1206)",
        quantity: 1,
        unit_cost: 0.42,
        total_cost: 0.42,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "JOHANSON-2450AT",
        matched_name: "Johanson Ceramic Antenna",
      },
    ],
  },
  {
    header: {
      id: "bom-sample-mechanical",
      project_id: "prj-tlm-002",
      bom_number: "BOM-TLM-2026-M01",
      name: "Mechanical Housing & Tooling BOM (IP67 Polycarbonate Enclosure + Gasket + Vent)",
      revision: "1.2",
      status: "active",
      total_cost: 8.95,
      line_count: 6,
      source_filename: "CAD_TLM_IP67_Housing_BOM_R1.2.xlsx",
      source_drive_node_id: "node-bom-mech",
      created_at: "2026-03-02T11:00:00.000Z",
      updated_at: "2026-03-12T16:00:00.000Z",
    },
    items: [
      {
        id: "item-m-1",
        bom_id: "bom-sample-mechanical",
        line_number: 1,
        refs: "ENC-TOP",
        mpn: "MEC-ENC-TLM-TOP",
        description: "Injection Molded Top Shell, Sabic Cycoloy PC/ABS Blend, Flame Retardant UL94-V0, UV Stabilized",
        value: "Top Housing",
        footprint: "115x75x22mm",
        quantity: 1,
        unit_cost: 2.75,
        total_cost: 2.75,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "SABIC-CYCOLOY-V0",
        matched_name: "Sabic Automotive Polymer",
      },
      {
        id: "item-m-2",
        bom_id: "bom-sample-mechanical",
        line_number: 2,
        refs: "ENC-BOT",
        mpn: "MEC-ENC-TLM-BOT",
        description: "Bottom Enclosure Base with internal 3.7V battery retention ribs, mounting ears, and gasket groove",
        value: "Bottom Base",
        footprint: "115x75x18mm",
        quantity: 1,
        unit_cost: 2.65,
        total_cost: 2.65,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "SABIC-CYCOLOY-BASE",
        matched_name: "Injection Molded Base",
      },
      {
        id: "item-m-3",
        bom_id: "bom-sample-mechanical",
        line_number: 3,
        refs: "GSK-01",
        mpn: "GSK-SIL-IP67-01",
        description: "Continuous Perimeter Compression Gasket, Custom Molded Silicone Elastomer, Shore A 45",
        value: "Perimeter Seal",
        footprint: "O-Ring Profile 2.2mm",
        quantity: 1,
        unit_cost: 0.95,
        total_cost: 0.95,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "SILICONE-45A-GSK",
        matched_name: "Automotive Grade Silicone Seal",
      },
      {
        id: "item-m-4",
        bom_id: "bom-sample-mechanical",
        line_number: 4,
        refs: "VNT-01",
        mpn: "PMF-10026",
        description: "W.L. Gore Snap-in Pressure Equalization Breather Vent, IP67/IP68 Hydrophobic & Oleophobic",
        value: "Gore-Tex Vent",
        footprint: "Dia 12mm Hole",
        quantity: 1,
        unit_cost: 1.15,
        total_cost: 1.15,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "GORE-PMF10026",
        matched_name: "Gore Protective Vent",
      },
      {
        id: "item-m-5",
        bom_id: "bom-sample-mechanical",
        line_number: 5,
        refs: "SCR-01..04",
        mpn: "M3-TORX-T10-12",
        description: "Stainless Steel 304 M3 x 12mm Torx T10 Self-Tapping Fasteners with captive washer",
        value: "M3x12 Torx",
        footprint: "M3 Thread",
        quantity: 4,
        unit_cost: 0.12,
        total_cost: 0.48,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "SS304-M3-T10",
        matched_name: "Stainless Fasteners",
      },
      {
        id: "item-m-6",
        bom_id: "bom-sample-mechanical",
        line_number: 6,
        refs: "PAD-01",
        mpn: "TP-SARCON-20G",
        description: "Fujipoly Sarcon 20G Highly Conformable Thermal Interface Pad 2.0 W/m-K for BQ24075/MCU",
        value: "Thermal Pad 15x15mm",
        footprint: "15x15x1.5mm",
        quantity: 1,
        unit_cost: 0.97,
        total_cost: 0.97,
        shortage: 0,
        match_status: "exact",
        matched_part_number: "FUJIPOLY-SARCON",
        matched_name: "Thermal Interface Material",
      },
    ],
  },
];

export function ProjectBomsTab({ projectId }: { projectId: string }) {
  const navigate = useNavigate();
  const listFn = useServerFn(fetchProjectBoms);
  const itemsFn = useServerFn(fetchProjectBomItems);
  const [openBomId, setOpenBomId] = useState<string | null>(null);

  const { data: dbBoms = [], isLoading } = useQuery({
    queryKey: ["project_boms", projectId],
    queryFn: async () => {
      try {
        const res = await listFn({ data: { projectId } });
        return res ?? [];
      } catch {
        return [];
      }
    },
  });

  const sampleMatch = SAMPLE_TELEMATICS_BOMS.find((b) => b.header.id === openBomId);

  const { data: dbDetail } = useQuery({
    queryKey: ["project_bom_detail", openBomId],
    queryFn: async () => {
      if (sampleMatch) return null;
      try {
        return await itemsFn({ data: { bomId: openBomId! } });
      } catch {
        return null;
      }
    },
    enabled: !!openBomId && !sampleMatch,
  });

  const activeDetail = sampleMatch ?? dbDetail;

  if (openBomId && activeDetail) {
    const h = activeDetail.header as any;
    const items = activeDetail.items as ProjectBomItemRow[];
    return (
      <div className="space-y-4">
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" onClick={() => setOpenBomId(null)}>
            <ArrowLeft className="h-4 w-4" /> Back to BOM list
          </Button>
        </div>
        <Card className="p-4 space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            <FileSpreadsheet className="h-5 w-5 text-muted-foreground" />
            <span className="text-lg font-semibold">{h.name}</span>
            <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{h.bom_number}</span>
            {h.revision && <Badge variant="secondary">Rev {h.revision}</Badge>}
          </div>
          <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
            <span>{items.length} line items</span>
            <span>
              Total cost: <span className="font-medium text-foreground">${money(h.total_cost)}</span>
            </span>
            {h.source_filename && (
              <span>
                Source: <span className="font-mono text-xs">{h.source_filename}</span>
              </span>
            )}
          </div>
          <div className="flex flex-wrap gap-2 pt-1">
            <Button size="sm" onClick={() => navigate({ to: "/bom", search: { loadBom: h.id } as any })}>
              <FolderInput className="h-4 w-4" /> Load in BOM tool
            </Button>
            {h.source_drive_node_id && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => navigate({ to: "/drive", search: { node: h.source_drive_node_id } as any })}
              >
                <FolderOpen className="h-4 w-4" /> Open source file
              </Button>
            )}
          </div>
        </Card>
        <Card className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Refs</TableHead>
                <TableHead>MPN</TableHead>
                <TableHead>Value / description</TableHead>
                <TableHead>Footprint</TableHead>
                <TableHead className="text-right">Qty</TableHead>
                <TableHead className="text-right">Unit cost</TableHead>
                <TableHead className="text-right">Total</TableHead>
                <TableHead>Matched part</TableHead>
                <TableHead className="text-right">Short</TableHead>
                <TableHead>Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {items.map((it) => (
                <TableRow key={it.id}>
                  <TableCell className="text-xs text-muted-foreground max-w-[140px] truncate">{it.refs || "—"}</TableCell>
                  <TableCell className="font-mono text-xs">{it.mpn || "—"}</TableCell>
                  <TableCell>
                    <div className="text-xs font-medium">{it.value || "—"}</div>
                    <div className="text-xs text-muted-foreground">{it.description}</div>
                  </TableCell>
                  <TableCell className="text-xs">{it.footprint || "—"}</TableCell>
                  <TableCell className="text-right">{it.quantity}</TableCell>
                  <TableCell className="text-right text-xs">${money(it.unit_cost)}</TableCell>
                  <TableCell className="text-right text-xs">${money(it.total_cost)}</TableCell>
                  <TableCell>
                    {it.matched_part_number ? (
                      <>
                        <div className="text-xs font-medium">{it.matched_name}</div>
                        <div className="font-mono text-xs text-muted-foreground">{it.matched_part_number}</div>
                      </>
                    ) : (
                      <span className="text-xs text-muted-foreground">—</span>
                    )}
                  </TableCell>
                  <TableCell className="text-right">
                    {it.shortage > 0 ? <span className="text-destructive font-semibold">{it.shortage}</span> : "—"}
                  </TableCell>
                  <TableCell>
                    <Badge className={KIND_STYLE[it.match_status ?? ""] ?? "variant=secondary"} variant="outline">
                      {it.match_status ?? "—"}
                    </Badge>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      </div>
    );
  }

  const effectiveBoms: ProjectBomSummary[] =
    dbBoms.length > 0 ? (dbBoms as ProjectBomSummary[]) : SAMPLE_TELEMATICS_BOMS.map((b) => b.header);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-base font-semibold">Controlled Project Bills of Materials</h3>
          <p className="text-xs text-muted-foreground">
            BOMs with automated AVL component matching, unit costing, and shortage tracking.
          </p>
        </div>
        <Button size="sm" onClick={() => navigate({ to: "/bom", search: { projectId } as any })}>
          <Upload className="h-4 w-4" /> Upload BOM
        </Button>
      </div>

      {isLoading ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : (
        <Card className="divide-y">
          {effectiveBoms.map((b) => (
            <button
              key={b.id}
              onClick={() => setOpenBomId(b.id)}
              className="w-full text-left p-4 hover:bg-accent/50 flex items-center gap-4 transition-colors"
            >
              <FileSpreadsheet className="h-5 w-5 text-muted-foreground shrink-0" />
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-medium text-foreground">{b.name}</span>
                  <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{b.bom_number}</span>
                  {b.revision && <Badge variant="secondary">Rev {b.revision}</Badge>}
                  {b.id.startsWith("bom-sample") && (
                    <Badge variant="outline" className="border-primary/40 text-primary text-[10px]">
                      Master Spec
                    </Badge>
                  )}
                </div>
                <div className="text-xs text-muted-foreground mt-0.5">
                  {b.line_count} line items · ${money(b.total_cost)} total
                  {b.source_filename ? ` · ${b.source_filename}` : ""}
                  {b.source_drive_node_id ? " · linked to Drive" : ""}
                </div>
              </div>
              <span
                role="button"
                tabIndex={0}
                className="text-xs text-primary hover:underline inline-flex items-center gap-1 shrink-0"
                onClick={(e) => {
                  e.stopPropagation();
                  navigate({ to: "/bom", search: { loadBom: b.id } as any });
                }}
              >
                <FolderInput className="h-3.5 w-3.5" /> Load in BOM tool
              </span>
              <ChevronRight className="h-4 w-4 text-muted-foreground shrink-0" />
            </button>
          ))}
        </Card>
      )}
    </div>
  );
}
