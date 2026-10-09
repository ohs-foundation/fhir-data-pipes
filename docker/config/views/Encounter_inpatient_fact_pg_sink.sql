CREATE TABLE IF NOT EXISTS Fact_Encounter_Inpatient
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_Encounter_Inpatient"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM Encounter_inpatient_fact_view
;
