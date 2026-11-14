-- ============================================================================
-- КУРСОВА РОБОТА з дисципліни "Організація баз даних та знань"
-- Тема: Розробка бази даних для підтримки діяльності рекламного агентства
-- Варіант: 13
-- СУБД: PostgreSQL (версія 14+)
-- ============================================================================

-- Видалення попередніх об'єктів для забезпечення повторного запуску
DROP VIEW IF EXISTS v_manager_sales_summary CASCADE;
DROP VIEW IF EXISTS v_debtors_report CASCADE;
DROP VIEW IF EXISTS v_publications_catalog CASCADE;
DROP VIEW IF EXISTS v_active_ad_orders CASCADE;

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS ad_orders CASCADE;
DROP TABLE IF EXISTS contracts CASCADE;
DROP TABLE IF EXISTS ad_placements CASCADE;
DROP TABLE IF EXISTS publications CASCADE;
DROP TABLE IF EXISTS publication_types CASCADE;
DROP TABLE IF EXISTS ad_categories CASCADE;
DROP TABLE IF EXISTS advertisers CASCADE;
DROP TABLE IF EXISTS employees CASCADE;

DROP SEQUENCE IF EXISTS seq_audit_log CASCADE;
DROP SEQUENCE IF EXISTS seq_payments CASCADE;
DROP SEQUENCE IF EXISTS seq_order_items CASCADE;
DROP SEQUENCE IF EXISTS seq_ad_orders CASCADE;
DROP SEQUENCE IF EXISTS seq_contracts CASCADE;
DROP SEQUENCE IF EXISTS seq_ad_placements CASCADE;
DROP SEQUENCE IF EXISTS seq_publications CASCADE;
DROP SEQUENCE IF EXISTS seq_publication_types CASCADE;
DROP SEQUENCE IF EXISTS seq_ad_categories CASCADE;
DROP SEQUENCE IF EXISTS seq_advertisers CASCADE;
DROP SEQUENCE IF EXISTS seq_employees CASCADE;

DROP DOMAIN IF EXISTS dm_phone CASCADE;
DROP DOMAIN IF EXISTS dm_email CASCADE;
DROP DOMAIN IF EXISTS dm_money CASCADE;
DROP DOMAIN IF EXISTS dm_payment_status CASCADE;
DROP DOMAIN IF EXISTS dm_order_status CASCADE;
DROP DOMAIN IF EXISTS dm_client_type CASCADE;

-- ============================================================================
-- 1. СТВОРЕННЯ ПОСЛІДОВНОСТЕЙ (SEQUENCES)
-- ============================================================================
CREATE SEQUENCE seq_employees START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_advertisers START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_publication_types START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_publications START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_ad_categories START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_ad_placements START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_contracts START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_ad_orders START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_order_items START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_payments START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_audit_log START WITH 1 INCREMENT BY 1;

-- ============================================================================
-- 2. СТВОРЕННЯ ДОМЕНІВ (DOMAINS) З ОБМЕЖЕННЯМИ
-- ============================================================================
CREATE DOMAIN dm_phone AS VARCHAR(25)
    CHECK (VALUE ~ '^\+?[0-9\s\-\(\)]{7,25}$');

CREATE DOMAIN dm_email AS VARCHAR(100)
    CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

CREATE DOMAIN dm_money AS NUMERIC(12, 2)
    CHECK (VALUE >= 0.00);

CREATE DOMAIN dm_payment_status AS VARCHAR(25)
    CHECK (VALUE IN ('Не оплачено', 'Частково оплачено', 'Оплачено', 'Скасовано'));

CREATE DOMAIN dm_order_status AS VARCHAR(25)
    CHECK (VALUE IN ('Нова', 'В обробці', 'Підтверджена', 'Виконана', 'Скасована'));

CREATE DOMAIN dm_client_type AS VARCHAR(25)
    CHECK (VALUE IN ('Юридична особа', 'Фізична особа', 'ФОП'));

-- ============================================================================
-- 3. СТВОРЕННЯ ТАБЛИЦЬ (TABLES)
-- ============================================================================

-- 3.1 Таблиця співробітників агентства (employees)
CREATE TABLE employees (
    id_employee INT PRIMARY KEY DEFAULT NEXTVAL('seq_employees'),
    full_name VARCHAR(100) NOT NULL,
    position VARCHAR(50) NOT NULL,
    phone dm_phone NOT NULL,
    email dm_email NOT NULL UNIQUE,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    commission_rate NUMERIC(4, 2) NOT NULL DEFAULT 5.00 
        CHECK (commission_rate BETWEEN 0.00 AND 30.00)
);

-- 3.2 Таблиця рекламодавців (advertisers)
CREATE TABLE advertisers (
    id_advertiser INT PRIMARY KEY DEFAULT NEXTVAL('seq_advertisers'),
    client_type dm_client_type NOT NULL DEFAULT 'Юридична особа',
    company_name VARCHAR(150) NOT NULL,
    contact_person VARCHAR(100) NOT NULL,
    legal_code VARCHAR(20) UNIQUE, -- ЄДРПОУ або ІПН
    address VARCHAR(200) NOT NULL,
    phone dm_phone NOT NULL,
    email dm_email,
    discount_percent NUMERIC(4, 2) NOT NULL DEFAULT 0.00 
        CHECK (discount_percent BETWEEN 0.00 AND 50.00)
);

-- 3.3 Таблиця типів рекламних видань (publication_types)
CREATE TABLE publication_types (
    id_publication_type INT PRIMARY KEY DEFAULT NEXTVAL('seq_publication_types'),
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    base_coefficient NUMERIC(3, 2) NOT NULL DEFAULT 1.00 
        CHECK (base_coefficient BETWEEN 0.50 AND 3.00)
);

-- 3.4 Таблиця рекламних видань (publications)
CREATE TABLE publications (
    id_publication INT PRIMARY KEY DEFAULT NEXTVAL('seq_publications'),
    id_publication_type INT NOT NULL,
    publication_name VARCHAR(100) NOT NULL,
    periodicity VARCHAR(50) NOT NULL, -- Щоденно, Щотижня, Двічі на місяць, Щомісяця
    circulation INT NOT NULL CHECK (circulation > 0),
    format_size VARCHAR(20) NOT NULL DEFAULT 'A4',
    chief_editor VARCHAR(100),
    contact_phone dm_phone NOT NULL,
    email dm_email,
    rating_score NUMERIC(3, 1) DEFAULT 5.0 CHECK (rating_score BETWEEN 1.0 AND 10.0),
    CONSTRAINT fk_publication_type 
        FOREIGN KEY (id_publication_type) 
        REFERENCES publication_types(id_publication_type) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.5 Таблиця тематичних рубрик / категорій реклами (ad_categories)
CREATE TABLE ad_categories (
    id_category INT PRIMARY KEY DEFAULT NEXTVAL('seq_ad_categories'),
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3.6 Таблиця місць розміщення реклами та розцінок (ad_placements)
CREATE TABLE ad_placements (
    id_placement INT PRIMARY KEY DEFAULT NEXTVAL('seq_ad_placements'),
    id_publication INT NOT NULL,
    placement_name VARCHAR(100) NOT NULL,
    unit_type VARCHAR(30) NOT NULL, -- кв.см, шпальта, колонка, блок
    base_price_per_unit dm_money NOT NULL CHECK (base_price_per_unit > 0.00),
    color_mode VARCHAR(30) NOT NULL DEFAULT 'Повноколір' 
        CHECK (color_mode IN ('Повноколір', 'Чорно-білий', 'Двоколір')),
    max_volume INT NOT NULL DEFAULT 1000 CHECK (max_volume > 0),
    CONSTRAINT fk_placement_publication 
        FOREIGN KEY (id_publication) 
        REFERENCES publications(id_publication) 
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- 3.7 Таблиця договорів про співпрацю (contracts)
CREATE TABLE contracts (
    id_contract INT PRIMARY KEY DEFAULT NEXTVAL('seq_contracts'),
    contract_number VARCHAR(30) NOT NULL UNIQUE,
    id_advertiser INT NOT NULL,
    id_employee INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_budget dm_money NOT NULL DEFAULT 0.00,
    contract_status VARCHAR(25) NOT NULL DEFAULT 'Діючий' 
        CHECK (contract_status IN ('Проєкт', 'Діючий', 'Завершений', 'Розірваний')),
    CONSTRAINT chk_contract_dates CHECK (end_date >= start_date),
    CONSTRAINT fk_contract_advertiser 
        FOREIGN KEY (id_advertiser) 
        REFERENCES advertisers(id_advertiser) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_contract_employee 
        FOREIGN KEY (id_employee) 
        REFERENCES employees(id_employee) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.8 Таблиця заявок на розміщення реклами (ad_orders)
CREATE TABLE ad_orders (
    id_order INT PRIMARY KEY DEFAULT NEXTVAL('seq_ad_orders'),
    order_number VARCHAR(30) NOT NULL UNIQUE,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    id_contract INT,
    id_advertiser INT NOT NULL,
    id_employee INT NOT NULL,
    id_category INT NOT NULL,
    ad_title VARCHAR(150) NOT NULL,
    ad_content_text TEXT NOT NULL,
    total_cost dm_money NOT NULL DEFAULT 0.00,
    paid_amount dm_money NOT NULL DEFAULT 0.00,
    payment_status dm_payment_status NOT NULL DEFAULT 'Не оплачено',
    order_status dm_order_status NOT NULL DEFAULT 'Нова',
    CONSTRAINT fk_order_contract 
        FOREIGN KEY (id_contract) 
        REFERENCES contracts(id_contract) 
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_order_advertiser 
        FOREIGN KEY (id_advertiser) 
        REFERENCES advertisers(id_advertiser) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_employee 
        FOREIGN KEY (id_employee) 
        REFERENCES employees(id_employee) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_category 
        FOREIGN KEY (id_category) 
        REFERENCES ad_categories(id_category) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.9 Таблиця публікацій за заявкою / графік виходів (order_items)
CREATE TABLE order_items (
    id_order_item INT PRIMARY KEY DEFAULT NEXTVAL('seq_order_items'),
    id_order INT NOT NULL,
    id_publication INT NOT NULL,
    id_placement INT NOT NULL,
    target_release_date DATE NOT NULL,
    volume_units NUMERIC(8, 2) NOT NULL CHECK (volume_units > 0),
    applied_price_per_unit dm_money NOT NULL,
    calculated_cost dm_money NOT NULL DEFAULT 0.00,
    is_urgent BOOLEAN NOT NULL DEFAULT FALSE,
    publication_status VARCHAR(25) NOT NULL DEFAULT 'Заплановано'
        CHECK (publication_status IN ('Заплановано', 'В верстці', 'Вийшло друком', 'Скасовано')),
    CONSTRAINT fk_item_order 
        FOREIGN KEY (id_order) 
        REFERENCES ad_orders(id_order) 
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_item_publication 
        FOREIGN KEY (id_publication) 
        REFERENCES publications(id_publication) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_item_placement 
        FOREIGN KEY (id_placement) 
        REFERENCES ad_placements(id_placement) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.10 Таблиця платежів та квитанцій (payments)
CREATE TABLE payments (
    id_payment INT PRIMARY KEY DEFAULT NEXTVAL('seq_payments'),
    payment_number VARCHAR(30) NOT NULL UNIQUE,
    id_order INT NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_amount dm_money NOT NULL CHECK (payment_amount > 0.00),
    payment_type VARCHAR(30) NOT NULL 
        CHECK (payment_type IN ('Безготівковий розрахунок', 'Банківська картка', 'Готівка в касу')),
    payer_name VARCHAR(150) NOT NULL,
    receipt_code VARCHAR(50) UNIQUE,
    processed_by_employee INT,
    CONSTRAINT fk_payment_order 
        FOREIGN KEY (id_order) 
        REFERENCES ad_orders(id_order) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_payment_employee 
        FOREIGN KEY (processed_by_employee) 
        REFERENCES employees(id_employee) 
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- 3.11 Таблиця журналу аудиту (audit_log)
CREATE TABLE audit_log (
    id_log INT PRIMARY KEY DEFAULT NEXTVAL('seq_audit_log'),
    table_name VARCHAR(50) NOT NULL,
    operation_type VARCHAR(15) NOT NULL,
    record_id INT NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by_user VARCHAR(50) NOT NULL DEFAULT CURRENT_USER,
    details TEXT
);

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
-- 7. НАПОВНЕННЯ ТАБЛИЦЬ ТЕСТОВИМИ ДАНИМИ (TEST DATA INSERTION)
-- ============================================================================

-- Вставка співробітників
INSERT INTO employees (full_name, position, phone, email, hire_date, commission_rate) VALUES
('Коваленко Сергій Васильович', 'Керівник рекламного відділу', '+380501112233', 's.kovalenko@agency-promo.ua', '2020-03-15', 7.00),
('Шевченко Олена Ігорівна', 'Старший менеджер з реклами', '+380672223344', 'o.shevchenko@agency-promo.ua', '2021-06-01', 6.00),
('Бондаренко Артем Петрович', 'Менеджер з роботи з клієнтами', '+380933334455', 'a.bondarenko@agency-promo.ua', '2022-09-10', 5.00),
('Мельник Тетяна Михайлівна', 'Головний бухгалтер', '+380504445566', 't.melnyk@agency-promo.ua', '2019-11-20', 0.00),
('Кравчук Дмитро Олексійович', 'Бухгалтер-касир', '+380685556677', 'd.kravchuk@agency-promo.ua', '2023-01-16', 0.00);

-- Вставка типів видань
INSERT INTO publication_types (type_name, description, base_coefficient) VALUES
('Газета суспільно-політична', 'Щоденна або щотижнева масова періодика широкого охоплення', 1.00),
('Діловий журнал', 'Глянцеве щомісячне аналітичне видання для бізнесу та інвесторів', 1.80),
('Рекламно-інформаційний дайджест', 'Безкоштовна щотижнева газета комерційних оголошень з великим тиражем', 0.85),
('Міський тижневик', 'Локальне щотижневе видання новин міста та регіону', 1.15),
('Інтернет-портал медіа-холдингу', 'Постійно оновлюваний новинний веб-ресурс з банерними місцями', 1.40);

-- Вставка тематичних рубрик
INSERT INTO ad_categories (category_name, description, is_active) VALUES
('Нерухомість та будівництво', 'Оголошення про продаж, оренду та будівництво житлових і комерційних об''єктів', TRUE),
('Автомобілі та транспорт', 'Продаж авто, запчастини, СТО, логістичні послуги', TRUE),
('Вакансії та робота', 'Пошук персоналу, пропозиції працевлаштування, рекрутинг', TRUE),
('Фінансові та юридичні послуги', 'Банківські продукти, кредитування, страхові та нотаріальні послуги', TRUE),
('Медицина, краса та здоров''я', 'Клініки, стоматологія, фармацевтика, салони краси', TRUE),
('Освіта, курси та IT', 'Навчальні центри, тренінги, IT-академії, курси іноземних мов', TRUE);

-- Вставка видань
INSERT INTO publications (id_publication_type, publication_name, periodicity, circulation, format_size, chief_editor, contact_phone, email, rating_score) VALUES
(1, 'Одеський Вісник', 'Щоденно', 45000, 'A2', 'Поліщук В. М.', '+380487001122', 'redaction@odessa-visnyk.ua', 8.5),
(2, 'Бізнес Південь', 'Щомісяця', 18000, 'A4', 'Задорожний О. С.', '+380487112233', 'editor@bizsouth.ua', 9.2),
(3, 'Авізо Реклама', 'Щотижня', 85000, 'A3', 'Григоренко І. А.', '+380487223344', 'ad@aviso-reklama.ua', 7.8),
(4, 'Чорноморські Новини', 'Двічі на тиждень', 32000, 'A3', 'Сидоренко Л. П.', '+380487334455', 'chief@chornomor-news.ua', 8.0),
(5, 'Думська Медіа Онлайн', 'Щоденно', 120000, 'WEB', 'Романов К. В.', '+380487445566', 'ads@dumskaya-online.ua', 9.5);

-- Вставка місць розміщення
INSERT INTO ad_placements (id_publication, placement_name, unit_type, base_price_per_unit, color_mode, max_volume) VALUES
(1, 'Перша шпальта (обкладинка, верх)', 'кв.см', 45.00, 'Повноколір', 300),
(1, 'Внутрішня текстова шпальта', 'кв.см', 18.00, 'Чорно-білий', 800),
(1, 'Остання сторінка (комерційний блок)', 'кв.см', 28.00, 'Повноколір', 600),
(2, 'Центральний глянцевий розворот (2 сторінки)', 'блок', 16000.00, 'Повноколір', 1),
(2, 'Полоса A4 (внутрішня сторінка)', 'блок', 9500.00, 'Повноколір', 10),
(2, '1/2 полоси A4', 'блок', 5200.00, 'Повноколір', 15),
(3, 'Блок у рубриці "Нерухомість"', 'блок', 850.00, 'Повноколір', 50),
(3, 'Рядкове текстове оголошення', 'рядок', 45.00, 'Чорно-білий', 500),
(4, 'Колонка новин компанії', 'колонка', 2200.00, 'Повноколір', 8),
(5, 'Головний банер (Top Billboard 1170x250)', 'тиждень', 14000.00, 'Повноколір', 4),
(5, 'Бічний сайдбар у статтях (300x600)', 'тиждень', 7500.00, 'Повноколір', 8);

-- Вставка рекламодавців
INSERT INTO advertisers (client_type, company_name, contact_person, legal_code, address, phone, email, discount_percent) VALUES
('Юридична особа', 'ТОВ "Буд-Альянс Південь"', 'Гончарук Вадим Іванович', '38920145', 'м. Одеса, вул. Канатна, 42', '+380487809010', 'info@bud-alians.ua', 10.00),
('Юридична особа', 'ПрАТ "Одеський Винзавод Класик"', 'Воропаєва Марина Сергіївна', '14325678', 'м. Одеса, Французький бульвар, 10', '+380487908020', 'marketing@classic-wine.ua', 15.00),
('ФОП', 'ФОП Ткаченко Василь Анатолійович (СТО АвтоДрайв)', 'Ткаченко В. А.', '2987410293', 'м. Одеса, вул. Балківська, 115', '+380671239874', 'autodrive.od@gmail.com', 5.00),
('Юридична особа', 'Мережа медичних клінік "Здоров''я Plus"', 'Кушнір Ольга Володимирівна', '41209845', 'м. Одеса, вул. Академічна, 28', '+380487556677', 'pr@zdorovya-plus.ua', 10.00),
('Фізична особа', 'Мартиненко Павло Костянтинович', 'Мартиненко П. К.', '3214569870', 'м. Одеса, просп. Шевченка, 12, кв. 45', '+380509876543', 'pavel.martynenko@ukr.net', 0.00),
('Юридична особа', 'IT-Академія "CodeFuture"', 'Самойлов Денис Юрійович', '43098712', 'м. Одеса, вул. Дерибасівська, 5', '+380634448899', 'director@codefuture.edu.ua', 12.00);

-- Вставка договорів
INSERT INTO contracts (contract_number, id_advertiser, id_employee, start_date, end_date, total_budget, contract_status) VALUES
('ДОГ-2026/001', 1, 2, '2026-01-10', '2026-12-31', 150000.00, 'Діючий'),
('ДОГ-2026/002', 2, 2, '2026-02-01', '2026-08-31', 90000.00, 'Діючий'),
('ДОГ-2026/003', 4, 3, '2026-03-01', '2026-12-31', 80000.00, 'Діючий'),
('ДОГ-2026/004', 6, 3, '2026-02-15', '2026-11-30', 65000.00, 'Діючий');

-- Вставка замовлень (ad_orders)
INSERT INTO ad_orders (order_number, order_date, id_contract, id_advertiser, id_employee, id_category, ad_title, ad_content_text) VALUES
('ЗАЯВ-2026/101', '2026-03-01', 1, 1, 2, 1, 'Старт продажу квартир у ЖК "Морська Симфонія"', 'Новий житловий комплекс біля моря. Розстрочка 0% до 3 років. Перший внесок від 20%. Дзвоніть вже сьогодні!'),
('ЗАЯВ-2026/102', '2026-03-03', 2, 2, 2, 5, 'Презентація нової лінійки вин "Шато Південь"', 'Вишуканий смак віденських традицій та сонця Півдня України. Шукайте у провідних супермаркетах міста.'),
('ЗАЯВ-2026/103', '2026-03-05', NULL, 3, 3, 2, 'Комплексна діагностика авто та шиномонтаж', 'Весняна підготовка вашого авто на СТО АвтоДрайв. Знижка 20% на заміну мастила та діагностику ходової частини.'),
('ЗАЯВ-2026/104', '2026-03-10', 3, 4, 3, 5, 'Відкриття нового відділення МРТ та КТ діагностики', 'Сучасне обладнання Philips 2025 року. Точні результати за 1 годину. Прийом за попереднім записом.'),
('ЗАЯВ-2026/105', '2026-03-12', NULL, 5, 2, 1, 'Терміновий продаж 3-кімнатної квартири в Аркадії', 'Квартира з дизайнерським ремонтом та панорамним видом на море. Всі меблі та техніка залишаються. Торг.'),
('ЗАЯВ-2026/106', '2026-03-15', 4, 6, 3, 6, 'Весняний набір на курси Fullstack Web & Data Science', 'Опануй престижну IT-професію з гарантією працевлаштування. Старт занять 1 квітня. Безкоштовний пробний урок!');

-- Вставка позицій замовлень (order_items)
-- Зауваження: тригер trg_calculate_order_item_cost автоматично розрахує calculated_cost
-- та trg_update_order_totals оновить total_cost у ad_orders
INSERT INTO order_items (id_order, id_publication, id_placement, target_release_date, volume_units, applied_price_per_unit, is_urgent, publication_status) VALUES
(1, 1, 1, '2026-03-20', 100.00, 45.00, FALSE, 'Вийшло друком'),
(1, 5, 10, '2026-03-23', 1.00, 14000.00, FALSE, 'Заплановано'),
(2, 2, 4, '2026-04-01', 1.00, 16000.00, FALSE, 'Заплановано'),
(3, 3, 7, '2026-03-25', 2.00, 850.00, FALSE, 'Вийшло друком'),
(4, 4, 9, '2026-03-27', 1.00, 2200.00, FALSE, 'В верстці'),
(4, 5, 11, '2026-03-30', 2.00, 7500.00, FALSE, 'Заплановано'),
(5, 3, 8, '2026-03-20', 8.00, 45.00, TRUE, 'Вийшло друком'), -- Термінове замовлення!
(6, 5, 10, '2026-04-05', 1.00, 14000.00, FALSE, 'Заплановано'),
(6, 1, 3, '2026-04-02', 150.00, 28.00, FALSE, 'Заплановано');

-- Вставка платежів (payments)
-- Зауваження: тригер trg_register_payment автоматично оновить paid_amount та payment_status
INSERT INTO payments (payment_number, id_order, payment_date, payment_amount, payment_type, payer_name, receipt_code, processed_by_employee) VALUES
('ПЛАТ-2026/001', 1, '2026-03-02 11:30:00', 16650.00, 'Безготівковий розрахунок', 'ТОВ "Буд-Альянс Південь"', 'RC-2026-001', 4),
('ПЛАТ-2026/002', 2, '2026-03-04 14:15:00', 13600.00, 'Безготівковий розрахунок', 'ПрАТ "Одеський Винзавод Класик"', 'RC-2026-002', 4),
('ПЛАТ-2026/003', 3, '2026-03-06 10:00:00', 1615.00, 'Банківська картка', 'Ткаченко Василь Анатолійович', 'RC-2026-003', 5),
('ПЛАТ-2026/004', 4, '2026-03-11 16:40:00', 8000.00, 'Безготівковий розрахунок', 'Мережа клінік "Здоров''я Plus"', 'RC-2026-004', 4),
('ПЛАТ-2026/005', 5, '2026-03-13 09:20:00', 720.00, 'Готівка в касу', 'Мартиненко Павло Костянтинович', 'RC-2026-005', 5);


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
-- 9. УПРАВЛІННЯ КОРИСТУВАЧАМИ ТА ПРАВАМИ ДОСТУПУ (ROLES & GRANTS)
-- ============================================================================

-- Створення групових ролей
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_ad_manager') THEN
        CREATE ROLE role_ad_manager;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_accountant') THEN
        CREATE ROLE role_accountant;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_agency_admin') THEN
        CREATE ROLE role_agency_admin;
    END IF;
END $$;

-- Надання прав ролі Менеджера з реклами (role_ad_manager):
-- може переглядати довідники, вносити клієнтів, створювати заявки та позиції
GRANT SELECT ON publication_types, publications, ad_placements, ad_categories TO role_ad_manager;
GRANT SELECT, INSERT, UPDATE ON advertisers, contracts, ad_orders, order_items TO role_ad_manager;
GRANT SELECT ON v_active_ad_orders, v_publications_catalog TO role_ad_manager;
GRANT USAGE, SELECT ON SEQUENCE seq_advertisers, seq_contracts, seq_ad_orders, seq_order_items TO role_ad_manager;
GRANT EXECUTE ON FUNCTION fn_get_orders_by_date(DATE) TO role_ad_manager;
GRANT EXECUTE ON PROCEDURE sp_create_order_with_item TO role_ad_manager;

-- Надання прав ролі Бухгалтера (role_accountant):
-- може переглядати замовлення, формувати платежі та квитанції, контролювати боржників
GRANT SELECT ON advertisers, contracts, ad_orders, order_items, publications TO role_accountant;
GRANT SELECT, INSERT, UPDATE ON payments TO role_accountant;
GRANT SELECT ON v_debtors_report, v_active_ad_orders TO role_accountant;
GRANT USAGE, SELECT ON SEQUENCE seq_payments TO role_accountant;
GRANT EXECUTE ON FUNCTION fn_generate_receipt_data(INT) TO role_accountant;

-- Надання прав ролі Адміністратора агентства (role_agency_admin):
-- повний доступ до всіх об'єктів бази даних та аудиту
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_agency_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_agency_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO role_agency_admin;

-- Створення облікових записів конкретних співробітників (приклад)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'manager_shevchenko') THEN
        CREATE USER manager_shevchenko WITH PASSWORD 'ManagerPass2026!';
        GRANT role_ad_manager TO manager_shevchenko;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'accountant_kravchuk') THEN
        CREATE USER accountant_kravchuk WITH PASSWORD 'AccountPass2026!';
        GRANT role_accountant TO accountant_kravchuk;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_kovalenko') THEN
        CREATE USER admin_kovalenko WITH SUPERUSER PASSWORD 'AdminSuper2026!';
        GRANT role_agency_admin TO admin_kovalenko;
    END IF;
END $$;
