CREATE TABLE IF NOT EXISTS Dim_PractitionerRole
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Dim_PractitionerRole"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM PractitionerRole_dim_view
;
