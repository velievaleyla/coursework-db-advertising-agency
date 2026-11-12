-- ============================================================================
-- Модуль 6: Збережені процедури та функції PL/pgSQL
-- ============================================================================

-- 5. ЗБЕРЕЖЕНІ ПРОЦЕДУРИ ТА ФУНКЦІЇ (STORED PROCEDURES / FUNCTIONS) - Мінімум 3
-- ============================================================================

-- ФУНКЦІЯ 1: Оперативний перегляд поточних заявок агентства на вказану дату
-- (пряма вимога варіанту 13: "Список поточних заявок агентства: на будь-яку дату")
CREATE OR REPLACE FUNCTION fn_get_orders_by_date(p_target_date DATE)
RETURNS TABLE (
    order_num VARCHAR(30),
    order_dt DATE,
    advertiser_name VARCHAR(150),
    contact_phone dm_phone,
    publication_title VARCHAR(100),
    placement_type VARCHAR(100),
    planned_release DATE,
    item_sum dm_money,
    pay_status dm_payment_status
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ord.order_number,
        ord.order_date,
        adv.company_name,
        adv.phone,
        pub.publication_name,
        plc.placement_name,
        itm.target_release_date,
        itm.calculated_cost,
        ord.payment_status
    FROM ad_orders ord
    JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
    JOIN order_items itm ON ord.id_order = itm.id_order
    JOIN publications pub ON itm.id_publication = pub.id_publication
    JOIN ad_placements plc ON itm.id_placement = plc.id_placement
    WHERE itm.target_release_date = p_target_date
    ORDER BY ord.order_number, pub.publication_name;
END;
$$ LANGUAGE plpgsql;


-- ФУНКЦІЯ 2: Формування квитанції на оплату заявки рекламодавцем
-- (вимога варіанту 13: "Друк квитанції на оплату заявки")
CREATE OR REPLACE FUNCTION fn_generate_receipt_data(p_order_id INT)
RETURNS TABLE (
    receipt_no VARCHAR(50),
    order_code VARCHAR(30),
    order_date DATE,
    client_name VARCHAR(150),
    legal_id VARCHAR(20),
    ad_heading VARCHAR(150),
    subtotal dm_money,
    vat_sum dm_money,
    grand_total dm_money,
    amount_paid dm_money,
    debt_remaining dm_money,
    status_payment dm_payment_status
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'RCPT-' || ord.order_number || '-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') AS receipt_no,
        ord.order_number AS order_code,
        ord.order_date,
        adv.company_name AS client_name,
        adv.legal_code AS legal_id,
        ord.ad_title AS ad_heading,
        ROUND(ord.total_cost / 1.20, 2) AS subtotal,
        ROUND(ord.total_cost - (ord.total_cost / 1.20), 2) AS vat_sum,
        ord.total_cost AS grand_total,
        ord.paid_amount AS amount_paid,
        GREATEST(ord.total_cost - ord.paid_amount, 0.00) AS debt_remaining,
        ord.payment_status AS status_payment
    FROM ad_orders ord
    JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
    WHERE ord.id_order = p_order_id;
END;
$$ LANGUAGE plpgsql;


-- ПРОЦЕДУРА 3: Комплексна реєстрація нової заявки та додавання першої публікації
-- в єдиній безпечній транзакції (вимога: "Формування заявки")
CREATE OR REPLACE PROCEDURE sp_create_order_with_item(
    p_order_number VARCHAR(30),
    p_advertiser_id INT,
    p_employee_id INT,
    p_category_id INT,
    p_ad_title VARCHAR(150),
    p_ad_content TEXT,
    p_publication_id INT,
    p_placement_id INT,
    p_release_date DATE,
    p_volume NUMERIC(8, 2),
    p_is_urgent BOOLEAN,
    INOUT p_new_order_id INT DEFAULT NULL
) AS $$
BEGIN
    -- Вставка заголовка замовлення
    INSERT INTO ad_orders (
        order_number, order_date, id_advertiser, id_employee, 
        id_category, ad_title, ad_content_text
    )
    VALUES (
        p_order_number, CURRENT_DATE, p_advertiser_id, p_employee_id,
        p_category_id, p_ad_title, p_ad_content
    )
    RETURNING id_order INTO p_new_order_id;

    -- Вставка позиції замовлення (тригер 1 автоматично порахує вартість)
    INSERT INTO order_items (
        id_order, id_publication, id_placement, target_release_date,
        volume_units, applied_price_per_unit, is_urgent
    )
    VALUES (
        p_new_order_id, p_publication_id, p_placement_id, p_release_date,
        p_volume, 1.00, p_is_urgent
    );

    RAISE NOTICE 'Заявку % успішно створено з ID % та додано публікацію на дату %', 
        p_order_number, p_new_order_id, p_release_date;
END;
$$ LANGUAGE plpgsql;


-- ФУНКЦІЯ 4: Розрахунок аналітичної статистики та коригування знижки рекламодавця
CREATE OR REPLACE FUNCTION fn_calculate_advertiser_stats(p_adv_id INT)
RETURNS TABLE (
    advertiser_title VARCHAR(150),
    total_orders_count BIGINT,
    total_spent dm_money,
    current_discount NUMERIC(4, 2),
    recommended_discount NUMERIC(4, 2)
) AS $$
DECLARE
    v_total_spent dm_money;
    v_rec_discount NUMERIC(4, 2);
BEGIN
    SELECT COALESCE(SUM(total_cost), 0.00)
    INTO v_total_spent
    FROM ad_orders
    WHERE id_advertiser = p_adv_id AND order_status != 'Скасована';

    -- Прогресивна шкала знижок агентства
    IF v_total_spent >= 100000.00 THEN
        v_rec_discount := 20.00;
    ELSIF v_total_spent >= 50000.00 THEN
        v_rec_discount := 15.00;
    ELSIF v_total_spent >= 20000.00 THEN
        v_rec_discount := 10.00;
    ELSIF v_total_spent >= 5000.00 THEN
        v_rec_discount := 5.00;
    ELSE
        v_rec_discount := 0.00;
    END IF;

    RETURN QUERY
    SELECT 
        adv.company_name,
        COUNT(ord.id_order),
        v_total_spent,
        adv.discount_percent,
        v_rec_discount
    FROM advertisers adv
    LEFT JOIN ad_orders ord ON adv.id_advertiser = ord.id_advertiser AND ord.order_status != 'Скасована'
    WHERE adv.id_advertiser = p_adv_id
    GROUP BY adv.id_advertiser, adv.company_name, adv.discount_percent;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
