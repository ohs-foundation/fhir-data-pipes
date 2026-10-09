CREATE OR REPLACE VIEW QuestionnaireResponse_fact_view AS
-- Grain: 1 row = 1 QuestionnaireResponse (whole survey).
-- Schema mirrors Fact_QuestionnaireResponse in FHIR_DWH_TEST (mock DWH): same column
-- names and order, with native types (Boolean/Int/Double/Timestamp) instead of casting
-- everything to TEXT.
-- The per-question scores (OverallScore ... NPSScore, CommentText, *Flag) depend on a
-- form-specific item.linkId -> metric mapping which is NOT knowable from FHIR alone;
-- they are kept NULL and should be populated per questionnaire. ServiceProvider /
-- PrimaryLocation / PrimaryPractitioner / EncounterClass are derived from the linked
-- Encounter and are NULL here.
SELECT
  id AS QuestionnaireResponseID,
  identifier.value AS IdentifierValue,
  questionnaire AS QuestionnaireID,
  status AS QuestionnaireResponseStatus,
  subject.patientId AS PatientID,
  encounter.encounterId AS EncounterID,
  CAST(date_format(to_timestamp(authored), 'yyyyMMdd') AS INT) AS AuthoredDateKey,
  to_timestamp(authored) AS AuthoredDateTime,
  CASE
    WHEN source.patientId IS NOT NULL THEN 'Patient'
    WHEN source.relatedPersonId IS NOT NULL THEN 'RelatedPerson'
    WHEN source.practitionerId IS NOT NULL THEN 'Practitioner'
  END AS SourceReferenceType,
  source.patientId AS SourcePatientID,
  CAST(NULL AS STRING) AS ServiceProviderOrganizationID,
  CAST(NULL AS STRING) AS PrimaryLocationID,
  CAST(NULL AS STRING) AS PrimaryPractitionerID,
  CAST(NULL AS STRING) AS EncounterClassCode,
  CAST(NULL AS DOUBLE) AS OverallScore,
  CAST(NULL AS DOUBLE) AS SatisfactionScore,
  CAST(NULL AS DOUBLE) AS WaitingScore,
  CAST(NULL AS DOUBLE) AS StaffScore,
  CAST(NULL AS DOUBLE) AS FacilityScore,
  CAST(NULL AS DOUBLE) AS NPSScore,
  CAST(NULL AS STRING) AS CommentText,
  CAST(NULL AS BOOLEAN) AS RecommendationFlag,
  CAST(NULL AS BOOLEAN) AS LowScoreFlag,
  CAST(NULL AS BOOLEAN) AS ComplaintFlag,
  CAST(NULL AS BOOLEAN) AS PositiveFeedbackFlag,
  CASE WHEN item IS NULL THEN 0 ELSE size(item) END AS QuestionCount,
  CASE WHEN item IS NULL THEN 0
       ELSE size(filter(item, x -> x.answer IS NOT NULL AND size(x.answer) > 0)) END AS AnsweredQuestionCount,
  CAST(NULL AS DOUBLE) AS CompletionRate,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM QuestionnaireResponse
;
