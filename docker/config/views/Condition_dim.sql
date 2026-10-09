CREATE OR REPLACE VIEW Condition_dim_view AS
-- Grain: 1 row = 1 distinct condition code (system|code), NOT 1 per Condition resource.
-- Schema mirrors Dim_Condition in FHIR_DWH_TEST (mock DWH): same column names and order,
-- with native types (Boolean/Timestamp) instead of casting everything to TEXT.
-- IsChronicFlag / IsInfectiousFlag are NOT in FHIR and must come from a business mapping
-- table (NULL here).
-- ConditionDisplay: ưu tiên Condition.code.text (tiếng Việt, dùng để join/báo cáo) thay vì
-- coding.display (thường là tiếng Anh, vd "Chronic obstructive pulmonary disease..." trong
-- khi code.text là "Bệnh phổi tắc nghẽn mạn tính có đợt cấp, không đặc hiệu..."). Fallback
-- ICD10_codesystem_view.DisplayVi (tiếng Việt, từ chính CodeSystem vn-icd10-cs) khi
-- Condition đó không có code.text, cuối cùng mới tới coding.display (tiếng Anh).
-- ConditionGroup: chương ICD-10 (ChapterCode, vd "I", "II"...; fallback ChapterID dạng
-- range "A00-B99") lấy từ ICD10_codesystem_view (CodeSystem_icd10_view.sql - đọc thẳng
-- resource CodeSystem, KHÔNG qua script/Postgres riêng nào, xem comment đầy đủ ở đó). NULL
-- với code không phải ICD-10.
-- Spark SQL không cho LATERAL VIEW đứng trước JOIN trong cùng 1 relation (PARSE_SYNTAX_ERROR
-- "Syntax error at or near 'LEFT'") - nên explode tách CTE riêng, JOIN Dim_ICD10 ở query
-- ngoài (không còn LATERAL VIEW) mới hợp lệ.
WITH cc_explode AS (
  SELECT
    C.code.text AS ConditionText,
    C.meta.lastUpdated AS ConditionLastUpdated,
    CCC.system AS CodingSystem,
    CCC.code AS CodingCode,
    CCC.display AS CodingDisplay
  FROM Condition AS C
    LATERAL VIEW OUTER explode(C.code.coding) AS CCC
  WHERE CCC.code IS NOT NULL
)
SELECT
  concat(cc.CodingSystem, '|', cc.CodingCode) AS ConditionKey,
  cc.CodingCode AS ConditionCode,
  cc.CodingSystem AS ConditionSystem,
  max(COALESCE(cc.ConditionText, cc.CodingDisplay, D10.DisplayVi)) AS ConditionDisplay,
  CASE WHEN lower(cc.CodingSystem) LIKE '%icd-10%' OR lower(cc.CodingSystem) LIKE '%icd10%' THEN cc.CodingCode END AS ICD10Code,
  CASE WHEN lower(cc.CodingSystem) LIKE '%snomed%' THEN cc.CodingCode END AS SNOMEDCode,
  max(COALESCE(D10.ChapterCode, D10.ChapterID)) AS ConditionGroup,
  CAST(NULL AS BOOLEAN) AS IsChronicFlag,
  CAST(NULL AS BOOLEAN) AS IsInfectiousFlag,
  max(to_timestamp(cc.ConditionLastUpdated)) AS SourceLastUpdated
FROM cc_explode AS cc
  LEFT JOIN ICD10_codesystem_view AS D10 ON D10.System = cc.CodingSystem AND D10.Code = cc.CodingCode
GROUP BY cc.CodingSystem, cc.CodingCode
;
