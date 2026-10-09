INSERT OVERWRITE TABLE Dim_Patient
SELECT * FROM Patient_dim_view
;
