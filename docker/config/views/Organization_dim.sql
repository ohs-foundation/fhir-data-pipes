CREATE OR REPLACE VIEW Organization_dim_view AS
-- Grain: 1 row = 1 Organization.
-- Schema mirrors Dim_Organization in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Int/Double/Timestamp) instead of casting everything
-- to TEXT.
-- TotalBeds / TargetOccupancyRate / TargetALOS are NOT available in FHIR Organization;
-- they must be supplied later from master data / business rules (kept as NULL here).
WITH picked AS (
  SELECT O.*,
    COALESCE(
      try_element_at(filter(O.identifier, i -> try_element_at(i.type.coding, 1).code = 'MRN'), 1),
      try_element_at(O.identifier, 1)
    ) AS oid,
    try_element_at(O.type, 1) AS otype
  FROM Organization AS O
)
SELECT
  id AS OrganizationID,
  oid.value AS IdentifierValue,
  active AS ActiveFlag,
  name AS OrganizationName,
  COALESCE(try_element_at(otype.coding, 1).display, otype.text) AS OrganizationTypeDisplay,
  partOf.organizationId AS ParentOrganizationID,
  CAST(NULL AS INT) AS TotalBeds,
  CAST(NULL AS DOUBLE) AS TargetOccupancyRate,
  CAST(NULL AS DOUBLE) AS TargetALOS,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
