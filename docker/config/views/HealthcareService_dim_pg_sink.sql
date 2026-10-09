CREATE TABLE IF NOT EXISTS Dim_HealthcareService
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Dim_HealthcareService"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM HealthcareService_dim_view
;
