import { useState, type ReactNode } from "react";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";

export function StructuredPreviewExitBoundary({ dirty, children }: { dirty: boolean; children: (requestExit: (exit: () => void) => void) => ReactNode }) {
  const [pendingExit, setPendingExit] = useState<(() => void) | null>(null);
  const requestExit = (exit: () => void) => {
    if (dirty) {
      setPendingExit(() => exit);
      return;
    }
    exit();
  };

  return <>{children(requestExit)}<AlertDialog open={Boolean(pendingExit)} onOpenChange={(open) => { if (!open) setPendingExit(null); }}><AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Discard unsaved local edits?</AlertDialogTitle><AlertDialogDescription>These preview-only changes are not saved and cannot be recovered after leaving.</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Keep editing</AlertDialogCancel><AlertDialogAction onClick={() => { const exit = pendingExit; setPendingExit(null); exit?.(); }}>Discard edits</AlertDialogAction></AlertDialogFooter></AlertDialogContent></AlertDialog></>;
}