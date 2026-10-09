INSERT OVERWRITE TABLE Dim_Medication
SELECT * FROM Medication_dim_view
;
