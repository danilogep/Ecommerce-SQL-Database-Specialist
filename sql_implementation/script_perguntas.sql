USE ecommerce;
SELECT 
    c.nome, 
    COUNT(p.id_pedido) AS total_pedidos 
FROM cliente c
INNER JOIN pedido p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente;

SELECT 
    p.id_pedido,
    c.nome AS cliente,
    p.status_pedido AS status_financeiro,
    e.status_entrega AS status_logistico,
    e.codigo_rastreio
FROM pedido p
JOIN cliente c ON p.id_cliente = c.id_cliente
LEFT JOIN entrega e ON p.id_pedido = e.id_pedido;

SELECT 
    c.nome,
    SUM(p.valor_total) AS total_gasto
FROM cliente c
JOIN pedido p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente
HAVING total_gasto > 4000;