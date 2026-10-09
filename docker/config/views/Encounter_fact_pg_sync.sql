INSERT OVERWRITE TABLE Fact_Encounter
SELECT * FROM Encounter_fact_view
;