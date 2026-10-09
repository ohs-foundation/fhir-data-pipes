INSERT OVERWRITE TABLE Fact_QuestionnaireResponse
SELECT * FROM QuestionnaireResponse_fact_view
;
