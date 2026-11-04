-- ============================================================================
-- Модуль 4: Представлення (Views)
-- ============================================================================

-- 6. ПРЕДСТАВЛЕННЯ (VIEWS) - Мінімум 3
-- ============================================================================

-- ПРЕДСТАВЛЕННЯ 1: Оперативний перегляд списку заявок
-- (вимога: "Забезпечити оперативний перегляд списку заявок (рекламні видання, рекламодавець, вартість)")
CREATE OR REPLACE VIEW v_active_ad_orders AS
SELECT 
    ord.id_order,
    ord.order_number,
    ord.order_date,
    adv.company_name AS advertiser_name,
    adv.contact_person,
    adv.phone AS advertiser_phone,
    STRING_AGG(DISTINCT pub.publication_name, ', ') AS publications_list,
    cat.category_name,
    ord.ad_title,
    ord.total_cost,
    ord.paid_amount,
    (ord.total_cost - ord.paid_amount) AS balance_due,
    ord.payment_status,
    ord.order_status,
    emp.full_name AS manager_name
FROM ad_orders ord
JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
JOIN employees emp ON ord.id_employee = emp.id_employee
JOIN ad_categories cat ON ord.id_category = cat.id_category
LEFT JOIN order_items itm ON ord.id_order = itm.id_order
LEFT JOIN publications pub ON itm.id_publication = pub.id_publication
GROUP BY 
    ord.id_order, ord.order_number, ord.order_date, 
    adv.company_name, adv.contact_person, adv.phone,
    cat.category_name, ord.ad_title, ord.total_cost, 
    ord.paid_amount, ord.payment_status, ord.order_status, emp.full_name;


-- ПРЕДСТАВЛЕННЯ 2: Каталог рекламних видань з характеристиками та розцінками
-- (вимога: "Каталог рекламних видань")
CREATE OR REPLACE VIEW v_publications_catalog AS
SELECT 
    pub.id_publication,
    pub.publication_name,
    pt.type_name AS publication_type,
    pub.periodicity,
    pub.circulation,
    pub.format_size,
    pub.chief_editor,
    pub.contact_phone,
    pub.rating_score,
    COUNT(plc.id_placement) AS available_placements_count,
    MIN(plc.base_price_per_unit) AS min_placement_price,
    MAX(plc.base_price_per_unit) AS max_placement_price
FROM publications pub
JOIN publication_types pt ON pub.id_publication_type = pt.id_publication_type
LEFT JOIN ad_placements plc ON pub.id_publication = plc.id_publication
GROUP BY 
    pub.id_publication, pub.publication_name, pt.type_name, 
    pub.periodicity, pub.circulation, pub.format_size, 
    pub.chief_editor, pub.contact_phone, pub.rating_score;


-- ПРЕДСТАВЛЕННЯ 3: Відомість заборгованості рекламодавців (для бухгалтерії)
CREATE OR REPLACE VIEW v_debtors_report AS
SELECT 
    adv.id_advertiser,
    adv.company_name,
    adv.contact_person,
    adv.phone,
    adv.email,
    COUNT(ord.id_order) AS unpaid_orders_count,
    SUM(ord.total_cost) AS total_orders_sum,
    SUM(ord.paid_amount) AS total_paid_sum,
    SUM(ord.total_cost - ord.paid_amount) AS outstanding_debt
FROM advertisers adv
JOIN ad_orders ord ON adv.id_advertiser = ord.id_advertiser
WHERE ord.payment_status IN ('Не оплачено', 'Частково оплачено')
  AND ord.order_status != 'Скасована'
GROUP BY adv.id_advertiser, adv.company_name, adv.contact_person, adv.phone, adv.email
HAVING SUM(ord.total_cost - ord.paid_amount) > 0.00;


-- ПРЕДСТАВЛЕННЯ 4: Зведена ефективність менеджерів з реклами
CREATE OR REPLACE VIEW v_manager_sales_summary AS
SELECT 
    emp.id_employee,
    emp.full_name AS manager_name,
    emp.position,
    COUNT(ord.id_order) AS total_orders_handled,
    COALESCE(SUM(ord.total_cost), 0.00) AS total_revenue_generated,
    COALESCE(SUM(ord.paid_amount), 0.00) AS actual_cash_received,
    ROUND(COALESCE(SUM(ord.paid_amount), 0.00) * (emp.commission_rate / 100.00), 2) AS earned_commission
FROM employees emp
LEFT JOIN ad_orders ord ON emp.id_employee = ord.id_employee AND ord.order_status != 'Скасована'
WHERE emp.position LIKE '%Менеджер%'
GROUP BY emp.id_employee, emp.full_name, emp.position, emp.commission_rate;


-- ============================================================================
