CREATE OR REPLACE VIEW AdverseEvent_fact_view AS
-- Grain: 1 row = 1 AdverseEvent. The category array is reduced to its first element.
-- Schema mirrors Fact_AdverseEvent in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Int/Timestamp) instead of casting everything to TEXT.
-- ContributingFactorDisplay is an R5 element NOT present in R4; kept NULL.
-- ManagingOrganizationID and the Is*Flag columns require a business/taxonomy mapping and
-- are left NULL (derive downstream).
WITH picked AS (
  SELECT A.*,
    try_element_at(A.category, 1) AS acat
  FROM AdverseEvent AS A
)
SELECT
  id AS AdverseEventID,
  identifier.value AS IdentifierValue,
  actuality AS Actuality,
  try_element_at(event.coding, 1).code AS EventCode,
  COALESCE(try_element_at(event.coding, 1).display, event.text) AS EventDisplay,
  try_element_at(acat.coding, 1).code AS EventCategoryCode,
  COALESCE(try_element_at(acat.coding, 1).display, acat.text) AS EventCategoryDisplay,
  subject.patientId AS PatientID,
  encounter.encounterId AS EncounterID,
  CAST(date_format(to_timestamp(date), 'yyyyMMdd') AS INT) AS AdverseEventDateKey,
  to_timestamp(date) AS AdverseEventDateTime,
  location.locationId AS LocationID,
  CAST(NULL AS STRING) AS ManagingOrganizationID,
  COALESCE(try_element_at(seriousness.coding, 1).display, seriousness.text) AS SeriousnessDisplay,
  COALESCE(try_element_at(severity.coding, 1).display, severity.text) AS SeverityDisplay,
  COALESCE(try_element_at(outcome.coding, 1).display, outcome.text) AS OutcomeDisplay,
  COALESCE(recorder.practitionerId, recorder.practitionerRoleId, recorder.patientId,
           recorder.relatedPersonId) AS RecorderID,
  CAST(NULL AS STRING) AS ContributingFactorDisplay,
  CAST(NULL AS BOOLEAN) AS IsPreventableFlag,
  CAST(NULL AS BOOLEAN) AS IsHAIFlag,
  CAST(NULL AS BOOLEAN) AS IsMedicationErrorFlag,
  CAST(NULL AS BOOLEAN) AS IsFallFlag,
  CAST(NULL AS BOOLEAN) AS IsSSIFlag,
  CAST(NULL AS BOOLEAN) AS IsMortalityRelatedFlag,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
