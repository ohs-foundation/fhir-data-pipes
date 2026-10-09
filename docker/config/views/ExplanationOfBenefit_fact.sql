CREATE OR REPLACE VIEW ExplanationOfBenefit_fact_view AS
-- Grain: 1 row = 1 EOB item (item exploded).
-- Schema mirrors Fact_ExplanationOfBenefit in FHIR_DWH_TEST (mock DWH): same column names
-- and order, with native types (Boolean/Int/Double/Timestamp) instead of casting
-- everything to TEXT.
-- Adjudication amounts are split by category code (eligible / benefit / copay / deductible).
-- PatientResponsibilityAmount = copay + deductible. DeniedAmount and
-- ChargeItemDefinitionID need business mappings; kept NULL.
-- ClaimID: EOB không có field `claim` (Reference tới Claim) trong data hiện tại nên
-- claim.claimId luôn NULL - xác nhận trên toàn bộ 15 EOB mẫu. EOB và Claim của cùng 1
-- lượt khám lại dùng CHUNG 1 giá trị identifier type='MA_LK' ("Mã liên kết hồ sơ
-- BHYT") - đây là khóa nghiệp vụ thật do chính nguồn sinh ra để nối 2 resource, không
-- phải suy đoán - nên dùng nó để join sang Claim lấy ClaimID thay vì để NULL.
-- InsurerDisplay (thêm ở cuối): insurer trên EOB chỉ có `.display` ("Bảo hiểm Xã hội
-- Việt Nam"), không có `.reference` -> InsurerID vẫn luôn NULL với data hiện tại,
-- thêm InsurerDisplay để không mất thông tin duy nhất đang có.
WITH exploded AS (
  SELECT E.*, it,
    try_element_at(filter(it.adjudication, a -> try_element_at(a.category.coding, 1).code = 'eligible'), 1).amount.value AS EligibleAmountRaw,
    try_element_at(filter(it.adjudication, a -> try_element_at(a.category.coding, 1).code = 'benefit'), 1).amount.value AS BenefitAmountRaw,
    try_element_at(filter(it.adjudication, a -> try_element_at(a.category.coding, 1).code = 'copay'), 1).amount.value AS CopayAmountRaw,
    try_element_at(filter(it.adjudication, a -> try_element_at(a.category.coding, 1).code = 'deductible'), 1).amount.value AS DeductibleAmountRaw,
    try_element_at(filter(E.identifier, i -> try_element_at(i.type.coding, 1).code = 'MA_LK'), 1).value AS MALKValue
  FROM ExplanationOfBenefit AS E
    LATERAL VIEW OUTER explode(E.item) AS it
),

claim_link AS (
  SELECT
    CL.id AS ClaimID,
    try_element_at(filter(CL.identifier, i -> try_element_at(i.type.coding, 1).code = 'MA_LK'), 1).value AS MALKValue
  FROM Claim AS CL
)
SELECT
  concat(id, '-', COALESCE(CAST(it.sequence AS STRING), '0')) AS EOBItemID,
  id AS ExplanationOfBenefitID,
  try_element_at(identifier, 1).value AS IdentifierValue,
  status AS EOBStatus,
  COALESCE(try_element_at(type.coding, 1).display, type.text) AS EOBTypeDisplay,
  use AS EOBUse,
  patient.patientId AS PatientID,
  CAST(date_format(to_timestamp(created), 'yyyyMMdd') AS INT) AS CreatedDateKey,
  to_timestamp(created) AS CreatedDateTime,
  insurer.organizationId AS InsurerID,
  CASE
    WHEN provider.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN provider.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN provider.organizationId IS NOT NULL THEN 'Organization'
  END AS ProviderReferenceType,
  provider.organizationId AS ProviderOrganizationID,
  COALESCE(claim.claimId, cl.ClaimID) AS ClaimID,
  outcome AS Outcome,
  payment.amount.value AS PaymentAmount,
  payment.amount.currency AS PaymentCurrency,
  payment.date AS PaymentDate,
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
  BenefitAmountRaw AS BenefitAmount,
  COALESCE(CopayAmountRaw, 0) + COALESCE(DeductibleAmountRaw, 0) AS PatientResponsibilityAmount,
  CAST(NULL AS DOUBLE) AS DeniedAmount,
  EligibleAmountRaw AS EligibleAmount,
  COALESCE(outcome = 'error', FALSE) AS IsDeniedFlag,
  COALESCE(CopayAmountRaw, 0) + COALESCE(DeductibleAmountRaw, 0) > 0 AS IsPatientPayFlag,
  COALESCE(payment.amount.value IS NOT NULL AND payment.amount.value > 0, FALSE) AS IsInsuranceBenefitFlag,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated,
  insurer.display AS InsurerDisplay
FROM exploded
  LEFT JOIN claim_link cl ON cl.MALKValue = exploded.MALKValue
;
