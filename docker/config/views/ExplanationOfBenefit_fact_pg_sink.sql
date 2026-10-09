CREATE TABLE IF NOT EXISTS Fact_ExplanationOfBenefit
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_ExplanationOfBenefit"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM ExplanationOfBenefit_fact_view
;
