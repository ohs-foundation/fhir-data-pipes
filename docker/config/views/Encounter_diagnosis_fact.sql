CREATE OR REPLACE VIEW Encounter_diagnosis_fact_view AS
-- Grain: 1 row = 1 phần tử trong Encounter.diagnosis[] (1 quan hệ Encounter-Diagnosis).
-- Đây là bảng "bridge" nối Fact_Encounter sang Dim_Condition (qua ConditionKey) mà
-- KHÔNG làm nổ số dòng Fact_Encounter - Fact_Encounter không còn lưu diagnosis dạng
-- text/mã nối chuỗi trực tiếp nữa, xem Encounter_fact.sql.
-- Schema mirrors Fact_Encounter_Diagnosis in FHIR_DWH_TEST (mock DWH): same column names
-- and order, with native types (Boolean/Int/Timestamp) instead of casting everything to
-- TEXT.
-- DiagnosisType/DiagnosisRank lấy từ Encounter.diagnosis[].use/.rank - đã xác nhận có
-- data thật trên FHIR server (role AD=Admission/DD=Discharge/CM=Comorbidity, rank cho
-- chẩn đoán ra viện), KHÔNG phải luôn NULL như bản trước của file này.
-- ConditionDisplay: ưu tiên C.code.text (tiếng Việt) trước coding.display (tiếng Anh) -
-- khớp đúng convention đã dùng ở Condition_dim.sql (trước đây file này bị ngược thứ tự).
WITH diag_explode AS (
  SELECT
    E.id AS EncounterID,
    E.meta.lastUpdated AS EncounterLastUpdated,
    pos,
    dx
  FROM Encounter AS E
  LATERAL VIEW posexplode(E.diagnosis) AS pos, dx
)
SELECT
  concat(de.EncounterID, '-', CAST(de.pos AS STRING)) AS EncounterDiagnosisID,
  de.EncounterID,
  CAST('Condition' AS STRING) AS DiagnosisReferenceType,
  de.dx.condition.conditionId AS DiagnosisReferenceID,
  de.dx.condition.conditionId AS ConditionID,
  concat(try_element_at(C.code.coding, 1).system, '|', try_element_at(C.code.coding, 1).code) AS ConditionKey,
  try_element_at(C.code.coding, 1).code AS ConditionCode,
  COALESCE(C.code.text, try_element_at(C.code.coding, 1).display, de.dx.condition.display) AS ConditionDisplay,
  try_element_at(de.dx.use.coding, 1).code AS DiagnosisType,
  de.dx.rank AS DiagnosisRank,
  de.dx.rank = 1 AS IsPrimaryDiagnosisFlag,
  to_timestamp(de.EncounterLastUpdated) AS SourceLastUpdated
FROM diag_explode de
  LEFT JOIN Condition C ON C.id = de.dx.condition.conditionId
;
