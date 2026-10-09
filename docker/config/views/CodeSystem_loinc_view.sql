CREATE OR REPLACE VIEW LOINC_codesystem_view AS
-- Đọc thẳng bảng CodeSystem (Bunsen-native, không script/JDBC-Postgres riêng nào) - xem
-- comment đầy đủ trong CodeSystem_icd10_view.sql. vn-loinc-cs KHÔNG lồng cấp (phẳng), tiếng
-- Việt nằm trong designation[language=vi], không có field display.
WITH cs AS (
  SELECT concept
  FROM CodeSystem
  WHERE url = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-loinc-cs'
)
SELECT
  C.code AS Code,
  'http://fhir.hl7.org.vn/core/CodeSystem/vn-loinc-cs' AS System,
  try_element_at(filter(C.designation, d -> d.language = 'vi'), 1).value AS DisplayVi
FROM cs
  LATERAL VIEW explode(concept) t AS C
WHERE C.code IS NOT NULL
;
