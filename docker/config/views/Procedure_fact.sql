CREATE OR REPLACE VIEW Procedure_fact_view AS
-- Grain: 1 row = 1 Procedure. code.coding / performer / bodySite / basedOn are reduced
-- to their first element to keep a single row.
-- Schema mirrors Fact_Procedure in FHIR_DWH_TEST (mock DWH): same column names and order,
-- with native types (Int/Timestamp) instead of casting everything to TEXT.
-- OrderDateTime lives on the ordering ServiceRequest, not on Procedure; kept NULL.
WITH picked AS (
  SELECT P.*,
    try_element_at(P.identifier, 1) AS pid,
    try_element_at(P.code.coding, 1) AS pcc,
    try_element_at(P.category.coding, 1) AS pcat,
    try_element_at(P.performer, 1) AS pperf,
    try_element_at(P.bodySite, 1) AS pbs,
    try_element_at(P.basedOn, 1) AS pbo
  FROM Procedure AS P
)
SELECT
  id AS ProcedureID,
  pid.value AS IdentifierValue,
  status AS ProcedureStatus,
  COALESCE(pcat.display, category.text) AS ProcedureCategoryDisplay,
  pcc.code AS ProcedureCode,
  COALESCE(pcc.display, code.text) AS ProcedureDisplay,
  subject.patientId AS PatientID,
  encounter.encounterId AS EncounterID,
  CASE
    WHEN pbo.serviceRequestId IS NOT NULL THEN 'ServiceRequest'
    WHEN pbo.carePlanId IS NOT NULL THEN 'CarePlan'
  END AS BasedOnReferenceType,
  pbo.serviceRequestId AS ServiceRequestID,
  CAST(NULL AS TIMESTAMP) AS OrderDateTime,
  CAST(date_format(to_timestamp(COALESCE(performed.dateTime, performed.period.start)), 'yyyyMMdd') AS INT) AS PerformedDateKey,
  to_timestamp(COALESCE(performed.dateTime, performed.period.start)) AS PerformedStartTime,
  to_timestamp(performed.period.`end`) AS PerformedEndTime,
  CAST((unix_timestamp(to_timestamp(performed.period.`end`)) - unix_timestamp(to_timestamp(performed.period.start))) / 60 AS BIGINT) AS PerformedDurationMinutes,
  CASE
    WHEN pperf.actor.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN pperf.actor.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN pperf.actor.organizationId IS NOT NULL THEN 'Organization'
  END AS PerformerReferenceType,
  COALESCE(pperf.actor.practitionerId, pperf.actor.practitionerRoleId, pperf.actor.organizationId) AS PerformerID,
  pperf.actor.practitionerId AS PractitionerID,
  pperf.actor.practitionerRoleId AS PractitionerRoleID,
  pperf.onBehalfOf.organizationId AS OnBehalfOfOrganizationID,
  location.locationId AS LocationID,
  COALESCE(try_element_at(pbs.coding, 1).display, pbs.text) AS BodySiteDisplay,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
