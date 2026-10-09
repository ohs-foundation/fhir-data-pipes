CREATE OR REPLACE VIEW Encounter_reason_fact_view AS
-- Grain: 1 row = 1 MÃ/lý do tách được từ 1 phần tử Encounter.reasonCode[] - KHÔNG còn là
-- 1:1 với reasonCode[] nữa (xem lý do bên dưới), đây là thay đổi có chủ đích.
-- rc.coding trên data thật LUÔN rỗng - reasonCode chỉ dùng text tự do, đôi khi nhồi nhiều
-- mã ICD-10 nối nhau bởi ';' dạng "MÃ - mô tả" (vd "N39.0 - Nhiễm khuẩn đường tiết niệu...;
-- N30.0 - Viêm bàng quang cấp"), đôi khi chỉ là câu tự nhiên không có mã (vd "đau bụng").
-- Tách rc.text theo ';' thành từng đoạn (seg_pos); đoạn nào khớp mẫu "MÃ - mô tả"
-- (regex ^[A-Z][0-9]{2}(\.[0-9]+)?\s*-\s*.+$, đúng dạng ICD-10 quan sát được trên data
-- thật) thì tách ReasonCode/phần mô tả, đoạn thuần câu tự nhiên thì giữ nguyên làm
-- ReasonDisplay, ReasonCode NULL. Việc tách làm nổ số dòng có chủ đích (1 reasonCode chứa
-- 3 mã -> 3 dòng).
-- Tối ưu: sau khi tách được mã, JOIN ICD10_codesystem_view (đọc thẳng CodeSystem
-- vn-icd10-cs, xem CodeSystem_icd10_view.sql) lấy display CHUẨN từ terminology thay vì tin
-- hoàn toàn mô tả tự do sau dấu "-" (dễ lệch chính tả/viết tắt do nhập tay) - chỉ fallback
-- về mô tả tự do khi mã không khớp được với terminology (vd mã gõ sai/không phải ICD-10).
WITH reason_explode AS (
  SELECT
    E.id AS EncounterID,
    E.meta.lastUpdated AS EncounterLastUpdated,
    pos,
    rc
  FROM Encounter AS E
  LATERAL VIEW posexplode(E.reasonCode) AS pos, rc
),
reason_segments AS (
  SELECT
    EncounterID,
    EncounterLastUpdated,
    pos,
    rc,
    seg_pos,
    trim(seg_text) AS SegmentText
  FROM reason_explode
    LATERAL VIEW OUTER posexplode(split(rc.text, '\\s*;\\s*')) AS seg_pos, seg_text
),
reason_parsed AS (
  SELECT
    EncounterID,
    EncounterLastUpdated,
    pos,
    rc,
    seg_pos,
    SegmentText,
    CASE WHEN SegmentText RLIKE '^[A-Z][0-9]{2}(\\.[0-9]+)?\\s*-\\s*.+$'
      THEN regexp_extract(SegmentText, '^([A-Z][0-9]{2}(?:\\.[0-9]+)?)\\s*-\\s*(.+)$', 1)
    END AS ParsedCode,
    CASE WHEN SegmentText RLIKE '^[A-Z][0-9]{2}(\\.[0-9]+)?\\s*-\\s*.+$'
      THEN regexp_extract(SegmentText, '^([A-Z][0-9]{2}(?:\\.[0-9]+)?)\\s*-\\s*(.+)$', 2)
    END AS ParsedText
  FROM reason_segments
)
SELECT
  concat(rp.EncounterID, '-', CAST(rp.pos AS STRING), '-', CAST(rp.seg_pos AS STRING)) AS EncounterReasonID,
  rp.EncounterID,
  rp.pos AS ReasonSequence,
  CASE WHEN rp.ParsedCode IS NOT NULL THEN 'http://fhir.hl7.org.vn/core/CodeSystem/vn-icd10-cs' END AS ReasonCodeSystem,
  rp.ParsedCode AS ReasonCode,
  COALESCE(D10.DisplayVi, rp.ParsedText, rp.SegmentText) AS ReasonDisplay,
  rp.rc.text AS ReasonText,
  to_timestamp(rp.EncounterLastUpdated) AS SourceLastUpdated
FROM reason_parsed rp
  LEFT JOIN ICD10_codesystem_view D10 ON D10.Code = rp.ParsedCode
;
