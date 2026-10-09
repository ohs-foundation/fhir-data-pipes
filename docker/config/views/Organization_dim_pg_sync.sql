INSERT OVERWRITE TABLE Dim_Organization
SELECT * FROM Organization_dim_view
;
