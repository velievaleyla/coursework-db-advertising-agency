-- ============================================================================
-- Модуль 0: Створення послідовностей та доменів з обмеженнями
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
