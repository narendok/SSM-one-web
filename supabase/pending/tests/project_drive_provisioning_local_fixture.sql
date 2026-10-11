-- LOCAL DISPOSABLE FIXTURE ONLY. Minimal schema/helpers for exercising the
-- pending project-Drive provisioner; no managed roles, RLS, or data are used.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE public.departments (
  id uuid PRIMARY KEY,
  code text NOT NULL,
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE public.projects (
  id uuid PRIMARY KEY,
  code text NOT NULL,
  name text NOT NULL,
  department_id uuid,
  drive_project_class text NOT NULL DEFAULT 'INTERNAL' CHECK (drive_project_class IN ('INTERNAL', 'CLIENT')),
  project_drive_node_id uuid
);

CREATE TABLE public.drive_nodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid,
  department_id uuid,
  parent_id uuid,
  name text NOT NULL,
  slug text NOT NULL,
  node_type text NOT NULL CHECK (node_type = 'FOLDER'),
  is_locked boolean NOT NULL DEFAULT false,
  folder_kind text NOT NULL CHECK (folder_kind IN ('DEPARTMENT_ROOT', 'DEPARTMENT_STANDARDS', 'INTERNAL_PROJECTS', 'CLIENT_PROJECTS', 'PROJECT_ROOT', 'STANDARD')),
  is_trashed boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE public.projects
  ADD CONSTRAINT projects_drive_root_fixture_fk
  FOREIGN KEY (project_drive_node_id) REFERENCES public.drive_nodes(id);

CREATE OR REPLACE FUNCTION public.provision_department_drive_template(p_department_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_root uuid;
BEGIN
  SELECT id INTO v_root FROM public.drive_nodes
  WHERE department_id = p_department_id AND folder_kind = 'DEPARTMENT_ROOT'
    AND parent_id IS NULL AND is_trashed = false
  ORDER BY created_at LIMIT 1;
  IF v_root IS NULL THEN
    INSERT INTO public.drive_nodes(department_id, parent_id, name, slug, node_type, is_locked, folder_kind)
    SELECT id, NULL, name, 'department-' || lower(code), 'FOLDER', true, 'DEPARTMENT_ROOT'
    FROM public.departments WHERE id = p_department_id AND is_active
    RETURNING id INTO v_root;
  END IF;
  INSERT INTO public.drive_nodes(department_id, parent_id, name, slug, node_type, is_locked, folder_kind)
  SELECT p_department_id, v_root, v.name, v.slug, 'FOLDER', true, v.folder_kind
  FROM (VALUES
    ('01 Internal Projects', '01-internal-projects', 'INTERNAL_PROJECTS'),
    ('02 Client Projects', '02-client-projects', 'CLIENT_PROJECTS')
  ) AS v(name, slug, folder_kind)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.drive_nodes n
    WHERE n.department_id = p_department_id AND n.parent_id = v_root
      AND n.folder_kind = v.folder_kind AND n.is_trashed = false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.provision_drive_category_template(
  p_parent_id uuid, p_department_id uuid, p_placement text, p_project_id uuid DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('fixture.fail_category', true) = 'on' THEN
    RAISE EXCEPTION 'Injected category failure';
  END IF;
END;
$$;

INSERT INTO public.departments(id, code, name) VALUES
  ('00000000-0000-4000-8000-000000000010', 'ENG', 'Engineering');

INSERT INTO public.projects(id, code, name, department_id, drive_project_class) VALUES
  ('00000000-0000-4000-8000-000000000101', 'PRJ-101', 'Repeat project', '00000000-0000-4000-8000-000000000010', 'INTERNAL'),
  ('00000000-0000-4000-8000-000000000102', 'PRJ-102', 'Contended project', '00000000-0000-4000-8000-000000000010', 'INTERNAL'),
  ('00000000-0000-4000-8000-000000000103', 'PRJ-103', 'Pointer conflict project', '00000000-0000-4000-8000-000000000010', 'INTERNAL'),
  ('00000000-0000-4000-8000-000000000104', 'PRJ-104', 'Rollback project', '00000000-0000-4000-8000-000000000010', 'CLIENT');