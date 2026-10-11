-- LOCAL DISPOSABLE concurrency worker only.
\set ON_ERROR_STOP on
SELECT public.provision_project_drive_template('00000000-0000-4000-8000-000000000102'::uuid);