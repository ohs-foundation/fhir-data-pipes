INSERT OVERWRITE TABLE Fact_Encounter_Identifier
SELECT * FROM Encounter_identifier_fact_view
;
