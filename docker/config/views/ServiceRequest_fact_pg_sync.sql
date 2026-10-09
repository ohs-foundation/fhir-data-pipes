INSERT OVERWRITE TABLE Fact_ServiceRequest
SELECT * FROM ServiceRequest_fact_view
;
