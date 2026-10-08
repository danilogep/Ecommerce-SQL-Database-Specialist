USE ecommerce;

-- ==============================================================================
-- PARTE 3.1: VIEWS (Visões Personalizadas)
-- ==============================================================================

-- 1. CENÁRIO: Número de Clientes por Localidade
-- (Adaptado de: Empregados por departamento e localidade)
CREATE OR REPLACE VIEW vw_clientes_por_localidade AS
SELECT 
    endereco, 
    COUNT(*) as total_clientes
FROM cliente
GROUP BY endereco;

-- 2. CENÁRIO: Lista de Fornecedores e seus Produtos
-- (Adaptado de: Lista de departamentos e seus gerentes)
CREATE OR REPLACE VIEW vw_produtos_fornecedores AS
SELECT 
    f.razao_social AS Fornecedor,
    p.descricao AS Produto,
    p.valor
FROM fornecedor f
INNER JOIN produto_fornecedor pf ON f.id_fornecedor = pf.id_fornecedor
INNER JOIN produto p ON pf.id_produto = p.id_produto;

-- 3. CENÁRIO: Produtos com maior saída (Estoque/Vendas)
-- (Adaptado de: Projetos com maior número de empregados)
CREATE OR REPLACE VIEW vw_produtos_mais_vendidos AS
SELECT 
    p.categoria,
    p.descricao,
    SUM(pp.quantidade) as total_vendido
FROM produto p
INNER JOIN produto_pedido pp ON p.id_produto = pp.id_produto
GROUP BY p.id_produto
ORDER BY total_vendido DESC;

-- 4. CENÁRIO: Relatório Detalhado de Pedidos
-- (Adaptado de: Lista de projetos, departamentos e gerentes)
CREATE OR REPLACE VIEW vw_relatorio_pedidos AS
SELECT 
    c.nome AS Cliente,
    p.id_pedido,
    p.status_pedido,
    e.status_entrega,
    pag.tipo_pagamento
FROM pedido p
JOIN cliente c ON p.id_cliente = c.id_cliente
LEFT JOIN entrega e ON p.id_pedido = e.id_pedido
LEFT JOIN pagamento pag ON p.id_pedido = pag.id_pedido;


-- ==============================================================================
-- PARTE 3.2: PERMISSÕES DE ACESSO (DCL)
-- ==============================================================================

-- Criando usuários (Exemplo local)
CREATE USER IF NOT EXISTS 'gerente'@'localhost' IDENTIFIED BY 'senha_forte_123';
CREATE USER IF NOT EXISTS 'funcionario_logistica'@'localhost' IDENTIFIED BY 'senha_basica_123';

-- PERMISSÕES DO GERENTE
-- O Gerente tem acesso total às views de relatórios de vendas e fornecedores
GRANT SELECT ON ecommerce.vw_relatorio_pedidos TO 'gerente'@'localhost';
GRANT SELECT ON ecommerce.vw_produtos_mais_vendidos TO 'gerente'@'localhost';
GRANT SELECT ON ecommerce.vw_produtos_fornecedores TO 'gerente'@'localhost';

-- PERMISSÕES DO FUNCIONÁRIO (Logística)
-- O Funcionário deve ver apenas de onde são os clientes para planejar rotas, 
-- mas NÃO deve ver quanto a empresa vendeu ou fornecedores.
GRANT SELECT ON ecommerce.vw_clientes_por_localidade TO 'funcionario_logistica'@'localhost';

-- O acesso a vw_produtos_mais_vendidos simplesmente nao e concedido a este
-- usuario. Um REVOKE aqui falharia com o erro 1147 ("no such grant defined"):
-- o MySQL recusa revogar um privilegio que nunca foi dado. Privilegio minimo
-- se faz por omissao, nao por revogacao.

-- Conferencia do que cada usuario enxerga:
SHOW GRANTS FOR 'gerente'@'localhost';
SHOW GRANTS FOR 'funcionario_logistica'@'localhost';

FLUSH PRIVILEGES;