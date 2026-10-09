CREATE OR REPLACE VIEW QuestionnaireResponse_item_fact_view AS
-- Grain: 1 row = 1 response - 1 (top-level) item - 1 answer.
-- Only top-level item + its direct answers are exploded here; nested item.item and
-- answer.item are NOT flattened in this phase (add a recursive pass later if needed).
-- NOTE ON answer.value[x] CASING: the flattened struct follows the same convention as
-- Observation.value[x] in this repo (String/Boolean/Integer capitalized; quantity/coding/
-- dateTime lowercase). Decimal/time are inferred (scalar primitive -> capital; date-ish ->
-- lowercase) and are not exercised elsewhere, so verify against the generated schema on the
-- first run if survey answers use those types.
SELECT
  concat_ws('-', Q.id, qi.linkId, CAST(ans_idx AS STRING)) AS QuestionnaireResponseItemID,
  Q.id AS QuestionnaireResponseID,
  Q.questionnaire AS QuestionnaireID,
  qi.linkId AS LinkID,
  qi.text AS QuestionText,
  ans_idx AS AnswerSequence,
  CASE
    WHEN qa.value.Boolean IS NOT NULL THEN 'Boolean'
    WHEN qa.value.Decimal IS NOT NULL THEN 'Decimal'
    WHEN qa.value.Integer IS NOT NULL THEN 'Integer'
    WHEN qa.value.date IS NOT NULL THEN 'Date'
    WHEN qa.value.dateTime IS NOT NULL THEN 'DateTime'
    WHEN qa.value.time IS NOT NULL THEN 'Time'
    WHEN qa.value.String IS NOT NULL THEN 'String'
    WHEN qa.value.coding IS NOT NULL THEN 'Coding'
    WHEN qa.value.quantity IS NOT NULL THEN 'Quantity'
    WHEN qa.value.reference IS NOT NULL THEN 'Reference'
  END AS AnswerType,
  qa.value.Integer AS AnswerInteger,
  qa.value.Decimal AS AnswerDecimal,
  qa.value.String AS AnswerString,
  qa.value.Boolean AS AnswerBoolean,
  qa.value.coding.code AS AnswerCodingCode,
  qa.value.coding.display AS AnswerCodingDisplay,
  qa.value.quantity.value AS AnswerQuantityValue,
  qa.value.quantity.unit AS AnswerQuantityUnit,
  to_timestamp(qa.value.dateTime) AS AnswerDateTime,
  CAST(NULL AS STRING) AS QuestionGroup,
  CAST(NULL AS STRING) AS ScoreCategory
FROM QuestionnaireResponse AS Q
  LATERAL VIEW OUTER explode(Q.item) AS qi
  LATERAL VIEW OUTER posexplode(qi.answer) AS ans_idx, qa
;
