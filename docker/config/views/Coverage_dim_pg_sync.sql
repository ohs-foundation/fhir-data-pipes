INSERT OVERWRITE TABLE Dim_Coverage
SELECT * FROM Coverage_dim_view
;
