import { useEffect, useState } from "react";
import { AlertCircle, Loader2, Search } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export type LocalBomComponentCandidate = {
  id: string;
  name: string;
  partNumber: string;
  manufacturer: string | null;
};

type Props = {
  rowLabel: string;
  selectedComponentId: string | null;
  onSelect: (candidate: LocalBomComponentCandidate) => void;
};

export function LocalBomComponentPicker({ rowLabel, selectedComponentId, onSelect }: Props) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<LocalBomComponentCandidate[]>([]);
  const [status, setStatus] = useState<"idle" | "loading" | "error" | "empty">("idle");

  useEffect(() => {
    const term = query.trim();
    if (term.length < 2) {
      setResults([]);
      setStatus("idle");
      return;
    }

    let cancelled = false;
    setStatus("loading");
    const timeout = window.setTimeout(async () => {
      const { data, error } = await supabase
        .from("components")
        .select("id,name,part_number,manufacturer")
        .or(`name.ilike.%${term}%,part_number.ilike.%${term}%`)
        .limit(10);

      if (cancelled) return;
      if (error) {
        setResults([]);
        setStatus("error");
        return;
      }

      const next = (data ?? []).map((component) => ({
        id: component.id,
        name: component.name,
        partNumber: component.part_number,
        manufacturer: component.manufacturer,
      }));
      setResults(next);
      setStatus(next.length ? "idle" : "empty");
    }, 250);

    return () => {
      cancelled = true;
      window.clearTimeout(timeout);
    };
  }, [query]);

  const select = (candidate: LocalBomComponentCandidate) => {
    onSelect(candidate);
    setQuery("");
    setResults([]);
    setStatus("idle");
  };

  return <div className="min-w-[220px] space-y-1.5">
    <label className="sr-only" htmlFor={`local-component-search-${rowLabel}`}>Search caller-visible components for {rowLabel}</label>
    <div className="relative">
      <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
      <Input id={`local-component-search-${rowLabel}`} aria-label={`Search caller-visible components for ${rowLabel}`} className="pl-8" placeholder="Search component" value={query} onChange={(event) => setQuery(event.target.value)} />
      {status === "loading" && <Loader2 aria-label="Searching components" className="absolute right-2.5 top-2.5 size-4 animate-spin text-muted-foreground" />}
    </div>
    <p className="text-xs text-muted-foreground">{selectedComponentId ? "A local component identity is selected; existing row text remains unchanged." : "Search by name or part number; caller-visible results only."}</p>
    {status === "error" && <p role="alert" className="flex items-center gap-1 text-xs text-destructive"><AlertCircle className="size-3.5" /> Component search is unavailable. Your local row is unchanged.</p>}
    {status === "empty" && <p role="status" className="text-xs text-muted-foreground">No caller-visible components match this search. Your local row is unchanged.</p>}
    {results.length > 0 && <div role="listbox" aria-label={`Component results for ${rowLabel}`} className="max-h-44 overflow-y-auto border bg-popover p-1 shadow-sm">{results.map((candidate) => <Button key={candidate.id} type="button" variant="ghost" size="sm" role="option" className="h-auto w-full justify-start whitespace-normal px-2 py-2 text-left" onClick={() => select(candidate)}><span><span className="block font-medium">{candidate.name}</span><span className="block font-mono text-xs text-muted-foreground">{candidate.partNumber}{candidate.manufacturer ? ` · ${candidate.manufacturer}` : ""}</span></span></Button>)}</div>}
  </div>;
}
