INSERT OVERWRITE TABLE Fact_Encounter_Participant
SELECT * FROM Encounter_participant_fact_view
;