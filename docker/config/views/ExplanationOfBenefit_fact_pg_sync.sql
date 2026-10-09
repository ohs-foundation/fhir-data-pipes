INSERT OVERWRITE TABLE Fact_ExplanationOfBenefit
SELECT * FROM ExplanationOfBenefit_fact_view
;