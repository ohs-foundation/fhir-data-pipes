CREATE OR REPLACE VIEW MedicationRequest_fact_view AS
-- Grain: 1 row = 1 MedicationRequest. category and dosageInstruction arrays are reduced
-- to their first element to keep a single row.
-- Schema mirrors Fact_MedicationRequest in FHIR_DWH_TEST (mock DWH): same column names
-- and order, with native types (Boolean/Int/Double/Timestamp) instead of casting
-- everything to TEXT.
-- MedicationGroup / IsAntibioticFlag need a business (ATC) mapping; kept NULL.
-- MedicationCode/MedicationDisplay (thêm ở cuối): medication[x] là choice type
-- (medicationCodeableConcept hoặc medicationReference). Xác nhận trên data thật:
-- 100/100 MedicationRequest lấy mẫu đều dùng medicationCodeableConcept (mã/tên thuốc
-- ghi thẳng trong request, không trỏ sang resource Medication) - KHÔNG có
-- medicationReference. Trước đây view chỉ lấy medication.reference.medicationId nên
-- MedicationID luôn NULL và tên/mã thuốc thực tế bị thiếu hoàn toàn.
WITH picked AS (
  SELECT M.*,
    try_element_at(M.identifier, 1) AS mid,
    try_element_at(M.category, 1) AS mcat,
    try_element_at(M.dosageInstruction, 1) AS mdi
  FROM MedicationRequest AS M
)
SELECT
  id AS MedicationRequestID,
  mid.value AS IdentifierValue,
  status AS MedicationRequestStatus,
  intent AS MedicationRequestIntent,
  COALESCE(try_element_at(mcat.coding, 1).display, mcat.text) AS MedicationRequestCategoryDisplay,
  priority AS Priority,
  medication.reference.medicationId AS MedicationID,
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
  CAST(NULL AS STRING) AS MedicationGroup,
  CAST(NULL AS BOOLEAN) AS IsAntibioticFlag,
  COALESCE(try_element_at(mdi.route.coding, 1).display, mdi.route.text) AS RouteDisplay,
  try_element_at(mdi.doseAndRate, 1).dose.quantity.value AS DoseQuantityValue,
  try_element_at(mdi.doseAndRate, 1).dose.quantity.unit AS DoseQuantityUnit,
  dispenseRequest.expectedSupplyDuration.value AS ExpectedSupplyDurationValue,
  dispenseRequest.expectedSupplyDuration.unit AS ExpectedSupplyDurationUnit,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated,
  try_element_at(medication.codeableConcept.coding, 1).code AS MedicationCode,
  COALESCE(try_element_at(medication.codeableConcept.coding, 1).display, medication.codeableConcept.text) AS MedicationDisplay
FROM picked
;
