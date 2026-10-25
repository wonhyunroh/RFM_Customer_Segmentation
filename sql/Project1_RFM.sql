-- Recency(R): 기준일(2026-06-30) 대비 마지막 거래일까지의 경과일 (정상 거래 is_modified='N' 기준)
USE salesdb;
SELECT customer_code AS `거래처`
       , MAX(txn_date) AS `마지막거래일`
       , DATEDIFF('2026-06-30', MAX(txn_date)) AS `R_경과일`
FROM sales
WHERE is_modified = 'N'
GROUP BY customer_code
ORDER BY `R_경과일`;

-- R 점수화: PERCENT_RANK로 경과일 순위 비율(0~1)을 구해 20% 단위로 5등급화 (경과일이 짧을수록 높은 점수)
USE salesdb;
WITH R AS (
    SELECT customer_code
         , DATEDIFF('2026-06-30', MAX(txn_date)) AS `경과일`
    FROM sales
    WHERE is_modified = 'N'
    GROUP BY customer_code
), P AS (
    SELECT customer_code
         , `경과일`
         , PERCENT_RANK() OVER (ORDER BY `경과일`) AS PR
    FROM R
)
SELECT customer_code AS `거래처`
     , `경과일`
     , CASE WHEN PR <= 0.2 THEN 5
            WHEN PR <= 0.4 THEN 4
            WHEN PR <= 0.6 THEN 3
            WHEN PR <= 0.8 THEN 2
            ELSE 1 END AS `R_점수`
FROM P
ORDER BY `R_점수` DESC, `경과일`;

-- Frequency(F): 거래처별 정상 거래 건수 (정정 전표 제외, is_modified='N')
USE salesdb;
SELECT customer_code AS `거래처`
       , COUNT(*) AS `F_거래건수`
FROM sales
WHERE is_modified = 'N'
GROUP BY customer_code
ORDER BY `F_거래건수` DESC;

-- F 점수화: PERCENT_RANK로 거래 건수 순위 비율을 구해 20% 단위로 5등급화 (건수가 많을수록 높은 점수)
USE salesdb;
WITH F AS (
    SELECT customer_code
         , COUNT(*) AS `거래건수`
    FROM sales
    WHERE is_modified = 'N'
    GROUP BY customer_code
), P AS (
    SELECT customer_code
         , `거래건수`
         , PERCENT_RANK() OVER (ORDER BY `거래건수` DESC) AS PR
    FROM F
)
SELECT customer_code AS `거래처`
     , `거래건수`
     , CASE WHEN PR <= 0.2 THEN 5
            WHEN PR <= 0.4 THEN 4
            WHEN PR <= 0.6 THEN 3
            WHEN PR <= 0.8 THEN 2
            ELSE 1 END AS `F_점수`
FROM P
ORDER BY `F_점수` DESC, `거래건수` DESC;

-- Monetary(M): 거래처별 전체 순매출 (정정 반영, 전체 전표 합산)
USE salesdb;
SELECT customer_code AS `거래처`
     , SUM(total_amount) AS `매출`
FROM sales
GROUP BY customer_code
ORDER BY customer_code ASC;

-- M 점수화: PERCENT_RANK로 매출 순위 비율을 구해 20% 단위로 5등급화 (매출이 클수록 높은 점수)
USE salesdb;
WITH M AS (
    SELECT customer_code
         , SUM(total_amount) AS `매출`
    FROM sales
    GROUP BY customer_code
), P AS (
    SELECT customer_code
         , `매출`
         , PERCENT_RANK() OVER (ORDER BY `매출` DESC) AS PR
    FROM M
)
SELECT customer_code AS `거래처`
     , `매출`
     , CASE WHEN PR <= 0.2 THEN 5
            WHEN PR <= 0.4 THEN 4
            WHEN PR <= 0.6 THEN 3
            WHEN PR <= 0.8 THEN 2
            ELSE 1 END AS `M_점수`
FROM P
ORDER BY `M_점수` DESC, `매출` DESC;

-- RFM 통합 점수: R,F는 정상 거래(is_modified='N'), M은 전체 순매출 기준으로 한 번에 산출
USE salesdb;
WITH B AS (
    SELECT customer_code
         , DATEDIFF('2026-06-30', MAX(CASE WHEN is_modified = 'N' THEN txn_date END)) AS `경과일`
         , COUNT(CASE WHEN is_modified = 'N' THEN 1 END) AS `거래건수`
         , SUM(total_amount) AS `매출`
    FROM sales
    GROUP BY customer_code
), P AS (
    SELECT customer_code
         -- R: 경과일 짧은 순 / F: 건수 많은 순 / M: 매출 큰 순
         , PERCENT_RANK() OVER (ORDER BY `경과일`) AS PR_R
         , PERCENT_RANK() OVER (ORDER BY `거래건수` DESC) AS PR_F
         , PERCENT_RANK() OVER (ORDER BY `매출` DESC) AS PR_M
    FROM B
)
SELECT customer_code AS `거래처`
     , CASE WHEN PR_R <= 0.2 THEN 5 WHEN PR_R <= 0.4 THEN 4 WHEN PR_R <= 0.6 THEN 3 WHEN PR_R <= 0.8 THEN 2 ELSE 1 END AS `R_점수`
     , CASE WHEN PR_F <= 0.2 THEN 5 WHEN PR_F <= 0.4 THEN 4 WHEN PR_F <= 0.6 THEN 3 WHEN PR_F <= 0.8 THEN 2 ELSE 1 END AS `F_점수`
     , CASE WHEN PR_M <= 0.2 THEN 5 WHEN PR_M <= 0.4 THEN 4 WHEN PR_M <= 0.6 THEN 3 WHEN PR_M <= 0.8 THEN 2 ELSE 1 END AS `M_점수`
FROM P
ORDER BY `거래처`;
