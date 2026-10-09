CREATE TABLE IF NOT EXISTS Fact_QuestionnaireResponse_Item
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_QuestionnaireResponse_Item"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM QuestionnaireResponse_item_fact_view
;
