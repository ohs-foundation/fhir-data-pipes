INSERT OVERWRITE TABLE Fact_MedicationRequest
SELECT * FROM MedicationRequest_fact_view
;
