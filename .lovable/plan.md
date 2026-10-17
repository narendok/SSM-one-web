# Role-aware Sidebar Menu Plan

## Goal
Create one clear sidebar that adapts to the signed-in person: a full-control administration view and focused department views. Everyone gets Favorites first, then only the grouped work areas they are allowed to open.

## Shared sidebar behavior
- Keep a compact icon-only state and an always-visible control to expand it again.
- Show Favorites at the top. Users can pin their most-used permitted pages; sensible role defaults appear before they personalize the list.
- Group the remaining links into expandable work areas. Keep the group containing the current page open and highlight the current page.
- On small screens, open navigation as an accessible overlay; retain the active page context and a clear close control.
- Hide links without access. A visible link is navigation convenience only; every page and action continues to enforce its existing authorization independently.
- Preserve the existing authenticated routes and avoid exposing unfinished or source-only workflows as operational menu items.

## Administrator sidebar

### Favorites
Default pins: Overview, Projects, Work queue, Inventory, Procurement, Quality, Documents, and People. Administrators can rearrange or remove these without losing access to the grouped menu.

### Work groups
1. **Overview**
   - Dashboard / work queue
   - Notifications and approvals that the current administrator is authorized to handle
2. **Commercial & Projects**
   - Customers, opportunities, projects, project analysis, project tasks, and customer service
3. **Engineering & Delivery**
   - Requirements, specifications, BOM, hardware, firmware, software, mechanical, engineering changes, and production planning where already available
4. **Inventory & Procurement**
   - Parts, stock, lots, material movements, purchase orders, suppliers, receiving / GRN, incoming quality, and assets
   - Keep quality-held stock separate from available stock in labels and summaries; the sidebar does not imply release or issue authority.
5. **Quality & Compliance**
   - Quality workspace, inspections, non-conformances, warranty, calibrations, and controlled records where available
6. **Documents & Collaboration**
   - Drive, document registers, templates, shared collaboration, and approved external-contact administration
7. **People & Organization**
   - Employees, departments, hiring, roles, memberships, and assignments
8. **Administration**
   - Organization settings, permission administration, integrations, controlled reference data, and audit/history views that already have protected routes

## Department sidebar

### Department-focused Favorites
Default pins will depend on the person’s active department and assigned work, for example: My work, department queue, active projects, and the department’s primary workspace. People who belong to more than one department can switch their active department context; the sidebar refreshes without revealing other departments’ restricted work.

### Shared department groups
1. **My work**
   - My tasks, assigned reviews, notifications, and permitted project work
2. **Projects**
   - Only the projects and project documents the person is authorized to view
3. **Department workspace**
   - The active department’s queue, work items, templates, controlled documents, and team members as permitted
4. **Reference**
   - Read-only parts, approved specifications, approved documents, and other shared records needed to do the job

### Department-specific primary workspaces
- **Sales:** customers, opportunities, quotations, handover status, and customer service.
- **Hardware / Firmware / Software / Mechanical:** requirements, assigned project work, specifications, BOM visibility, change inputs, and department documents.
- **Procurement / Stores:** parts, approved purchase work, supplier records, receiving, stock movements, and material issue/return duties that are explicitly granted.
- **Quality:** inspections, incoming quality, quality holds/releases, non-conformances, and calibration/quality records.
- **Production / Operations:** authorized project delivery work, production planning, controlled material requests, and process records.
- **Finance / HR / Legal / Management:** only their existing authorized records and department tools; Legal documents remain separate from Sales navigation.

## Implementation stages
1. **Navigation inventory and access matrix**
   - Map every existing authenticated route to a work group, audience, icon, display name, and authorization source.
   - Mark routes that must remain absent because their underlying contract is pending, source-only, or restricted.
2. **Reusable navigation model**
   - Introduce a typed menu catalogue with group, route, role/department eligibility, favorite eligibility, and feature status.
   - Resolve the current user’s administrator authority, active department membership, and authorized route set on the server-backed authenticated path.
3. **Sidebar experience**
   - Build the responsive collapsible sidebar, active-link state, open-group behavior, and accessible mobile navigation.
   - Add an active-department switcher only for verified multi-department memberships.
4. **Favorites**
   - Add per-user favorites with safe defaults, ordering, add/remove controls, and fallback behavior when access changes.
   - Persist preferences only after confirming the existing department workspace-preference contract can safely support it; otherwise deliver the default-only sidebar first.
5. **Role validation and rollout**
   - Exercise representative administrator and department accounts, including a multi-department person, restricted department user, and unauthorised deep link.
   - Verify that menu visibility changes correctly but direct route/server authorization remains the source of truth.

## Technical details
- Use the existing TanStack route links and authenticated layout; do not introduce a second router.
- Keep navigation configuration separate from authorization decisions. The menu consumes verified permissions and department context rather than encoding broad client-side privileges.
- Use the established sidebar component pattern, with explicit CSS variable syntax for width calculations so the content never sits behind the collapsed or expanded sidebar.
- Add focused tests for concrete menu eligibility rules, default favorites, active-route group expansion, and access removal behavior.

## Boundaries
- This is a navigation and visibility improvement, not a permissions rewrite. No existing backend authorization, document responsibility, inventory release, quality-hold, or feasibility approval rule is weakened.
- No new operational links are added for pending feasibility, external-client copy, private document materialization, or other workflows that lack an accepted backend contract.
