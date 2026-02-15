Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Фролова Надежда Васильевна
 * Дата: 03.12.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

SELECT count(ID) AS count_of_users, 
    SUM(payer) AS count_of_payer, 
    ROUND(AVG(payer) * 100, 2) AS part_of_payer
FROM fantasy.users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT r.race, 
    SUM(u.payer) AS count_of_payers, 
    COUNT(u.id) AS count_of_players,  
    ROUND((SUM(CASE WHEN u.payer = 1 THEN u.payer END)::NUMERIC / COUNT(u.id)::NUMERIC) * 100, 2) AS part_of_payer_on_race
FROM fantasy.race AS r
JOIN fantasy.users AS u ON r.race_id = u.race_id
GROUP BY r.race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT COUNT(amount) AS count_amount, 
    SUM(amount) AS sum_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    ROUND((AVG(amount))::NUMERIC, 2) AS avg_amount,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount))::NUMERIC, 2) AS median_amount,
    ROUND((STDDEV(amount))::NUMERIC, 2) AS std_dev
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:

SELECT 
    COUNT(CASE WHEN amount = 0 THEN 1 END) AS count_of_zero,
    ROUND((COUNT(CASE WHEN amount = 0 THEN 1 END) :: float / COUNT(amount) :: float)::NUMERIC * 100, 2) AS part_zero_amount
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:

WITH items_sales AS (
  SELECT e.item_code, i.game_items,
         COUNT(*) AS absolute_sales,
         COUNT(DISTINCT e.id) AS distinct_buyers
  FROM fantasy.events e
  JOIN fantasy.items i ON e.item_code = i.item_code
  WHERE e.amount > 0 
  GROUP BY e.item_code, i.game_items
),
total_sales AS (
  SELECT SUM(absolute_sales) AS total_absolute_sales
  FROM items_sales
),
players_count AS (
  SELECT COUNT(DISTINCT id) AS distinct_buyers
  FROM fantasy.events
  WHERE amount > 0
)
SELECT 
  s.item_code, 
  s.game_items, 
  s.absolute_sales,
  ROUND((s.absolute_sales::float / (SELECT total_absolute_sales FROM total_sales) * 100)::numeric, 2) AS part_of_sales_in_procent,
  ROUND((s.distinct_buyers::float / (SELECT distinct_buyers FROM players_count) * 100)::numeric, 2) AS part_of_player_in_procent
FROM items_sales s
ORDER BY part_of_sales_in_procent DESC;


-- Задача: Зависимость активности игроков от расы персонажа:

WITH player_purchases AS (
    SELECT
        u.id,
        r.race,
        SUM(CASE WHEN e.amount > 0 THEN 1 ELSE 0 END) AS total_purchases,
        SUM(e.amount) AS total_purchase_amount
    FROM fantasy.users AS u
    LEFT JOIN fantasy.events AS e ON u.id = e.id AND e.amount > 0
    LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
    GROUP BY u.id, r.race
),
buyers AS (
    SELECT DISTINCT id
    FROM fantasy.events
    WHERE amount > 0
),
payers AS (
    SELECT DISTINCT u.id
    FROM fantasy.users AS u
    INNER JOIN fantasy.events AS e ON u.id = e.id
    WHERE u.payer = 1 AND e.amount > 0 
)
SELECT
    r.race,
    COUNT(DISTINCT p.id) AS total_players,
    COUNT(DISTINCT b.id) AS count_of_buyers, 
    ROUND((COUNT(b.id)::NUMERIC / COUNT(DISTINCT p.id)) * 100, 2) AS part_of_payer_on_race, 
    ROUND((COUNT(DISTINCT pa.id)::numeric / COUNT(DISTINCT b.id)) * 100, 2) AS part_of_payers_from_buyers, 
    ROUND(AVG(p.total_purchases) FILTER (WHERE p.total_purchases > 0)::NUMERIC, 2) AS avg_purchase_count,  
    ROUND(SUM(p.total_purchase_amount)::NUMERIC / NULLIF(SUM(p.total_purchases), 0), 2) AS avg_cost_per_purchase,  
    ROUND(SUM(p.total_purchase_amount)::NUMERIC / COUNT(DISTINCT b.id), 2) AS avg_total_cost_per_player 
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
LEFT JOIN player_purchases AS p ON u.id = p.id
LEFT JOIN buyers AS b ON p.id = b.id
LEFT JOIN payers AS pa ON p.id = pa.id
GROUP BY r.race;