-- ============================================================
-- Stage 7: Leave the Trail
-- Migration: 002_inventory_audit_trail.sql
-- Purpose: Enforce an auditable inventory movement history.
-- Database: kloudkart_test
--
-- Design:
--   1. Capture stock changes automatically.
--   2. Record before/after stock quantities.
--   3. Record the database session actor.
--   4. Support transaction references.
--   5. Preserve existing historical records.
--   6. Prevent modification of historical audit records.
--
-- Important:
--   All stock changes and audit inserts occur in the same
--   database transaction.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Extend the existing inventory log
-- ============================================================

ALTER TABLE public.inventory_log
    ADD COLUMN quantity_before integer,
    ADD COLUMN quantity_after integer,
    ADD COLUMN actor text,
    ADD COLUMN reference_type text,
    ADD COLUMN reference_id text;

-- Historical records retain NULL audit metadata because
-- their original values cannot reliably be reconstructed.

-- Enforce complete stock balances for new audit records.
ALTER TABLE public.inventory_log
    ADD CONSTRAINT inventory_log_balance_check
    CHECK (
        product_id IS NOT NULL
        AND change_qty IS NOT NULL
        AND reason IS NOT NULL
        AND BTRIM(reason) <> ''
        AND created_at IS NOT NULL
        AND quantity_before IS NOT NULL
        AND quantity_after IS NOT NULL
        AND quantity_after - quantity_before = change_qty
    ) NOT VALID;

-- Require an actor for new audit records.
ALTER TABLE public.inventory_log
    ADD CONSTRAINT inventory_log_actor_check
    CHECK (actor IS NOT NULL) NOT VALID;

-- Existing orphan references are preserved.
-- New inventory log records must reference valid products.
ALTER TABLE public.inventory_log
    ADD CONSTRAINT inventory_log_product_fk
    FOREIGN KEY (product_id)
    REFERENCES public.products(product_id)
    NOT VALID;


-- ============================================================
-- 2. Prevent modification of historical audit records
-- ============================================================

CREATE OR REPLACE FUNCTION public.prevent_inventory_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Inventory audit records are append-only. Record a compensating movement instead.';
END;
$$;

CREATE TRIGGER inventory_log_append_only
BEFORE UPDATE OR DELETE
ON public.inventory_log
FOR EACH ROW
EXECUTE FUNCTION public.prevent_inventory_log_mutation();


-- ============================================================
-- 3. Automatically capture product stock changes
-- ============================================================

CREATE OR REPLACE FUNCTION public.capture_inventory_audit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_reason text;
    v_reference_type text;
    v_reference_id text;
    v_change_qty integer;
    v_note text;
BEGIN

    -- Ignore updates that do not change stock.
    IF NEW.stock_quantity IS NOT DISTINCT FROM OLD.stock_quantity THEN
        RETURN NEW;
    END IF;

    -- Stock balances must be known for an auditable movement.
    IF OLD.stock_quantity IS NULL OR NEW.stock_quantity IS NULL THEN
        RAISE EXCEPTION
            'Inventory stock cannot be changed to or from NULL.';
    END IF;

    v_change_qty := NEW.stock_quantity - OLD.stock_quantity;

    -- Read transaction-local movement context.
    -- Unclassified direct stock changes are recorded as
    -- manual adjustments.
    v_reason := COALESCE(
        NULLIF(
            current_setting('kloudkart.audit_reason', true),
            ''
        ),
        'manual_adjustment'
    );

    v_reference_type := NULLIF(
        current_setting('kloudkart.audit_reference_type', true),
        ''
    );

    v_reference_id := NULLIF(
        current_setting('kloudkart.audit_reference_id', true),
        ''
    );

    IF v_reference_type IS NOT NULL
       AND v_reference_id IS NOT NULL THEN
        v_note := INITCAP(v_reference_type) || ' ' || v_reference_id;
    ELSE
        v_note := NULL;
    END IF;

    -- Insert the audit record in the same transaction
    -- as the product stock update.
    INSERT INTO public.inventory_log (
        log_id,
        product_id,
        change_qty,
        reason,
        created_at,
        note,
        quantity_before,
        quantity_after,
        actor,
        reference_type,
        reference_id
    )
    VALUES (
        nextval('public.inventory_log_log_id_seq'),
        NEW.product_id,
        v_change_qty,
        v_reason,
        CURRENT_TIMESTAMP,
        v_note,
        OLD.stock_quantity,
        NEW.stock_quantity,
        SESSION_USER::text,
        v_reference_type,
        v_reference_id
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER products_inventory_audit
AFTER UPDATE OF stock_quantity
ON public.products
FOR EACH ROW
WHEN (OLD.stock_quantity IS DISTINCT FROM NEW.stock_quantity)
EXECUTE FUNCTION public.capture_inventory_audit();


-- ============================================================
-- 4. Update the atomic order-placement function
-- ============================================================

CREATE OR REPLACE FUNCTION public.place_order(
    p_customer_id bigint,
    p_product_id bigint,
    p_quantity integer
)
RETURNS TABLE (
    success boolean,
    order_id bigint,
    message text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_unit_price numeric(12,2);
    v_order_id integer;
    v_stock_updated boolean;

    v_previous_reason text;
    v_previous_reference_type text;
    v_previous_reference_id text;
BEGIN

    -- Validate quantity.
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RETURN QUERY
        SELECT false, NULL::bigint, 'Invalid quantity'::text;
        RETURN;
    END IF;

    -- Validate customer.
    PERFORM 1
    FROM public.customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT false, NULL::bigint, 'Customer not found'::text;
        RETURN;
    END IF;

    -- Allocate the order ID before updating stock so that
    -- the audit trigger can capture the order reference.
    v_order_id := nextval('public.orders_order_id_seq');

    -- Preserve any existing transaction-local audit context.
    v_previous_reason :=
        current_setting('kloudkart.audit_reason', true);

    v_previous_reference_type :=
        current_setting('kloudkart.audit_reference_type', true);

    v_previous_reference_id :=
        current_setting('kloudkart.audit_reference_id', true);

    -- Establish the audit context for this sale.
    PERFORM set_config(
        'kloudkart.audit_reason',
        'sale',
        true
    );

    PERFORM set_config(
        'kloudkart.audit_reference_type',
        'order',
        true
    );

    PERFORM set_config(
        'kloudkart.audit_reference_id',
        v_order_id::text,
        true
    );

    -- Atomically reserve stock.
    -- The AFTER UPDATE trigger automatically records the movement.
    UPDATE public.products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = p_product_id
      AND stock_quantity >= p_quantity
      AND price IS NOT NULL
    RETURNING price INTO v_unit_price;

    -- Preserve the UPDATE result before other statements change FOUND.
    v_stock_updated := FOUND;

    -- Restore the previous transaction-local audit context.
    PERFORM set_config(
        'kloudkart.audit_reason',
        COALESCE(v_previous_reason, ''),
        true
    );

    PERFORM set_config(
        'kloudkart.audit_reference_type',
        COALESCE(v_previous_reference_type, ''),
        true
    );

    PERFORM set_config(
        'kloudkart.audit_reference_id',
        COALESCE(v_previous_reference_id, ''),
        true
    );

    IF NOT v_stock_updated THEN
        RETURN QUERY
        SELECT false, NULL::bigint,
               'Out of stock or product unavailable'::text;
        RETURN;
    END IF;

    -- Create the order.
    INSERT INTO public.orders (
        order_id,
        customer_id,
        order_date,
        status,
        total_amount
    )
    VALUES (
        v_order_id,
        p_customer_id,
        CURRENT_TIMESTAMP,
        'placed',
        v_unit_price * p_quantity
    );

    -- Create the order item.
    INSERT INTO public.order_items (
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price
    )
    VALUES (
        nextval('public.order_items_order_item_id_seq'),
        v_order_id,
        p_product_id,
        p_quantity,
        v_unit_price
    );

    -- No manual inventory_log INSERT is needed.
    -- The products_inventory_audit trigger records the sale.

    RETURN QUERY
    SELECT true, v_order_id::bigint,
           'Order placed successfully'::text;

END;
$$;

COMMIT;
