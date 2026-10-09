CREATE OR REPLACE VIEW Observation_fact_view AS
-- Grain: 1 row = 1 Observation. category / code.coding / performer / interpretation
-- are reduced to their first element to keep a single row.
-- Schema mirrors Fact_Observation in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Int/Double/Timestamp) instead of casting everything
-- to TEXT.
-- ValueString/ValueCodeableConceptCode/Display/ValueBoolean/ValueInteger (thêm ở cuối):
-- trước đây ValueType đoán đúng loại giá trị (String/CodeableConcept/Boolean/Integer) nhưng
-- không có cột nào lưu giá trị thật ngoài Quantity - xác nhận trên data thật: các Observation
-- kết luận CĐHA/xét nghiệm dùng valueString rất phổ biến (vd "Nốt mờ nhỏ thùy trên phổi
-- trái..."), ValueType báo đúng 'String' nhưng nội dung bị mất hoàn toàn.
-- PerformerIdentifierValue (thêm ở cuối): Observation.performer trong data xét nghiệm dùng
-- reference dạng chỉ có `identifier` (số CCHN), không có `.reference` nên không resolve được
-- practitionerId - lưu thêm số CCHN thô để không mất thông tin người thực hiện.
-- ObservationDisplay: data thật dùng hệ mã LOINC chuẩn (http://loinc.org) với display tiếng
-- Anh (vd "Body weight", "Heart rate"), code.text hầu như không có. LOINC_codesystem_view
-- (CodeSystem_loinc_view.sql - đọc thẳng resource CodeSystem vn-loinc-cs, KHÔNG qua script/
-- Postgres riêng nào) dịch sang tiếng Việt qua DisplayVi, join theo code (dùng chung không
-- gian mã LOINC dù canonical URL khác - "http://fhir.hl7.org.vn/core/CodeSystem/vn-loinc-cs"
-- - nên không so system).
WITH picked AS (
  SELECT O.*,
    try_element_at(O.identifier, 1) AS oid,
    try_element_at(O.category, 1) AS ocat,
    try_element_at(O.code.coding, 1) AS occ,
    try_element_at(O.performer, 1) AS operf,
    try_element_at(O.interpretation, 1) AS ointerp
  FROM Observation AS O
),

loinc_values AS (
  SELECT id AS ObservationID, DLOINC.DisplayVi
  FROM picked
    LEFT JOIN LOINC_codesystem_view AS DLOINC
      ON DLOINC.Code = picked.occ.code
      AND picked.occ.system IN ('http://loinc.org', 'http://fhir.hl7.org.vn/core/CodeSystem/vn-loinc-cs')
)

SELECT
  id AS ObservationID,
  oid.value AS IdentifierValue,
  status AS ObservationStatus,
  try_element_at(ocat.coding, 1).code AS ObservationCategoryCode,
  COALESCE(try_element_at(ocat.coding, 1).display, ocat.text) AS ObservationCategoryDisplay,
  occ.code AS ObservationCode,
  occ.system AS ObservationSystem,
  COALESCE(code.text, lv.DisplayVi, occ.display) AS ObservationDisplay,
  subject.patientId AS PatientID,
  encounter.encounterId AS EncounterID,
  CAST(date_format(to_timestamp(effective.dateTime), 'yyyyMMdd') AS INT) AS EffectiveDateKey,
  to_timestamp(effective.dateTime) AS EffectiveDateTime,
  to_timestamp(issued) AS IssuedDateTime,
  CASE
    WHEN operf.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN operf.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN operf.organizationId IS NOT NULL THEN 'Organization'
  END AS PerformerReferenceType,
  COALESCE(operf.practitionerId, operf.practitionerRoleId, operf.organizationId) AS PerformerID,
  CASE
    WHEN value.quantity.value IS NOT NULL THEN 'Quantity'
    WHEN value.codeableConcept IS NOT NULL THEN 'CodeableConcept'
    WHEN value.String IS NOT NULL THEN 'String'
    WHEN value.Boolean IS NOT NULL THEN 'Boolean'
    WHEN value.Integer IS NOT NULL THEN 'Integer'
  END AS ValueType,
  value.quantity.value AS ValueQuantity,
  value.quantity.unit AS ValueUnit,
  COALESCE(try_element_at(ointerp.coding, 1).display, ointerp.text) AS InterpretationDisplay,
  COALESCE(component IS NOT NULL AND size(component) > 0, FALSE) AS HasComponentFlag,
  CASE WHEN component IS NULL THEN 0 ELSE size(component) END AS ComponentCount,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated,
  value.String AS ValueString,
  value.Boolean AS ValueBoolean,
  value.Integer AS ValueInteger,
  try_element_at(value.codeableConcept.coding, 1).code AS ValueCodeableConceptCode,
  COALESCE(try_element_at(value.codeableConcept.coding, 1).display, value.codeableConcept.text) AS ValueCodeableConceptDisplay,
  operf.identifier.value AS PerformerIdentifierValue
FROM picked
  LEFT JOIN loinc_values lv ON lv.ObservationID = picked.id
;
