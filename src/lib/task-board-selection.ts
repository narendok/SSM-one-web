export function shouldUpdateGlobalTaskRoute(projectId: string | undefined, hasSelectionCallback: boolean) {
  return !projectId && !hasSelectionCallback;
}