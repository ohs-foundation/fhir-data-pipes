CREATE OR REPLACE VIEW Medication_dim_view AS
-- Grain: 1 row = 1 Medication.
-- Schema mirrors Dim_Medication in FHIR_DWH_TEST (mock DWH): same column names and order,
-- with native types (Boolean/Timestamp) instead of casting everything to TEXT.
-- MedicationGroup / IsAntibioticFlag / DefaultRouteDisplay need a business mapping
-- outside FHIR (NULL here). ATCCode is only filled when the code system is ATC.
SELECT
  id AS MedicationID,
  try_element_at(code.coding, 1).code AS MedicationCode,
  try_element_at(code.coding, 1).system AS MedicationSystem,
  COALESCE(try_element_at(code.coding, 1).display, code.text) AS MedicationDisplay,
  status AS Status,
  COALESCE(try_element_at(form.coding, 1).display, form.text) AS MedicationFormDisplay,
  CAST(NULL AS STRING) AS MedicationGroup,
  CAST(NULL AS BOOLEAN) AS IsAntibioticFlag,
  CASE WHEN lower(try_element_at(code.coding, 1).system) LIKE '%atc%' THEN try_element_at(code.coding, 1).code END AS ATCCode,
  CAST(NULL AS STRING) AS DefaultRouteDisplay,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM Medication
;
