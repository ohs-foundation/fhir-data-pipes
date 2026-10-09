CREATE OR REPLACE VIEW Patient_dim_view AS
-- Grain: 1 row = 1 Patient.
-- Schema mirrors Dim_Patient in FHIR_DWH_TEST (mock DWH): same column names and order,
-- with native types (Boolean/Int/Date/Timestamp) instead of casting everything to TEXT.
-- List-valued fields (name/identifier/address/telecom/communication) are reduced to a
-- single representative value: name -> use='official' else first; identifier -> MRN else
-- first; address -> use='home' else first; telecom -> first phone/email;
-- communication -> preferred=true else first.
-- DateOfBirth is intentionally truncated to year-only (e.g. "1982") to de-identify real
-- patient data; this is a permanent privacy rule, not a data quality gap. Age/AgeGroup are
-- still computed from the full birthDate so they stay accurate.
WITH picked AS (
  SELECT P.*,
    COALESCE(try_element_at(filter(P.name, n -> n.use = 'official'), 1), try_element_at(P.name, 1)) AS pn,
    COALESCE(
      try_element_at(filter(P.identifier, i -> try_element_at(i.type.coding, 1).code = 'MRN'), 1),
      try_element_at(P.identifier, 1)
    ) AS pid,
    COALESCE(try_element_at(filter(P.address, a -> a.use = 'home'), 1), try_element_at(P.address, 1)) AS pa,
    COALESCE(try_element_at(filter(P.communication, c -> c.preferred = true), 1), try_element_at(P.communication, 1)) AS pcm
  FROM Patient AS P
)
SELECT
  id AS PatientID,
  pid.value AS IdentifierValue,
  active AS ActiveFlag,
  COALESCE(pn.text, concat_ws(' ', concat_ws(' ', pn.given), pn.family)) AS PatientName,
  gender AS Gender,
  YEAR(birthDate) AS DateOfBirth,
  YEAR(current_date()) - YEAR(birthDate) AS Age,
  CASE
    WHEN birthDate IS NULL THEN NULL
    WHEN YEAR(current_date()) - YEAR(birthDate) < 18 THEN '0-17'
    WHEN YEAR(current_date()) - YEAR(birthDate) < 35 THEN '18-34'
    WHEN YEAR(current_date()) - YEAR(birthDate) < 50 THEN '35-49'
    WHEN YEAR(current_date()) - YEAR(birthDate) < 65 THEN '50-64'
    ELSE '65+'
  END AS AgeGroup,
  CASE
    WHEN deceased.Boolean OR deceased.dateTime IS NOT NULL THEN true
    WHEN NOT deceased.Boolean THEN false
  END AS DeceasedFlag,
  to_date(deceased.dateTime) AS DeceasedDate,
  try_element_at(filter(telecom, t -> t.system = 'phone'), 1).value AS Phone,
  try_element_at(filter(telecom, t -> t.system = 'email'), 1).value AS Email,
  pa.city AS City,
  pa.state AS Province,
  pa.country AS Country,
  try_element_at(pcm.language.coding, 1).code AS LanguageCode,
  managingOrganization.organizationId AS ManagingOrganizationID,
  to_timestamp(meta.lastUpdated) AS SourceLastUpdated
FROM picked
;
