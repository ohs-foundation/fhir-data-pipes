INSERT OVERWRITE TABLE Fact_Encounter_Inpatient
SELECT * FROM Encounter_inpatient_fact_view
;