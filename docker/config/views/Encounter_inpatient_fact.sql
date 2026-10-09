CREATE OR REPLACE VIEW Encounter_inpatient_fact_view AS
-- Grain: 1 row = 1 inpatient Encounter (class = 'IMP').
-- Schema mirrors Fact_Encounter_Inpatient in FHIR_DWH_TEST (mock DWH): same column names
-- and order, with native types (Boolean/Int/Date/Timestamp) instead of casting everything
-- to TEXT.
WITH inpatient AS (
  SELECT
    E.id AS EncounterID,
    E.subject.patientId AS PatientID,
    E.status AS EncounterStatus,
    -- EncounterClassCode/Display: lấy từ Encounter.type[] lọc theo hệ mã VN
    -- (vn-encounter-type-cs), GIỐNG Fact_Encounter - không lấy Encounter.class như
    -- bản trước, vì bảng này chỉ chứa Encounter class='IMP' (đã lọc ở WHERE bên
    -- dưới) nên nếu lấy từ class thì cột này luôn là hằng số 'IMP', không có thông
    -- tin gì thêm.
    try_element_at(
      filter(try_element_at(E.type, 1).coding, C -> C.system = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-encounter-type-cs'),
      1
    ).code AS EncounterClassCode,
    try_element_at(
      filter(try_element_at(E.type, 1).coding, C -> C.system = 'http://fhir.hl7.org.vn/core/CodeSystem/vn-encounter-type-cs'),
      1
    ).display AS EncounterClassDisplay,
    E.serviceProvider.organizationId AS ServiceProviderOrganizationID,
    -- PrimaryBedID: field đúng là Encounter.location[].location - trên data thật đây
    -- là Location cấp Khoa/Phòng (physicalType='wa' = Ward, vd "Khoa Nội tổng hợp"),
    -- KHÔNG phải giường bệnh cụ thể dù tên cột là "Bed". Giữ tên cột theo đúng schema
    -- Fact_Encounter_Inpatient gốc, nhưng lưu ý khi dùng: giá trị hiện tại là ID cấp
    -- Khoa/Phòng, không phải ID giường.
    try_element_at(E.location, 1).location.locationId AS PrimaryBedID,
    to_timestamp(E.period.start) AS InpatientAdmitDate,
    to_timestamp(E.period.end) AS DischargeDateTime,
    try_element_at(E.hospitalization.admitSource.coding, 1).code AS AdmitSourceCode,
    COALESCE(try_element_at(E.hospitalization.admitSource.coding, 1).display, E.hospitalization.admitSource.text) AS AdmitSourceDisplay,
    COALESCE(try_element_at(E.hospitalization.dischargeDisposition.coding, 1).display, E.hospitalization.dischargeDisposition.text) AS DischargeDispositionDisplay,
    E.hospitalization.reAdmission IS NOT NULL AS IsReadmissionFlag,
    try_element_at(E.appointment, 1).appointmentId AS AppointmentID,
    to_timestamp(E.meta.lastUpdated) AS SourceLastUpdated
  FROM Encounter AS E
  WHERE E.class.code = 'IMP'
),
prev_discharge AS (
  SELECT EncounterID,
    LAG(DischargeDateTime) OVER (PARTITION BY PatientID ORDER BY InpatientAdmitDate) AS PreviousDischargeDate
  FROM inpatient
)
SELECT
  i.EncounterID AS InpatientEncounterID,
  i.EncounterID AS EncounterID,
  i.PatientID,
  i.EncounterStatus,
  i.EncounterClassCode,
  i.EncounterClassDisplay,
  i.ServiceProviderOrganizationID,
  i.PrimaryBedID,
  CAST(date_format(i.InpatientAdmitDate, 'yyyyMMdd') AS INT) AS AdmitDateKey,
  to_date(i.InpatientAdmitDate) AS AdmitDate,
  i.InpatientAdmitDate AS InpatientAdmitDate,
  CAST(date_format(i.DischargeDateTime, 'yyyyMMdd') AS INT) AS DischargeDateKey,
  to_date(i.DischargeDateTime) AS DischargeDate,
  i.DischargeDateTime AS DischargeDateTime,
  datediff(i.DischargeDateTime, i.InpatientAdmitDate) AS LengthOfStayDays,
  i.AdmitSourceDisplay,
  i.DischargeDispositionDisplay,
  i.AppointmentID IS NOT NULL AS IsPlannedAdmissionFlag,
  COALESCE(i.AdmitSourceCode = 'emd', FALSE) AS IsEmergencyAdmissionFlag,
  i.DischargeDateTime IS NOT NULL AS IsDischargedFlag,
  COALESCE(i.DischargeDateTime IS NULL AND i.EncounterStatus = 'in-progress', FALSE) AS IsCurrentInpatientFlag,
  i.IsReadmissionFlag AS IsReadmissionFlag,
  COALESCE(pd.PreviousDischargeDate IS NOT NULL
        AND datediff(i.InpatientAdmitDate, pd.PreviousDischargeDate) BETWEEN 0 AND 30, FALSE) AS IsReadmission30dFlag,
  pd.PreviousDischargeDate AS PreviousDischargeDate,
  datediff(i.InpatientAdmitDate, pd.PreviousDischargeDate) AS DaysSincePreviousDischarge,
  i.SourceLastUpdated AS SourceLastUpdated
FROM inpatient AS i
  LEFT JOIN prev_discharge AS pd ON pd.EncounterID = i.EncounterID
;
