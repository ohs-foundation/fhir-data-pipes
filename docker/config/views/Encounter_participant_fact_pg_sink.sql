CREATE TABLE IF NOT EXISTS Fact_Encounter_Participant
USING org.apache.spark.sql.jdbc
OPTIONS (
  url 'jdbc:postgresql://fhir-views-db:5432/views',
  dbtable '"Fact_Encounter_Participant"',
  user 'admin',
  password 'admin',
  driver 'org.postgresql.Driver'
)
AS SELECT * FROM Encounter_participant_fact_view
;
