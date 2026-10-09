INSERT OVERWRITE TABLE Dim_Practitioner
SELECT * FROM Practitioner_dim_view
;
