CREATE OR REPLACE VIEW Encounter_identifier_fact_view AS
-- Grain: 1 row = 1 phần tử trong Encounter.identifier[] (1 quan hệ Encounter-Identifier).
-- Bảng "bridge" giữ TẤT CẢ identifier của Encounter, thay vì Fact_Encounter tự chọn 1
-- giá trị đại diện. Lý do: 1 Encounter có thể có tới 3 identifier - mã lượt KCB
-- (MA_LUOT_KCB) và HAI mã hồ sơ bệnh án cùng type.coding.code='MR' nhưng khác system
-- (ma-hsba = "Mã hồ sơ bệnh án", so-luu-tru = "Số lưu trữ hồ sơ bệnh án") - nếu chọn
-- đại diện theo code sẽ dễ ăn nhầm giá trị; để nguyên bridge thì consumer tự lọc theo
-- IdentifierSystem là chính xác nhất.
WITH ident_explode AS (
  SELECT
    E.id AS EncounterID,
    E.meta.lastUpdated AS EncounterLastUpdated,
    pos,
    ident
  FROM Encounter AS E
  LATERAL VIEW posexplode(E.identifier) AS pos, ident
)
SELECT
  concat(EncounterID, '-', CAST(pos AS STRING)) AS EncounterIdentifierID,
  EncounterID,
  pos AS IdentifierSequence,
  ident.use AS IdentifierUse,
  try_element_at(ident.type.coding, 1).code AS IdentifierTypeCode,
  ident.type.text AS IdentifierTypeText,
  ident.system AS IdentifierSystem,
  ident.value AS IdentifierValue,
  to_timestamp(EncounterLastUpdated) AS SourceLastUpdated
FROM ident_explode
;
