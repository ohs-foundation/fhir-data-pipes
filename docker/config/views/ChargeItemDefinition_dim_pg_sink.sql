CREATE TABLE IF NOT EXISTS Dim_ChargeItemDefinition
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Dim_ChargeItemDefinition"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM ChargeItemDefinition_dim_view
;
