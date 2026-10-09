INSERT OVERWRITE TABLE Dim_ChargeItemDefinition
SELECT * FROM ChargeItemDefinition_dim_view
;
