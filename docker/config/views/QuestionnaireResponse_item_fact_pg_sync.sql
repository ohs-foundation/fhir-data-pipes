INSERT OVERWRITE TABLE Fact_QuestionnaireResponse_Item
SELECT * FROM QuestionnaireResponse_item_fact_view
;
