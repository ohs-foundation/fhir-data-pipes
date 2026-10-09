INSERT OVERWRITE TABLE Dim_Condition
SELECT * FROM Condition_dim_view
;
