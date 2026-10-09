CREATE OR REPLACE VIEW Encounter_fact_view AS
-- Grain: 1 row = 1 Encounter. KHÔNG nổ số dòng: mọi field 1-nhiều (diagnosis[],
-- reasonCode[], identifier[]) được đẩy ra các bảng "bridge" riêng thay vì nối chuỗi/
-- chọn đại diện ngay trên Fact_Encounter - xem:
--   Encounter_diagnosis_fact.sql  (Fact_Encounter_Diagnosis - nối Dim_Condition)
--   Encounter_reason_fact.sql     (Fact_Encounter_Reason)
--   Encounter_identifier_fact.sql (Fact_Encounter_Identifier)
-- Tiền/bảo hiểm (MedicationAmount, HospitalTotalAmount, InsuranceEligibleTotalAmount...)
-- và các field thuộc Claim/ExplanationOfBenefit/Coverage KHÔNG đưa vào đây nữa - các
-- resource đó đã có Fact_Claim (Claim_fact.sql), Fact_ExplanationOfBenefit
-- (ExplanationOfBenefit_fact.sql), Dim_Coverage (Coverage_dim.sql) riêng, join được
-- sang Fact_Encounter qua EncounterID/PatientID sẵn có trên các bảng đó - không nhân
-- bản logic. Mọi cột dưới đây lấy trực tiếp từ field thật trên resource Encounter
-- (không tự sinh/nối chuỗi thêm).
WITH base AS (
  SELECT
    E.id AS EncounterID,
    E.subject.patientId AS PatientID,
    E.status AS EncounterStatus,

    try_element_at(
      filter(try_element_at(E.type, 1).coding, C -> C.system = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-encounter-type-cs'),
      1
    ).code AS EncounterClassCode,
    try_element_at(
      filter(try_element_at(E.type, 1).coding, C -> C.system = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-encounter-type-cs'),
      1
    ).display AS EncounterClassDisplay,

    try_element_at(
      filter(E.hospitalization.dischargeDisposition.coding, C -> C.system = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-discharge-disposition-cs'),
      1
    ).code AS DischargeDispositionCode,
    try_element_at(
      filter(E.hospitalization.dischargeDisposition.coding, C -> C.system = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-discharge-disposition-cs'),
      1
    ).display AS DischargeDispositionDisplay,

    to_timestamp(E.period.start) AS EncounterStartDateTime,
    to_date(E.period.start) AS EncounterStartDate,
    to_timestamp(E.period.end) AS EncounterEndDateTime,
    to_date(E.period.end) AS EncounterEndDate,
    CASE WHEN E.class.code = 'IMP' THEN to_timestamp(E.period.start) END AS InpatientAdmitDateTime,
    CASE WHEN E.class.code = 'IMP' THEN to_date(E.period.start) END AS InpatientAdmitDate,
    datediff(to_timestamp(E.period.end), to_timestamp(E.period.start)) AS LengthOfStayDays,

    -- DepartmentCodes: Encounter.serviceType.text trên nguồn đã là chuỗi mã khoa/phòng
    -- nối nhau bằng ';' sẵn (vd "K0102;K01;K03") - lấy nguyên văn, không tự nối thêm.
    E.serviceType.text AS DepartmentCodes,

    -- ReferralFromFacilityCode: Encounter.hospitalization.origin = nơi bệnh nhân được
    -- chuyển đến từ đó trước khi nhập viện/khám (đúng ngữ nghĩa FHIR "origin"), field
    -- đơn (0..1) nên lấy thẳng, không phải nối/chọn từ mảng.
    E.hospitalization.origin.identifier.value AS ReferralFromFacilityCode,

    E.class.code = 'IMP' AS IsInpatientFlag,
    E.class.code = 'EMER' AS IsEmergencyFlag,
    E.serviceProvider.organizationId AS ServiceProviderOrganizationID,
    to_timestamp(E.meta.lastUpdated) AS SourceLastUpdated
  FROM Encounter AS E
),

-- PatientCategoryCode/Display (vn-ext-insurance-visit-type) và
-- TreatmentOutcomeCode/Name (vn-ext-treatment-outcome) nằm trong
-- Encounter.extension, nhưng cột `extension` không tồn tại trong bảng
-- Encounter mà pipeline Spark/Bunsen sinh ra (Bunsen loại field mở này khi
-- convert FHIR -> Parquet nếu không đăng ký custom profile qua
-- structureDefinitionsPath; và việc đăng ký profile vn-core-encounter lại
-- đụng giới hạn regex hard-code trong bunsen-core chỉ nhận URL dạng
-- http://hl7.org/fhir/...).
-- [THỬ NGHIỆM] Nên đọc qua ViewDefinition (SQL-on-FHIR v2, FHIRPath) thay vì
-- Bunsen: config/views/encounter_extension_view.json chạy FHIRPath
-- extension(...) thẳng trên resource Encounter gốc (ViewApplicator, không qua
-- Bunsen nên không bị giới hạn trên), pipeline-controller tự đăng ký kết quả
-- thành Hive/Spark view `default.encounter_extension`. Cách này thay cho
-- việc đọc /dwh/extension-source/encounter_raw.ndjson do service nền
-- extension-source-refresh (docker/extension-source-refresh) tải về - service
-- đó tạm thời vẫn giữ nguyên (chưa xoá) cho tới khi xác nhận cách mới này
-- chạy đúng qua 1 lần pipeline thật.
-- Đây vẫn là field thật trên Encounter (2 giá trị đơn, không phải mảng 1-nhiều) - chỉ
-- là đường đọc khác do giới hạn kỹ thuật của Bunsen, không phải cột tự sinh.
ext_values AS (
  SELECT
    id AS EncounterID,
    PatientCategoryCode,
    PatientCategoryDisplay,
    TreatmentOutcomeCode,
    TreatmentOutcomeName
  FROM encounter_extension
)

SELECT
  b.EncounterID,
  b.PatientID,
  b.EncounterStatus,
  b.EncounterClassCode,
  b.EncounterClassDisplay,
  b.EncounterStartDateTime,
  b.EncounterStartDate,
  b.EncounterEndDateTime,
  b.EncounterEndDate,
  b.InpatientAdmitDateTime,
  b.InpatientAdmitDate,
  b.LengthOfStayDays,
  b.DepartmentCodes,
  b.ReferralFromFacilityCode,
  b.DischargeDispositionCode,
  b.DischargeDispositionDisplay,
  ext.TreatmentOutcomeCode,
  ext.TreatmentOutcomeName,
  ext.PatientCategoryCode,
  ext.PatientCategoryDisplay,
  b.IsInpatientFlag,
  b.IsEmergencyFlag,
  b.ServiceProviderOrganizationID,
  b.SourceLastUpdated
FROM base b
LEFT JOIN ext_values ext ON ext.EncounterID = b.EncounterID
;
