-- ============================================================================
-- Модуль 5: Тригери та тригерні функції PL/pgSQL
-- ============================================================================

-- 4. ТРИГЕРИ ТА ТРИГЕРНІ ФУНКЦІЇ (TRIGGERS) - Мінімум 5
-- ============================================================================

-- ТРИГЕР 1: Автоматичний розрахунок вартості позиції замовлення з урахуванням
-- персональної знижки рекламодавця та націнки за терміновість (+100%)
CREATE OR REPLACE FUNCTION fn_trg_calculate_item_cost()
RETURNS TRIGGER AS $$
DECLARE
    v_discount NUMERIC(4, 2);
    v_base_price NUMERIC(12, 2);
    v_urgent_multiplier NUMERIC(3, 2);
BEGIN
    -- Отримуємо знижку клієнта
    SELECT COALESCE(adv.discount_percent, 0.00)
    INTO v_discount
    FROM ad_orders ord
    JOIN advertisers adv ON ord.id_advertiser = adv.id_advertiser
    WHERE ord.id_order = NEW.id_order;

    -- Отримуємо базовий тариф місця розміщення
    SELECT base_price_per_unit
    INTO v_base_price
    FROM ad_placements
    WHERE id_placement = NEW.id_placement;

    NEW.applied_price_per_unit := v_base_price;

    -- Коефіцієнт терміновості (якщо терміново - подвійний тариф, згідно варіанту)
    IF NEW.is_urgent THEN
        v_urgent_multiplier := 2.00;
    ELSE
        v_urgent_multiplier := 1.00;
    END IF;

    -- Формула: обсяг * ціна * множник терміновості * (1 - знижка/100)
    NEW.calculated_cost := ROUND(
        (NEW.volume_units * NEW.applied_price_per_unit * v_urgent_multiplier * (1.00 - v_discount / 100.00)), 
        2
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_order_item_cost
BEFORE INSERT OR UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_trg_calculate_item_cost();


-- ТРИГЕР 2: Автоматичний перерахунок загальної вартості заявки (total_cost)
-- в ad_orders при додаванні, зміні чи видаленні позицій у order_items
CREATE OR REPLACE FUNCTION fn_trg_update_order_total_cost()
RETURNS TRIGGER AS $$
DECLARE
    v_target_order_id INT;
    v_sum NUMERIC(12, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_target_order_id := OLD.id_order;
    ELSE
        v_target_order_id := NEW.id_order;
    END IF;

    SELECT COALESCE(SUM(calculated_cost), 0.00)
    INTO v_sum
    FROM order_items
    WHERE id_order = v_target_order_id
      AND publication_status != 'Скасовано';

    UPDATE ad_orders
    SET total_cost = v_sum
    WHERE id_order = v_target_order_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_order_totals
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_trg_update_order_total_cost();


-- ТРИГЕР 3: Реєстрація платежу - оновлення сплаченої суми (paid_amount)
-- та автоматичне коригування статусу оплати (payment_status)
CREATE OR REPLACE FUNCTION fn_trg_process_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_total NUMERIC(12, 2);
    v_paid NUMERIC(12, 2);
    v_new_status VARCHAR(25);
BEGIN
    -- Підсумовуємо всі платежі за замовленням
    SELECT COALESCE(SUM(payment_amount), 0.00)
    INTO v_paid
    FROM payments
    WHERE id_order = NEW.id_order;

    -- Отримуємо загальну вартість
    SELECT total_cost
    INTO v_total
    FROM ad_orders
    WHERE id_order = NEW.id_order;

    -- Визначаємо новий статус
    IF v_paid >= v_total AND v_total > 0 THEN
        v_new_status := 'Оплачено';
    ELSIF v_paid > 0 AND v_paid < v_total THEN
        v_new_status := 'Частково оплачено';
    ELSE
        v_new_status := 'Не оплачено';
    END IF;

    -- Оновлюємо замовлення
    UPDATE ad_orders
    SET paid_amount = v_paid,
        payment_status = v_new_status
    WHERE id_order = NEW.id_order;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_register_payment
AFTER INSERT OR UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION fn_trg_process_payment();


-- ТРИГЕР 4: Захист цілісності даних - заборона видалення замовлення,
-- якщо по ньому вже зареєстровано хоча б один платіж
CREATE OR REPLACE FUNCTION fn_trg_prevent_paid_order_deletion()
RETURNS TRIGGER AS $$
DECLARE
    v_payment_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_payment_count
    FROM payments
    WHERE id_order = OLD.id_order;

    IF v_payment_count > 0 THEN
        RAISE EXCEPTION 'Заборонено видаляти замовлення % (ID: %), оскільки по ньому наявні проведені платежі!', 
            OLD.order_number, OLD.id_order;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_paid_order_delete
BEFORE DELETE ON ad_orders
FOR EACH ROW
EXECUTE FUNCTION fn_trg_prevent_paid_order_deletion();


-- ТРИГЕР 5: Ведення журналу аудиту - фіксація будь-яких змін статусів 
-- та фінансових показників замовлень у таблиці audit_log
CREATE OR REPLACE FUNCTION fn_trg_audit_order_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.order_status <> NEW.order_status) OR 
       (OLD.payment_status <> NEW.payment_status) OR 
       (OLD.total_cost <> NEW.total_cost) THEN
        INSERT INTO audit_log (table_name, operation_type, record_id, changed_by_user, details)
        VALUES (
            'ad_orders',
            TG_OP,
            NEW.id_order,
            CURRENT_USER,
            FORMAT('Зміна замовлення %s: Статус [%s -> %s], Оплата [%s -> %s], Сума [%s -> %s]',
                   NEW.order_number, OLD.order_status, NEW.order_status, 
                   OLD.payment_status, NEW.payment_status, OLD.total_cost, NEW.total_cost)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_ad_orders
AFTER UPDATE ON ad_orders
FOR EACH ROW
EXECUTE FUNCTION fn_trg_audit_order_changes();


-- ============================================================================
