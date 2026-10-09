INSERT OVERWRITE TABLE Fact_Observation
SELECT * FROM Observation_fact_view
;
