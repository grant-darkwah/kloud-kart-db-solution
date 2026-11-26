-- ============================================================
-- Stage 3: Prevent Overselling
-- Migration: 001_prevent_overselling.sql
-- ============================================================

-- 1. Create sequences for tables without automatic ID generation.

CREATE SEQUENCE IF NOT EXISTS public.orders_order_id_seq AS integer;

CREATE SEQUENCE IF NOT EXISTS public.order_items_order_item_id_seq AS integer;

CREATE SEQUENCE IF NOT EXISTS public.inventory_log_log_id_seq AS integer;


-- 2. Initialise sequences above existing maximum IDs.
-- GREATEST prevents an existing sequence from moving backwards
-- if this migration is executed again.

SELECT setval(
    'public.orders_order_id_seq',
    GREATEST(
        COALESCE((SELECT MAX(order_id)::bigint FROM public.orders), 0),
        (SELECT last_value::bigint FROM public.orders_order_id_seq)
    ),
    true
);

SELECT setval(
    'public.order_items_order_item_id_seq',
    GREATEST(
        COALESCE((SELECT MAX(order_item_id)::bigint FROM public.order_items), 0),
        (SELECT last_value::bigint FROM public.order_items_order_item_id_seq)
    ),
    true
);

SELECT setval(
    'public.inventory_log_log_id_seq',
    GREATEST(
        COALESCE((SELECT MAX(log_id)::bigint FROM public.inventory_log), 0),
        (SELECT last_value::bigint FROM public.inventory_log_log_id_seq)
    ),
    true
);


-- 3. Create the atomic order-placement function.

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

    -- Atomically reserve stock.
    -- PostgreSQL locks the product row during this update.
    -- Concurrent calls must wait and re-evaluate the condition.

    UPDATE public.products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = p_product_id
      AND stock_quantity >= p_quantity
      AND price IS NOT NULL
    RETURNING price INTO v_unit_price;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT false, NULL::bigint,
               'Out of stock or product unavailable'::text;
        RETURN;
    END IF;

    -- Create the order.
    v_order_id := nextval('public.orders_order_id_seq');

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

    -- Record the inventory movement.
    INSERT INTO public.inventory_log (
        log_id,
        product_id,
        change_qty,
        reason,
        created_at,
        note
    )
    VALUES (
        nextval('public.inventory_log_log_id_seq'),
        p_product_id,
        -p_quantity,
        'sale',
        CURRENT_TIMESTAMP,
        'Order ' || v_order_id
    );

    -- Return successful result.
    RETURN QUERY
    SELECT true, v_order_id::bigint, 'Order placed successfully'::text;

END;
$$;