import type { DriveNode, DriveRevision } from "@/lib/drive";

export function canDownloadNode(node: Pick<DriveNode, "storage_path">): node is Pick<DriveNode, "storage_path"> & { storage_path: string } {
  return Boolean(node.storage_path);
}

export function isSelectedNodeRevision(
  node: Pick<DriveNode, "id">,
  revision: Pick<DriveRevision, "node_id">,
) {
  return revision.node_id === node.id;
}