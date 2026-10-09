INSERT OVERWRITE TABLE Fact_DiagnosticReport
SELECT * FROM DiagnosticReport_fact_view
;
