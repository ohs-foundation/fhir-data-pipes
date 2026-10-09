INSERT OVERWRITE TABLE Fact_Claim
SELECT * FROM Claim_fact_view
;
