CREATE TABLE IF NOT EXISTS Fact_AdverseEvent
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_AdverseEvent"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM AdverseEvent_fact_view
;
