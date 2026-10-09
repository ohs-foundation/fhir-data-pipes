CREATE OR REPLACE VIEW Location_dim_view AS
-- Grain: 1 row = 1 Location.
-- Schema mirrors Dim_Location in FHIR_DWH_TEST (mock DWH): same column names and order,
-- with native types (Timestamp) instead of casting everything to TEXT.
-- Building / Floor / Ward / Room / BedType are derived from the partOf hierarchy or
-- naming conventions and are left NULL here (add via mapping later).
WITH picked AS (
  SELECT L.*,
    try_element_at(L.identifier, 1) AS lid,
    try_element_at(L.type, 1) AS ltype
  FROM Location AS L
)
SELECT
  id AS LocationID,
  lid.value AS IdentifierValue,
  status AS Status,
  COALESCE(operationalStatus.display, operationalStatus.code) AS OperationalStatus,
  name AS LocationName,
  COALESCE(try_element_at(ltype.coding, 1).display, ltype.text) AS LocationTypeDisplay,
  COALESCE(try_element_at(physicalType.coding, 1).display, physicalType.text) AS PhysicalTypeDisplay,
  managingOrganization.organizationId AS ManagingOrganizationID,
  partOf.locationId AS ParentLocationID,
  CAST(NULL AS STRING) AS Building,
  CAST(NULL AS STRING) AS Floor,
  CAST(NULL AS STRING) AS Ward,
  CAST(NULL AS STRING) AS Room,
  CAST(NULL AS STRING) AS BedType,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
