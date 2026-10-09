INSERT OVERWRITE TABLE Fact_DocumentReference
SELECT * FROM DocumentReference_fact_view
;
