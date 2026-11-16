-- ============================================================================
-- Модуль 8: Дослідження та оптимізація планів виконання SQL-запитів
-- Розроблено на основі матеріалів Лекції 16 «Огляд процесів виконання 
-- SQL-запитів на прикладі СУБД PostgreSQL» (доц. Блажко О. А.)
-- Студентка: Велієва Л. А., група АІ-253
-- ============================================================================

-- ВСТУП ДО ПРОЦЕСУ ВИКОНАННЯ SQL-ЗАПИТУ В POSTGRESQL:
-- Кожен запит проходить 4 ключові етапи:
-- 1. Parser (Синтаксичний аналізатор) - перевірка граматики та побудова Parse Tree.
-- 2. Rewriter (Перетворювач запиту) - розгортання правил, представлень (Views) 
--    та приведення до канонічного дерева логічного плану (реляційної алгебри).
-- 3. Planner / Optimizer (Планувальник / Оптимізатор) - генерує можливі фізичні 
--    шляхи виконання (paths) та обирає план з мінімальною вартістю (Cost).
-- 4. Executor (Виконавець) - рекурсивно виконує вузли плану в оперативній пам'яті 
--    (shared_buffers, work_mem) та повертає результат клієнту.

-- ============================================================================
-- 8.1. АНАЛІЗ БАЗОВОГО ЗАПИТУ ВИБІРКИ ЗА ДІАПАЗОНОМ ДАТ (EXPLAIN / EXPLAIN ANALYZE)
-- ============================================================================

-- Запит: Знайти всі замовлення за 1 квартал 2026 року зі статусом 'Виконано'
-- Команда EXPLAIN показує оціночну вартість (cost=startup..total, rows, width)
EXPLAIN (COSTS, VERBOSE)
SELECT order_id, order_number, client_id, total_amount, order_status
FROM ad_orders
WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
  AND order_status = 'Виконано';

-- Команда EXPLAIN ANALYZE фактично виконує запит і вимірює реальний час (actual time) та кількість рядків:
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, order_number, client_id, total_amount, order_status
FROM ad_orders
WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
  AND order_status = 'Виконано';

-- ============================================================================
-- 8.2. СТВОРЕННЯ ІНДЕКСІВ ТА ПОРІВНЯННЯ МЕТОДІВ СКАНУВАННЯ
-- ============================================================================

-- Створення B-Tree індексів для оптимізації фільтрації:
CREATE INDEX IF NOT EXISTS idx_ad_orders_date_status ON ad_orders(order_date, order_status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_fk ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_placement_fk ON order_items(placement_id);

-- Збір актуальної статистики для планувальника:
VACUUM ANALYZE ad_orders;
VACUUM ANALYZE order_items;

-- Повторний аналіз плану: планувальник обирає Index Scan або Bitmap Index Scan замість Seq Scan:
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_number, client_id, total_amount, order_status
FROM ad_orders
WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
  AND order_status = 'Виконано';

-- ============================================================================
-- 8.3. ДОСЛІДЖЕННЯ МЕТОДІВ З'ЄДНАННЯ ТАБЛИЦЬ (JOIN METHODS)
-- ============================================================================
-- PostgreSQL підтримує три основні алгоритми з'єднання:
-- 1) Hash Join — побудова геш-таблиці за внутрішньою таблицею та одноразове сканування зовнішньої;
-- 2) Merge Join — з'єднання двох попередньо відсортованих наборів даних;
-- 3) Nested Loop — вкладений цикл (ефективний для малих вибірок або з індексним доступом).

-- Запит багатотабличного з'єднання: Рекламодавці -> Замовлення -> Позиції -> Місця розміщення -> Видання
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    adv.company_name,
    ord.order_number,
    pub.pub_name,
    plc.placement_name,
    oi.final_price
FROM advertisers adv
JOIN ad_orders ord ON adv.client_id = ord.client_id
JOIN order_items oi ON ord.order_id = oi.order_id
JOIN ad_placements plc ON oi.placement_id = plc.placement_id
JOIN publications pub ON plc.pub_id = pub.pub_id
WHERE ord.payment_status = 'Оплачено';

-- ============================================================================
-- 8.4. КЕРУВАННЯ ПОВЕДІНКОЮ ОПТИМІЗАТОРА (OPTIMIZER SWITCHES)
-- ============================================================================
-- Демонстрація примусової зміни плану оптимізатора через параметри сесії,
-- розглянуті в Лекції 16:

-- 1) Примусова заборона послідовного сканування (змушує оптимізатор шукати індекси):
SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT * FROM ad_orders WHERE order_date >= '2026-02-01';

RESET enable_seqscan;

-- 2) Примусова заборона Hash Join (змушує використати Merge Join або Nested Loop):
SET enable_hashjoin = off;

EXPLAIN ANALYZE
SELECT adv.company_name, ord.order_number, ord.total_amount
FROM advertisers adv
JOIN ad_orders ord ON adv.client_id = ord.client_id;

RESET enable_hashjoin;

-- 3) Примусова заборона Merge Join:
SET enable_mergejoin = off;

EXPLAIN ANALYZE
SELECT adv.company_name, ord.order_number, ord.total_amount
FROM advertisers adv
JOIN ad_orders ord ON adv.client_id = ord.client_id;

RESET enable_mergejoin;

-- ============================================================================
-- 8.5. ПЕРЕВІРКА СТАТИСТИКИ ОПТИМІЗАТОРА У СИСТЕМНОМУ КАТАЛОЗІ
-- ============================================================================
-- Перегляд зібраної статистики про розподіл значень стовпців у pg_stats:
SELECT 
    schemaname, 
    tablename, 
    attname, 
    null_frac, 
    avg_width, 
    n_distinct, 
    correlation
FROM pg_stats
WHERE tablename IN ('ad_orders', 'order_items', 'advertisers')
ORDER BY tablename, attname;
