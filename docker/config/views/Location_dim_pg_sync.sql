INSERT OVERWRITE TABLE Dim_Location
SELECT * FROM Location_dim_view
;
