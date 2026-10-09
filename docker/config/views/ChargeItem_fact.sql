CREATE OR REPLACE VIEW ChargeItem_fact_view AS
-- Grain: 1 row = 1 ChargeItem. identifier / definitionCanonical / performer arrays are
-- reduced to their first element.
-- Schema mirrors Fact_ChargeItem in FHIR_DWH_TEST (mock DWH): same column names and order,
-- with native types (Boolean/Int/Double/Timestamp) instead of casting everything to TEXT.
-- CalculatedAmount is derived downstream and kept NULL here.
-- ChargeItemDefinitionID: KHÔNG lấy bằng cách tách chuỗi cuối cùng của definitionCanonical
-- (bản trước dùng regexp_extract) - đó là slug trong canonical URL (vd "ma-dich-vu-02.03"),
-- KHÔNG phải id thật của resource ChargeItemDefinition (vd "22803", xem
-- ChargeItemDefinition_dim.sql: id AS ChargeItemDefinitionID). Hai giá trị đó không cùng
-- không gian giá trị nên join giữa Fact_ChargeItem và Dim_ChargeItemDefinition qua
-- ChargeItemDefinitionID sẽ luôn ra 0 dòng nếu vẫn dùng slug. Sửa bằng cách join sang bảng
-- ChargeItemDefinition qua đúng cặp khóa nghiệp vụ: ChargeItemDefinition.url =
-- ChargeItem.definitionCanonical, rồi lấy id thật.
WITH picked AS (
  SELECT C.*,
    try_element_at(C.identifier, 1) AS cid,
    try_element_at(C.definitionCanonical, 1) AS cdefcanon
  FROM ChargeItem AS C
),
cid_link AS (
  SELECT
    id AS ChargeItemDefinitionID,
    url AS DefinitionUrl
  FROM ChargeItemDefinition
)
SELECT
  id AS ChargeItemID,
  cid.value AS IdentifierValue,
  status AS ChargeItemStatus,
  cdefcanon AS DefinitionCanonical,
  cidl.ChargeItemDefinitionID,
  try_element_at(code.coding, 1).code AS ChargeItemCode,
  COALESCE(try_element_at(code.coding, 1).display, code.text) AS ChargeItemDisplay,
  subject.patientId AS PatientID,
  context.encounterId AS EncounterID,
  CAST(date_format(to_timestamp(COALESCE(occurrence.dateTime, occurrence.period.start)), 'yyyyMMdd') AS INT) AS OccurrenceDateKey,
  to_timestamp(COALESCE(occurrence.dateTime, occurrence.period.start)) AS OccurrenceStartTime,
  CASE
    WHEN enterer.practitionerId IS NOT NULL THEN 'Practitioner'
    WHEN enterer.practitionerRoleId IS NOT NULL THEN 'PractitionerRole'
    WHEN enterer.organizationId IS NOT NULL THEN 'Organization'
    WHEN enterer.patientId IS NOT NULL THEN 'Patient'
    WHEN enterer.deviceId IS NOT NULL THEN 'Device'
  END AS EntererReferenceType,
  COALESCE(enterer.practitionerId, enterer.practitionerRoleId, enterer.organizationId,
           enterer.patientId, enterer.deviceId) AS EntererID,
  performingOrganization.organizationId AS PerformingOrganizationID,
  requestingOrganization.organizationId AS RequestingOrganizationID,
  costCenter.organizationId AS CostCenterID,
  quantity.value AS Quantity,
  quantity.unit AS QuantityUnit,
  priceOverride.value AS UnitPriceOverride,
  priceOverride.currency AS Currency,
  factorOverride AS FactorOverride,
  CAST(NULL AS DOUBLE) AS CalculatedAmount,
  COALESCE(status = 'billable', FALSE) AS IsBillableFlag,
  COALESCE(status = 'billed', FALSE) AS IsBilledFlag,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
  LEFT JOIN cid_link cidl ON cidl.DefinitionUrl = picked.cdefcanon
;
