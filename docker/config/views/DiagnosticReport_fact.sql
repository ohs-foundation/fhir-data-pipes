CREATE OR REPLACE VIEW DiagnosticReport_fact_view AS
-- Grain: 1 row = 1 DiagnosticReport (phiếu kết quả CĐHA/xét nghiệm).
-- List-valued fields (category/performer/resultsInterpreter/specimen/basedOn/conclusionCode)
-- reduced to their first representative element. result/imagingStudy/presentedForm giữ dạng đếm.
-- InterpreterIdentifierValue (thêm ở cuối): resultsInterpreter trong data thật dùng reference
-- dạng chỉ có `identifier` (số CCHN), không có `.reference` nên InterpreterPractitionerID/
-- InterpreterOrganizationID luôn NULL - lưu thêm số CCHN thô để không mất thông tin.
WITH picked AS (
  SELECT D.*,
    try_element_at(D.identifier, 1) AS did,
    try_element_at(D.category, 1) AS dcat,
    try_element_at(D.performer, 1) AS dperf,
    try_element_at(D.resultsInterpreter, 1) AS dinterp,
    try_element_at(D.specimen, 1) AS dspec,
    try_element_at(D.basedOn, 1) AS dbased,
    try_element_at(D.conclusionCode, 1) AS dconc
  FROM DiagnosticReport AS D
)
SELECT
  id AS DiagnosticReportID,
  did.value AS IdentifierValue,
  did.system AS IdentifierSystem,
  status AS DiagnosticReportStatus,
  try_element_at(dcat.coding, 1).code AS CategoryCode,
  COALESCE(try_element_at(dcat.coding, 1).display, dcat.text) AS CategoryDisplay,
  try_element_at(code.coding, 1).code AS ReportCode,
  try_element_at(code.coding, 1).system AS ReportSystem,
  COALESCE(try_element_at(code.coding, 1).display, code.text) AS ReportDisplay,
  subject.patientId AS PatientID,
  encounter.encounterId AS EncounterID,
  CAST(date_format(to_timestamp(COALESCE(effective.dateTime, effective.period.start)), 'yyyyMMdd') AS INT) AS EffectiveDateKey,
  to_timestamp(COALESCE(effective.dateTime, effective.period.start)) AS EffectiveDateTime,
  to_timestamp(effective.period.`end`) AS EffectiveEndDateTime,
  to_timestamp(issued) AS IssuedDateTime,
  dperf.practitionerId AS PerformerPractitionerID,
  dperf.practitionerRoleId AS PerformerPractitionerRoleID,
  dperf.organizationId AS PerformerOrganizationID,
  dinterp.practitionerId AS InterpreterPractitionerID,
  dinterp.organizationId AS InterpreterOrganizationID,
  dspec.specimenId AS SpecimenID,
  dbased.serviceRequestId AS ServiceRequestID,
  conclusion AS Conclusion,
  try_element_at(dconc.coding, 1).code AS ConclusionCode,
  COALESCE(try_element_at(dconc.coding, 1).display, dconc.text) AS ConclusionDisplay,
  CASE WHEN result IS NULL THEN 0 ELSE size(result) END AS ResultCount,
  CASE WHEN imagingStudy IS NULL THEN 0 ELSE size(imagingStudy) END AS ImagingStudyCount,
  CASE WHEN presentedForm IS NULL THEN 0 ELSE size(presentedForm) END AS PresentedFormCount,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated,
  dinterp.identifier.value AS InterpreterIdentifierValue
FROM picked
;
