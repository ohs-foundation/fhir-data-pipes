CREATE TABLE IF NOT EXISTS Dim_Practitioner
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Dim_Practitioner"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM Practitioner_dim_view
;
