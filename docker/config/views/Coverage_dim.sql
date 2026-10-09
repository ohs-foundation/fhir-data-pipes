CREATE OR REPLACE VIEW Coverage_dim_view AS
-- Grain: 1 row = 1 Coverage (thẻ/hợp đồng bảo hiểm của bệnh nhân).
-- List-valued fields (identifier/payor/class) reduced to a single representative value.
-- Dùng CoverageID để Fact_Claim / Fact_ExplanationOfBenefit / Fact_MedicationRequest join vào.
-- PrimaryCareFacilityCode (nơi đăng ký KCB ban đầu theo BHYT) lấy từ
-- Coverage.extension(vn-ext-primary-care-facility). `extension` không tồn tại trong bảng
-- Coverage mà Bunsen sinh (cùng lý do đã giải thích ở Encounter_fact.sql).
-- [THỬ NGHIỆM] Đọc qua ViewDefinition (SQL-on-FHIR v2, FHIRPath) thay vì Bunsen:
-- config/views/coverage_extension_view.json chạy FHIRPath extension(...) thẳng trên
-- resource Coverage gốc, pipeline-controller tự đăng ký kết quả thành Hive/Spark view
-- `default.coverage_extension`. Thay cho việc đọc coverage_raw.ndjson do service nền
-- extension-source-refresh tải về - service đó tạm thời vẫn giữ nguyên (chưa xoá) cho
-- tới khi xác nhận cách mới này chạy đúng qua 1 lần pipeline thật.
WITH picked AS (
  SELECT C.*,
    try_element_at(C.identifier, 1) AS cid,
    try_element_at(C.payor, 1) AS cpayor,
    try_element_at(C.class, 1) AS cclass
  FROM Coverage AS C
),

coverage_ext_values AS (
  SELECT
    id AS CoverageID,
    PrimaryCareFacilityCode
  FROM coverage_extension
)

SELECT
  id AS CoverageID,
  cid.value AS IdentifierValue,
  cid.system AS IdentifierSystem,
  status AS CoverageStatus,
  try_element_at(type.coding, 1).code AS CoverageTypeCode,
  try_element_at(type.coding, 1).system AS CoverageTypeSystem,
  COALESCE(try_element_at(type.coding, 1).display, type.text) AS CoverageTypeDisplay,
  policyHolder.patientId AS PolicyHolderPatientID,
  policyHolder.organizationId AS PolicyHolderOrganizationID,
  subscriber.patientId AS SubscriberPatientID,
  subscriberId AS SubscriberID,
  beneficiary.patientId AS BeneficiaryPatientID,
  dependent AS Dependent,
  try_element_at(relationship.coding, 1).code AS RelationshipCode,
  COALESCE(try_element_at(relationship.coding, 1).display, relationship.text) AS RelationshipDisplay,
  period.start AS PeriodStart,
  period.`end` AS PeriodEnd,
  cpayor.organizationId AS PayorOrganizationID,
  cpayor.patientId AS PayorPatientID,
  cpayor.relatedPersonId AS PayorRelatedPersonID,
  `order` AS CoverageOrder,
  network AS Network,
  subrogation AS SubrogationFlag,
  cclass.value AS ClassValue,
  cclass.name AS ClassName,
  try_element_at(cclass.type.coding, 1).code AS ClassTypeCode,
  COALESCE(try_element_at(cclass.type.coding, 1).display, cclass.type.text) AS ClassTypeDisplay,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated,
  cev.PrimaryCareFacilityCode
FROM picked
  LEFT JOIN coverage_ext_values cev ON cev.CoverageID = picked.id
;
