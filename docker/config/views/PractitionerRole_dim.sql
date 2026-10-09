CREATE OR REPLACE VIEW PractitionerRole_dim_view AS
-- Grain: 1 row = 1 PractitionerRole. code / specialty reduced to their first element.
-- Schema mirrors Dim_PractitionerRole in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Timestamp) instead of casting everything to TEXT.
WITH picked AS (
  SELECT PR.*,
    try_element_at(PR.code, 1) AS pcode,
    try_element_at(PR.specialty, 1) AS pspec
  FROM PractitionerRole AS PR
)
SELECT
  id AS PractitionerRoleID,
  practitioner.practitionerId AS PractitionerID,
  organization.organizationId AS OrganizationID,
  try_element_at(pcode.coding, 1).code AS RoleCode,
  COALESCE(try_element_at(pcode.coding, 1).display, pcode.text) AS RoleDisplay,
  COALESCE(try_element_at(pspec.coding, 1).display, pspec.text) AS SpecialtyDisplay,
  active AS ActiveFlag,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
