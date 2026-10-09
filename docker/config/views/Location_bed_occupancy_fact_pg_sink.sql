CREATE TABLE IF NOT EXISTS Fact_Bed_Occupancy
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_Bed_Occupancy"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM Bed_Occupancy_fact_view
;
