SELECT id, payment_status, total, payment_method
FROM orders
WHERE id = 'Obd696b9c67dd4bacb9f3b181ed4c984';

SELECT *
FROM payment_transactions
WHERE order_id = 'Obd696b9c67dd4bacb9f3b181ed4c984';

SELECT
    merchant_trade_no,
    status,
    rtn_code,
    rtn_msg,
    paid_at,
    updated_at
FROM payment_transactions
WHERE merchant_trade_no = 'YRC2607221636579280';