CREATE OR REPLACE VIEW ICD10_codesystem_view AS
-- Đọc thẳng bảng CodeSystem mà Bunsen convert bình thường (concept KHÔNG phải extension
-- nên không bị Bunsen cắt như đã gặp với Encounter.extension - đã verify thật: `DESCRIBE
-- CodeSystem` cho thấy Bunsen giữ 3 cấp `concept` lồng nhau dù config recursiveDepth: 1).
-- Không cần script/service riêng nào (đã bỏ Condition_icd10_ref.sql kiểu cũ trỏ JDBC
-- Postgres) - CodeSystem được thêm vào resourceList (application.yaml) như 1 resource FHIR
-- bình thường, pipeline tự crawl lại mỗi lần chạy giống Patient/Encounter/Condition.
-- vn-icd10-cs lồng 2 cấp thật sự dùng: category 3 ký tự (vd "J44") -> mã chi tiết (vd
-- "J44.1"). UNION ALL 2 cấp vì Condition trên data thật dùng cả 2 loại mã.
-- property.value là 1 struct gộp mọi kiểu (string/boolean/integer/...) - Bunsen convert
-- value[x] của property thành 1 struct duy nhất, lấy đúng field theo kiểu khai báo trong
-- CodeSystem gốc (chapter-code/chapter-id/section-id là valueString, leaf là valueBoolean).
WITH cs AS (
  SELECT concept
  FROM CodeSystem
  WHERE url = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-icd10-cs'
),
lvl1 AS (
  SELECT C1.code, C1.display, C1.definition, C1.property
  FROM cs
    LATERAL VIEW explode(concept) t1 AS C1
),
lvl2 AS (
  SELECT C2.code, C2.display, C2.definition, C2.property
  FROM cs
    LATERAL VIEW explode(concept) t1 AS C1
    LATERAL VIEW explode(C1.concept) t2 AS C2
),
all_concepts AS (
  SELECT * FROM lvl1
  UNION ALL
  SELECT * FROM lvl2
)
SELECT
  code AS Code,
  'http://fhir.hl7.org.vn/core/CodeSystem/vn-icd10-cs' AS System,
  display AS DisplayVi,
  definition AS DisplayEn,
  try_element_at(filter(property, p -> p.code = 'level'), 1).value.string AS Level,
  try_element_at(filter(property, p -> p.code = 'chapter-id'), 1).value.string AS ChapterID,
  try_element_at(filter(property, p -> p.code = 'chapter-code'), 1).value.string AS ChapterCode,
  try_element_at(filter(property, p -> p.code = 'section-id'), 1).value.string AS SectionID,
  try_element_at(filter(property, p -> p.code = 'leaf'), 1).value.boolean AS IsLeaf
FROM all_concepts
WHERE code IS NOT NULL
;
