-- ============================================================================
-- Модуль 7: Керування користувачами та ролями доступу (DCL)
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
