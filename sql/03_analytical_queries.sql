-- ============================================================================
-- Модуль 3: Типові та аналітичні SQL-запити (12 запитів)
-- ============================================================================

-- 8. ТИПОВІ ТА АНАЛІТИЧНІ SQL-ЗАПИТИ (QUERIES) - 12 запитів
-- ============================================================================

-- ЗАПИТ 1: Групування та сортування (виручка та кількість виходів за кожним виданням)
-- Демонструє: GROUP BY, ORDER BY, агрегатні функції SUM, COUNT
SELECT 
    pub.publication_name,
    pt.type_name,
    COUNT(itm.id_order_item) AS total_placements_count,
    SUM(itm.calculated_cost) AS total_revenue
FROM publications pub
JOIN publication_types pt ON pub.id_publication_type = pt.id_publication_type
LEFT JOIN order_items itm ON pub.id_publication = itm.id_publication
GROUP BY pub.id_publication, pub.publication_name, pt.type_name
ORDER BY total_revenue DESC NULLS LAST;

-- ЗАПИТ 2: Критерії відбору (замовлення за визначений період із фільтрацією за статусом)
-- Демонструє: WHERE з датами та статусами
SELECT 
    ord.order_number,
    ord.order_date,
    adv.company_name,
    ord.ad_title,
    ord.total_cost,
    ord.payment_status
FROM ad_orders ord
JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
WHERE ord.order_date >= '2026-03-01' 
  AND ord.order_date <= '2026-03-15'
  AND ord.payment_status IN ('Оплачено', 'Частково оплачено')
ORDER BY ord.order_date;

-- ЗАПИТ 3: Агрегатні функції з фільтрацією за умовою HAVING
-- Демонструє: COUNT, AVG, HAVING (категорії реклами з середнім чеком замовлення понад 5000 грн)
SELECT 
    cat.category_name,
    COUNT(ord.id_order) AS orders_count,
    ROUND(AVG(ord.total_cost), 2) AS avg_order_cost,
    SUM(ord.total_cost) AS total_category_revenue
FROM ad_categories cat
JOIN ad_orders ord ON cat.id_category = ord.id_category
GROUP BY cat.id_category, cat.category_name
HAVING AVG(ord.total_cost) > 5000.00
ORDER BY avg_order_cost DESC;

-- ЗАПИТ 4: Спеціальний оператор LIKE (пошук оголошень за ключовими словами у тексті)
-- Демонструє: ILIKE (нечутливий до регістру пошук у змісті оголошення)
SELECT 
    ord.order_number,
    adv.company_name,
    ord.ad_title,
    ord.ad_content_text
FROM ad_orders ord
JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
WHERE ord.ad_content_text ILIKE '%знижк%' 
   OR ord.ad_content_text ILIKE '%квартир%'
   OR ord.ad_title ILIKE '%акці%';

-- ЗАПИТ 5: Спеціальний оператор IN (вибірка публікацій у визначених типах видань)
-- Демонструє: IN зі списком значень
SELECT 
    pub.publication_name,
    pt.type_name,
    pub.circulation,
    pub.periodicity
FROM publications pub
JOIN publication_types pt ON pub.id_publication_type = pt.id_publication_type
WHERE pt.type_name IN ('Газета суспільно-політична', 'Діловий журнал')
ORDER BY pub.circulation DESC;

-- ЗАПИТ 6: Спеціальний оператор BETWEEN (пошук місць розміщення у заданому ціновому коридорі)
-- Демонструє: BETWEEN для числових діапазонів розцінок
SELECT 
    pub.publication_name,
    plc.placement_name,
    plc.unit_type,
    plc.base_price_per_unit,
    plc.color_mode
FROM ad_placements plc
JOIN publications pub ON plc.id_publication = pub.id_publication
WHERE plc.base_price_per_unit BETWEEN 500.00 AND 10000.00
ORDER BY plc.base_price_per_unit ASC;

-- ЗАПИТ 7: Спеціальний оператор IS NULL (виявлення разових замовлень без укладеного договору)
-- Демонструє: IS NULL для зовнішніх ключів
SELECT 
    ord.order_number,
    ord.order_date,
    adv.company_name,
    adv.phone,
    ord.total_cost,
    ord.payment_status
FROM ad_orders ord
JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
WHERE ord.id_contract IS NULL
ORDER BY ord.order_date DESC;

-- ЗАПИТ 8: Скалярний підзапит (вибірка позицій, вартість яких перевищує середню по агентству)
-- Демонструє: скалярний вкладений SELECT
SELECT 
    itm.id_order_item,
    ord.order_number,
    pub.publication_name,
    plc.placement_name,
    itm.target_release_date,
    itm.calculated_cost
FROM order_items itm
JOIN ad_orders ord ON itm.id_order = ord.id_order
JOIN publications pub ON itm.id_publication = pub.id_publication
JOIN ad_placements plc ON itm.id_placement = plc.id_placement
WHERE itm.calculated_cost > (
    SELECT AVG(calculated_cost) 
    FROM order_items 
    WHERE publication_status != 'Скасовано'
)
ORDER BY itm.calculated_cost DESC;

-- ЗАПИТ 9: Корельований підзапит (рекламодавці, чий обсяг замовлень вищий за середній показник)
-- Демонструє: корельований підзапит з прив'язкою до зовнішньої таблиці
SELECT 
    adv.id_advertiser,
    adv.company_name,
    adv.contact_person,
    adv.discount_percent
FROM advertisers adv
WHERE (
    SELECT COALESCE(SUM(total_cost), 0.00)
    FROM ad_orders ord
    WHERE ord.id_advertiser = adv.id_advertiser
) > (
    SELECT AVG(total_cost) FROM ad_orders
);

-- ЗАПИТ 10: Спеціальний оператор EXISTS (видання, у яких розміщено замовлення клієнтів зі знижкою)
-- Демонструє: EXISTS з перевіркою існування пов'язаних записів
SELECT 
    pub.id_publication,
    pub.publication_name,
    pub.circulation
FROM publications pub
WHERE EXISTS (
    SELECT 1 
    FROM order_items itm
    JOIN ad_orders ord ON itm.id_order = ord.id_order
    JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
    WHERE itm.id_publication = pub.id_publication
      AND adv.discount_percent > 0.00
);

-- ЗАПИТ 11: З'єднання 4-х таблиць (детальний звіт публікацій для друкарні та випускового редактора)
-- Демонструє: багаторазовий INNER JOIN
SELECT 
    pub.publication_name,
    itm.target_release_date,
    plc.placement_name,
    adv.company_name AS client_name,
    ord.order_number,
    ord.ad_title,
    itm.volume_units,
    plc.unit_type,
    itm.is_urgent
FROM order_items itm
JOIN ad_orders ord ON itm.id_order = ord.id_order
JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
JOIN publications pub ON itm.id_publication = pub.id_publication
JOIN ad_placements plc ON itm.id_placement = plc.id_placement
WHERE itm.publication_status != 'Скасовано'
ORDER BY itm.target_release_date, pub.publication_name;

-- ЗАПИТ 12: Аналітичний CTE-запит (загальна фінансова зведення та рівень інкасації оплат)
-- Демонструє: WITH (Common Table Expressions), агрегацію та розрахунок відсотків
WITH OrderFinancials AS (
    SELECT 
        adv.company_name,
        COUNT(ord.id_order) AS orders_qty,
        SUM(ord.total_cost) AS total_billed,
        SUM(ord.paid_amount) AS total_collected
    FROM advertisers adv
    JOIN ad_orders ord ON adv.id_advertiser = ord.id_advertiser
    GROUP BY adv.id_advertiser, adv.company_name
)
SELECT 
    company_name,
    orders_qty,
    total_billed,
    total_collected,
    (total_billed - total_collected) AS outstanding_balance,
    CASE 
        WHEN total_billed > 0 THEN ROUND((total_collected / total_billed) * 100.0, 1)
        ELSE 100.0
    END AS collection_rate_pct
FROM OrderFinancials
ORDER BY total_billed DESC;


-- ============================================================================
