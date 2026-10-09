CREATE TABLE IF NOT EXISTS Fact_MedicationRequest
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_MedicationRequest"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM MedicationRequest_fact_view
;
