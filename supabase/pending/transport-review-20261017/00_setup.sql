BEGIN;
CREATE SCHEMA _ssm_feasibility_install_20261017 AUTHORIZATION CURRENT_USER;
REVOKE ALL ON SCHEMA _ssm_feasibility_install_20261017 FROM PUBLIC, anon, authenticated, service_role;
CREATE TABLE _ssm_feasibility_install_20261017.chunks (ordinal integer PRIMARY KEY CHECK (ordinal > 0), payload bytea NOT NULL);
REVOKE ALL ON TABLE _ssm_feasibility_install_20261017.chunks FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE _ssm_feasibility_install_20261017.chunks ENABLE ROW LEVEL SECURITY;
COMMIT;
