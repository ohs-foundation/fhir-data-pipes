CREATE OR REPLACE VIEW Claim_fact_view AS
-- Grain: 1 row = 1 Claim item (item exploded; Claim-level fields repeated per item row).
-- Schema mirrors Fact_Claim in FHIR_DWH_TEST (mock DWH): same column names and order,
-- with native types (Int/Double/Timestamp) instead of casting everything to TEXT.
-- Primary insurance = focal line, else first. ChargeItemDefinitionID needs a mapping from
-- productOrService to ChargeItemDefinition; kept NULL.
-- MedicationAmount..OtherFundingAmount, SettlementYear/Month (thêm ở cuối, không chen vào
-- giữa để không phá thứ tự cột đã khớp Fact_Claim) lấy từ Claim.extension
-- (vn-ext-claim-cost-summary, vn-ext-claim-payment-period). `extension` không tồn tại
-- trong bảng Claim mà Bunsen sinh (cùng lý do đã giải thích ở Encounter_fact.sql).
-- [THỬ NGHIỆM] Đọc qua ViewDefinition (SQL-on-FHIR v2, FHIRPath) thay vì Bunsen:
-- config/views/claim_extension_view.json chạy FHIRPath extension(...) thẳng trên
-- resource Claim gốc, pipeline-controller tự đăng ký kết quả thành Hive/Spark view
-- `default.claim_extension`. Thay cho việc đọc claim_raw.ndjson do service nền
-- extension-source-refresh tải về - service đó tạm thời vẫn giữ nguyên (chưa xoá)
-- cho tới khi xác nhận cách mới này chạy đúng qua 1 lần pipeline thật.
-- Các field này là mức Claim (không phải mức item) nên lặp lại trên mọi dòng item của
-- cùng 1 claim, giống cách ClaimTotalAmount đã lặp lại hiện có.
WITH claim_ext_values AS (
  SELECT
    id AS ClaimID,
    MedicationAmount,
    MedicalSupplyAmount,
    -- InsuranceBenefitAmount = totalInsurance: số tiền BHYT thực trả (tên extension
    -- "totalInsurance" nhưng ngữ nghĩa là phần bảo hiểm chi trả/benefit).
    InsuranceBenefitAmount,
    PatientCopayAmount,
    PatientSelfPayAmount,
    OtherFundingAmount,
    SettlementYear,
    SettlementMonth
  FROM claim_extension
)

SELECT
  concat(C.id, '-', COALESCE(CAST(it.sequence AS STRING), '0')) AS ClaimItemID,
  C.id AS ClaimID,
  try_element_at(C.identifier, 1).value AS IdentifierValue,
  C.status AS ClaimStatus,
  COALESCE(try_element_at(C.type.coding, 1).display, C.type.text) AS ClaimTypeDisplay,
  C.use AS ClaimUse,
  C.patient.patientId AS PatientID,
  CAST(date_format(to_timestamp(C.created), 'yyyyMMdd') AS INT) AS CreatedDateKey,
  to_timestamp(C.created) AS CreatedDateTime,
  CASE
    WHEN C.provider.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN C.provider.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN C.provider.organizationId IS NOT NULL THEN 'Organization'
  END AS ProviderReferenceType,
  C.provider.organizationId AS ProviderOrganizationID,
  C.insurer.organizationId AS InsurerID,
  COALESCE(
    try_element_at(filter(C.insurance, i -> i.focal = true), 1).sequence,
    try_element_at(C.insurance, 1).sequence
  ) AS InsuranceSequence,
  COALESCE(
    try_element_at(filter(C.insurance, i -> i.focal = true), 1).coverage.coverageId,
    try_element_at(C.insurance, 1).coverage.coverageId
  ) AS CoverageID,
  it.sequence AS ItemSequence,
  try_element_at(it.encounter, 1).encounterId AS EncounterID,
  CAST(date_format(to_timestamp(COALESCE(it.serviced.date, it.serviced.period.start)), 'yyyyMMdd') AS INT) AS ServiceDateKey,
  to_timestamp(COALESCE(it.serviced.date, it.serviced.period.start)) AS ServiceStartDateTime,
  it.location.reference.locationId AS LocationID,
  COALESCE(try_element_at(it.category.coding, 1).display, it.category.text) AS CategoryDisplay,
  try_element_at(it.productOrService.coding, 1).code AS ProductOrServiceCode,
  COALESCE(try_element_at(it.productOrService.coding, 1).display, it.productOrService.text) AS ProductOrServiceDisplay,
  CAST(NULL AS STRING) AS ChargeItemDefinitionID,
  it.quantity.value AS Quantity,
  it.quantity.unit AS QuantityUnit,
  it.unitPrice.value AS UnitPrice,
  COALESCE(it.unitPrice.currency, it.net.currency) AS Currency,
  it.net.value AS GrossAmount,
  C.total.value AS ClaimTotalAmount,
  to_timestamp(C.meta.lastUpdated) AS SourceLastUpdated,
  cev.MedicationAmount,
  cev.MedicalSupplyAmount,
  cev.InsuranceBenefitAmount,
  cev.PatientCopayAmount,
  cev.PatientSelfPayAmount,
  cev.OtherFundingAmount,
  cev.SettlementYear,
  cev.SettlementMonth
FROM Claim AS C
  LEFT JOIN claim_ext_values cev ON cev.ClaimID = C.id
  LATERAL VIEW OUTER explode(C.item) AS it
;
