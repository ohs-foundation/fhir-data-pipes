INSERT OVERWRITE TABLE Fact_Encounter_Reason
SELECT * FROM Encounter_reason_fact_view
;
