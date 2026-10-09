CREATE OR REPLACE VIEW DocumentReference_fact_view AS
-- Grain: 1 row = 1 DocumentReference. identifier/author/content arrays reduced to their
-- first element to keep a single row.
-- CHƯA có schema Fact_DocumentReference xác nhận từ FHIR_DWH_TEST (mock DWH) - tự thiết
-- kế theo field thật trên DocumentReference (đã xác nhận qua curl mẫu thật: 1 bản ghi
-- discharge-summary có identifier/type/subject/date/author/description/content/
-- context.encounter), cùng convention với ServiceRequest_fact.sql/Procedure_fact.sql.
-- Cần đối chiếu lại tên/thứ tự cột với mock DWH nếu có.
WITH picked AS (
  SELECT D.*,
    try_element_at(D.identifier, 1) AS did,
    try_element_at(D.author, 1) AS dauthor,
    try_element_at(D.content, 1) AS dcontent
  FROM DocumentReference AS D
)
SELECT
  id AS DocumentReferenceID,
  did.value AS IdentifierValue,
  status AS DocumentReferenceStatus,
  try_element_at(type.coding, 1).code AS TypeCode,
  COALESCE(try_element_at(type.coding, 1).display, type.text) AS TypeDisplay,
  subject.patientId AS PatientID,
  try_element_at(context.encounter, 1).encounterId AS EncounterID,
  to_timestamp(date) AS DocumentDateTime,
  CASE
    WHEN dauthor.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN dauthor.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN dauthor.organizationId IS NOT NULL THEN 'Organization'
    WHEN dauthor.patientId IS NOT NULL THEN 'Patient'
  END AS AuthorReferenceType,
  COALESCE(dauthor.practitionerId, dauthor.practitionerRoleId, dauthor.organizationId, dauthor.patientId) AS AuthorID,
  description AS DescriptionText,
  dcontent.attachment.contentType AS ContentType,
  dcontent.attachment.title AS ContentTitle,
  dcontent.attachment.language AS ContentLanguage,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
