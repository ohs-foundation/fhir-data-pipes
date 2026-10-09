CREATE TABLE IF NOT EXISTS Fact_ServiceRequest
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_ServiceRequest"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM ServiceRequest_fact_view
;
