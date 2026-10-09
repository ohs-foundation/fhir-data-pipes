CREATE OR REPLACE VIEW ChargeItemDefinition_dim_view AS
-- Grain: 1 row = 1 ChargeItemDefinition. propertyGroup / priceComponent reduced to first.
-- Schema mirrors Dim_ChargeItemDefinition in FHIR_DWH_TEST (mock DWH): same column names
-- and order, with native types (Double/Timestamp) instead of casting everything to TEXT.
-- InstanceTypeDisplay is NOT part of FHIR R4 ChargeItemDefinition.instance (a bare
-- Reference); kept NULL.
WITH picked AS (
  SELECT D.*,
    try_element_at(D.identifier, 1) AS did,
    try_element_at(D.propertyGroup, 1) AS dpg
  FROM ChargeItemDefinition AS D
)
SELECT
  id AS ChargeItemDefinitionID,
  url AS Url,
  did.value AS IdentifierValue,
  status AS Status,
  title AS Title,
  try_element_at(code.coding, 1).code AS Code,
  try_element_at(code.coding, 1).system AS CodeSystem,
  COALESCE(try_element_at(code.coding, 1).display, code.text) AS CodeDisplay,
  CAST(NULL AS STRING) AS InstanceTypeDisplay,
  try_element_at(dpg.priceComponent, 1).amount.value AS UnitPrice,
  try_element_at(dpg.priceComponent, 1).amount.currency AS Currency,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
