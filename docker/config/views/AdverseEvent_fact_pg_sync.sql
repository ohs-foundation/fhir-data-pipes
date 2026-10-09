INSERT OVERWRITE TABLE Fact_AdverseEvent
SELECT * FROM AdverseEvent_fact_view
;
