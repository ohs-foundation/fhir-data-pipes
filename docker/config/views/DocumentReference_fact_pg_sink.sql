CREATE TABLE IF NOT EXISTS Fact_DocumentReference
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_DocumentReference"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM DocumentReference_fact_view
;
