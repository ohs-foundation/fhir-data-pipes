CREATE OR REPLACE VIEW HealthcareService_dim_view AS
-- Grain: 1 row = 1 HealthcareService. category / type arrays reduced to their first element.
-- Schema mirrors Dim_HealthcareService in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Timestamp) instead of casting everything to TEXT.
WITH picked AS (
  SELECT H.*,
    try_element_at(H.identifier, 1) AS hid,
    try_element_at(H.category, 1) AS hcat,
    try_element_at(H.type, 1) AS htype
  FROM HealthcareService AS H
)
SELECT
  id AS HealthcareServiceID,
  hid.value AS IdentifierValue,
  active AS ActiveFlag,
  providedBy.organizationId AS ProvidedByOrganizationID,
  COALESCE(try_element_at(hcat.coding, 1).display, hcat.text) AS ServiceCategoryDisplay,
  COALESCE(try_element_at(htype.coding, 1).display, htype.text) AS ServiceTypeDisplay,
  name AS ServiceName,
  appointmentRequired AS AppointmentRequiredFlag,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
