CREATE OR REPLACE VIEW Encounter_hospitalization_fact_view AS
-- Grain: 1 row = 1 Encounter having hospitalization details.
-- Schema mirrors Fact_Encounter_Hospitalization in FHIR_DWH_TEST (mock DWH): same column
-- names and order, with native types (Boolean/Int/Timestamp) instead of casting everything
-- to TEXT.
SELECT
  E.id AS EncounterHospitalizationID,
  E.id AS EncounterID,
  E.subject.patientId AS PatientID,
  E.class.code = 'IMP' AS IsInpatientFlag,
  to_timestamp(E.period.start) AS AdmissionDateTime,
  to_timestamp(E.period.end) AS DischargeDateTime,
  CAST(date_format(to_timestamp(E.period.start), 'yyyyMMdd') AS INT) AS AdmissionDateKey,
  CAST(date_format(to_timestamp(E.period.end), 'yyyyMMdd') AS INT) AS DischargeDateKey,
  datediff(to_timestamp(E.period.end), to_timestamp(E.period.start)) AS LengthOfStayDays,
  COALESCE(try_element_at(E.hospitalization.admitSource.coding, 1).display, E.hospitalization.admitSource.text) AS AdmitSourceDisplay,
  COALESCE(try_element_at(E.hospitalization.dischargeDisposition.coding, 1).display, E.hospitalization.dischargeDisposition.text) AS DischargeDispositionDisplay,
  to_timestamp(E.meta.lastUpdated) AS SourceLastUpdated
FROM Encounter AS E
WHERE E.hospitalization IS NOT NULL
;
