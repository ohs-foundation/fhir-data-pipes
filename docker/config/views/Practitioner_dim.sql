CREATE OR REPLACE VIEW Practitioner_dim_view AS
-- Grain: 1 row = 1 Practitioner. List fields reduced to a single representative value.
-- Schema mirrors Dim_Practitioner in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Timestamp) instead of casting everything to TEXT.
-- pid: lấy identifier đầu tiên. Bản trước lọc theo type.coding.code='MRN' (copy từ
-- Patient_dim.sql) nhưng Practitioner.identifier trong data thật KHÔNG có field `type`
-- (chỉ có use/system/value, vd system=sid/ma-nvyt) nên filter đó không bao giờ khớp - bỏ
-- luôn cho khỏi gây hiểu lầm, mỗi Practitioner trong data hiện tại cũng chỉ có đúng 1
-- identifier nên kết quả không đổi.
WITH picked AS (
  SELECT P.*,
    COALESCE(try_element_at(filter(P.name, n -> n.use = 'official'), 1), try_element_at(P.name, 1)) AS pn,
    try_element_at(P.identifier, 1) AS pid,
    try_element_at(P.qualification, 1) AS pq
  FROM Practitioner AS P
)
SELECT
  id AS PractitionerID,
  pid.value AS IdentifierValue,
  active AS ActiveFlag,
  COALESCE(pn.text, concat_ws(' ', concat_ws(' ', pn.given), pn.family)) AS PractitionerName,
  gender AS Gender,
  try_element_at(pq.code.coding, 1).code AS QualificationCode,
  try_element_at(filter(telecom, t -> t.system = 'phone'), 1).value AS Phone,
  try_element_at(filter(telecom, t -> t.system = 'email'), 1).value AS Email,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
