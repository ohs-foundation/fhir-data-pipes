CREATE OR REPLACE VIEW Bed_Occupancy_fact_view AS
-- Grain: 1 row = 1 bed (Location physicalType = 'bd') x 1 day, INCLUDING vacant beds so that
-- OccupancyRate = SUM(OccupiedBedCount) / SUM(AvailableBedCount) can be computed downstream.
-- Schema mirrors Fact_Bed_Occupancy in FHIR_DWH_TEST (mock DWH): same column names and
-- order, with native types (Boolean/Int/Date/Timestamp) instead of casting everything to
-- TEXT.
-- Everything is derived from FHIR only:
--   * bed catalogue  <- all Location where physicalType.coding.code = 'bd'
--   * occupancy      <- Encounter.location segments (period) referencing those beds
--   * date spine     <- generated in-SQL from the occupancy date range (no Dim_Date table needed)
-- File is prefixed "Location_" on purpose: it reads both Encounter and Location, and the
-- controller runs a resource's views right after building that resource's table; naming it after
-- Location (which comes after Encounter in resourceList) guarantees both tables already exist.
WITH beds AS (
  SELECT
    L.id AS BedLocationID,
    L.name AS BedLocationDisplay,
    L.partOf.locationId AS ParentLocationID,
    L.managingOrganization.organizationId AS ManagingOrganizationID,
    L.status AS LocationStatus,
    COALESCE(L.operationalStatus.display, L.operationalStatus.code) AS LocationOperationalStatus,
    to_timestamp(L.meta.lastUpdated) AS SourceLocationLastUpdated
  FROM Location AS L
  WHERE try_element_at(L.physicalType.coding, 1).code = 'bd'
),
occ_segments AS (
  -- source HIS often leaves Encounter.location.period empty; fall back to the
  -- encounter's own period so occupancy can still be derived - nhưng CHỈ khi
  -- encounter đó có đúng 1 phần tử trong location[] (loc_count = 1). Nếu 1 encounter
  -- có nhiều location (chuyển giường trong cùng 1 encounter) mà không có period riêng
  -- cho từng giường, không có căn cứ để biết giường nào được dùng lúc nào - fallback
  -- nguyên period của encounter cho MỖI giường sẽ khiến ngày đó bị đếm là "đang có
  -- người" ở CẢ NHIỀU giường cùng lúc dù thực tế chỉ có 1 bệnh nhân, làm
  -- OccupiedBedCount bị đếm thừa. Data hiện tại chưa có encounter nào bị vậy (0/19),
  -- nhưng để không đếm sai khi phát sinh, chỉ fallback khi loc_count = 1; các dòng
  -- không xác định được period sẽ bị loại ở WHERE bên dưới (thà thiếu còn hơn đếm sai).
  SELECT
    E.id AS EncounterID,
    E.subject.patientId AS PatientID,
    E.class.code AS EncounterClassCode,
    E.serviceProvider.organizationId AS ServiceProviderOrganizationID,
    loc.location.locationId AS BedLocationID,
    to_timestamp(COALESCE(
      loc.period.start,
      CASE WHEN size(E.location) = 1 THEN E.period.start END
    )) AS LocationStartTime,
    to_timestamp(COALESCE(
      loc.period.`end`,
      CASE WHEN size(E.location) = 1 THEN E.period.`end` END
    )) AS LocationEndTime,
    to_timestamp(E.meta.lastUpdated) AS SourceEncounterLastUpdated
  FROM Encounter AS E
    LATERAL VIEW OUTER explode(E.location) locs AS loc
  WHERE loc.location.locationId IS NOT NULL
    AND COALESCE(
      loc.period.start,
      CASE WHEN size(E.location) = 1 THEN E.period.start END
    ) IS NOT NULL
),
bounds AS (
  SELECT
    to_date(min(LocationStartTime)) AS min_d,
    to_date(max(COALESCE(LocationEndTime, current_timestamp()))) AS max_d
  FROM occ_segments
),
spine AS (
  SELECT explode(sequence(min_d, max_d, interval 1 day)) AS SnapshotDate
  FROM bounds
),
occ_days AS (
  -- expand each occupancy segment to one row per calendar day it covers
  SELECT
    s.BedLocationID, s.EncounterID, s.PatientID, s.EncounterClassCode,
    s.ServiceProviderOrganizationID,
    s.LocationStartTime, s.LocationEndTime,
    s.SourceEncounterLastUpdated,
    d.SnapshotDate,
    row_number() OVER (
      PARTITION BY s.BedLocationID, d.SnapshotDate ORDER BY s.LocationStartTime DESC
    ) AS rn
  FROM occ_segments AS s
    LATERAL VIEW explode(
      sequence(to_date(s.LocationStartTime), to_date(COALESCE(s.LocationEndTime, current_timestamp())), interval 1 day)
    ) d AS SnapshotDate
),
occ_1 AS (
  -- keep 1 occupant per bed-day (latest admission wins on overlap/transfer noise)
  SELECT * FROM occ_days WHERE rn = 1
)
SELECT
  concat_ws('-', b.BedLocationID, date_format(sp.SnapshotDate, 'yyyyMMdd')) AS BedOccupancyID,
  CAST(date_format(sp.SnapshotDate, 'yyyyMMdd') AS INT) AS DateKey,
  sp.SnapshotDate AS SnapshotDate,
  b.BedLocationID AS BedLocationID,
  b.BedLocationDisplay AS BedLocationDisplay,
  b.ParentLocationID AS ParentLocationID,
  b.ManagingOrganizationID AS ManagingOrganizationID,
  o.EncounterID AS EncounterID,
  o.PatientID AS PatientID,
  o.EncounterClassCode AS EncounterClassCode,
  b.LocationStatus AS LocationStatus,
  b.LocationOperationalStatus AS LocationOperationalStatus,
  o.LocationStartTime AS LocationStartTime,
  o.LocationEndTime AS LocationEndTime,
  o.EncounterID IS NOT NULL AS IsOccupiedFlag,
  CASE WHEN o.EncounterID IS NOT NULL THEN 1 ELSE 0 END AS OccupiedBedCount,
  CASE WHEN b.LocationStatus = 'active' THEN 1 ELSE 0 END AS AvailableBedCount,
  COALESCE(b.LocationStatus = 'active', FALSE) AS IsActiveBedFlag,
  COALESCE(o.EncounterID IS NULL AND b.LocationStatus = 'active', FALSE) AS IsVacantFlag,
  o.ServiceProviderOrganizationID AS ServiceProviderOrganizationID,
  o.SourceEncounterLastUpdated AS SourceEncounterLastUpdated,
  b.SourceLocationLastUpdated AS SourceLocationLastUpdated
FROM beds AS b
  CROSS JOIN spine AS sp
  LEFT JOIN occ_1 AS o
    ON o.BedLocationID = b.BedLocationID
   AND o.SnapshotDate = sp.SnapshotDate
;
