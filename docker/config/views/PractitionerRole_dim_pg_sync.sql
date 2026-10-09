INSERT OVERWRITE TABLE Dim_PractitionerRole
SELECT * FROM PractitionerRole_dim_view
;
