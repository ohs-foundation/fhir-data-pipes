CREATE OR REPLACE VIEW ServiceRequest_fact_view AS
-- Grain: 1 row = 1 ServiceRequest. category / performer / reasonCode arrays reduced to
-- their first element.
-- Schema mirrors Fact_ServiceRequest in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Int/Timestamp) instead of casting everything to TEXT.
WITH picked AS (
  SELECT S.*,
    try_element_at(S.identifier, 1) AS sid,
    try_element_at(S.category, 1) AS scat,
    try_element_at(S.performer, 1) AS sperf,
    try_element_at(S.reasonCode, 1) AS sreason
  FROM ServiceRequest AS S
)
SELECT
  id AS ServiceRequestID,
  sid.value AS IdentifierValue,
  status AS ServiceRequestStatus,
  intent AS ServiceRequestIntent,
  priority AS Priority,
  try_element_at(scat.coding, 1).code AS CategoryCode,
  COALESCE(try_element_at(scat.coding, 1).display, scat.text) AS CategoryDisplay,
  try_element_at(code.coding, 1).code AS ServiceRequestCode,
  COALESCE(try_element_at(code.coding, 1).display, code.text) AS ServiceRequestDisplay,
  subject.patientId AS PatientID,
  encounter.encounterId AS EncounterID,
  CAST(date_format(to_timestamp(authoredOn), 'yyyyMMdd') AS INT) AS AuthoredDateKey,
  to_timestamp(authoredOn) AS AuthoredDateTime,
  CASE
    WHEN requester.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN requester.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN requester.organizationId IS NOT NULL THEN 'Organization'
  END AS RequesterReferenceType,
  COALESCE(requester.practitionerId, requester.practitionerRoleId, requester.organizationId) AS RequesterID,
  requester.practitionerId AS RequesterPractitionerID,
  requester.organizationId AS RequesterOrganizationID,
  CASE
    WHEN sperf.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN sperf.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN sperf.organizationId IS NOT NULL THEN 'Organization'
    WHEN sperf.healthcareServiceId IS NOT NULL THEN 'HealthcareService'
  END AS PerformerReferenceType,
  COALESCE(sperf.practitionerId, sperf.practitionerRoleId, sperf.organizationId,
           sperf.healthcareServiceId) AS PerformerID,
  sperf.healthcareServiceId AS HealthcareServiceID,
  COALESCE(status = 'completed', FALSE) AS IsCompletedFlag,
  COALESCE(status IN ('revoked', 'entered-in-error'), FALSE) AS IsCancelledFlag,
  COALESCE(try_element_at(sreason.coding, 1).display, sreason.text) AS ReasonDisplay,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
