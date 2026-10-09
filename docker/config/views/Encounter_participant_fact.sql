CREATE OR REPLACE VIEW Encounter_participant_fact_view AS
-- Grain: 1 row = 1 participant of an Encounter.
-- Schema mirrors Fact_Encounter_Participant in FHIR_DWH_TEST (mock DWH): same column
-- names and order, with native types (Boolean/Int/Timestamp) instead of casting everything
-- to TEXT.
SELECT
  concat(E.id, '-', CAST(PPos AS STRING)) AS EncounterParticipantID,
  E.id AS EncounterID,
  try_element_at(try_element_at(EP.type, 1).coding, 1).code AS ParticipantTypeCode,
  to_timestamp(EP.period.start) AS ParticipantStartTime,
  to_timestamp(EP.period.end) AS ParticipantEndTime,
  CAST((unix_timestamp(to_timestamp(EP.period.end)) - unix_timestamp(to_timestamp(EP.period.start))) / 60 AS BIGINT) AS ParticipantDurationMinutes,
  CASE
    WHEN EP.individual.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN EP.individual.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN EP.individual.relatedPersonId IS NOT NULL THEN 'RelatedPerson'
  END AS IndividualReferenceType,
  EP.individual.practitionerId AS PractitionerID,
  EP.individual.practitionerRoleId AS PractitionerRoleID,
  try_element_at(try_element_at(EP.type, 1).coding, 1).code IN ('PPRF', 'ATND') AS IsPrimaryParticipantFlag,
  to_timestamp(E.meta.lastUpdated) AS SourceLastUpdated
FROM Encounter AS E
  LATERAL VIEW posexplode(E.participant) AS PPos, EP
;
