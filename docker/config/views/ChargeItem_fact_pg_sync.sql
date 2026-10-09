INSERT OVERWRITE TABLE Fact_ChargeItem
SELECT * FROM ChargeItem_fact_view
;
