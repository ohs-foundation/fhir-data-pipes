INSERT OVERWRITE TABLE Fact_Encounter_Diagnosis
SELECT * FROM Encounter_diagnosis_fact_view
;