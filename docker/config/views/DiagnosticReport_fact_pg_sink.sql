CREATE TABLE IF NOT EXISTS Fact_DiagnosticReport
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_DiagnosticReport"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM DiagnosticReport_fact_view
;
