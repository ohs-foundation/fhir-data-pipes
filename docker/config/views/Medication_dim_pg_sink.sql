CREATE TABLE IF NOT EXISTS Dim_Medication
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Dim_Medication"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM Medication_dim_view
;
