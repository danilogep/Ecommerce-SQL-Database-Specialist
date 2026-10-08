-- =============================================================================
-- 02_seed_massa.sql — massa de volume realista
-- =============================================================================
-- Gera 20 mil clientes, 50 mil produtos, 100 mil pedidos, ~250 mil itens e as
-- entregas e pagamentos correspondentes.
--
-- Por que 100 mil pedidos e não 20 linhas: com tabela pequena o otimizador do
-- MySQL ignora o índice e faz full scan — ler 20 linhas sequencialmente é mais
-- barato que percorrer uma B-Tree. O ganho do índice só aparece quando a tabela
-- não cabe num piscar de olhos, e é esse o ponto que o benchmark precisa provar.
--
-- Pré-requisito: 01_tabelas.sql já executado.
-- Uso:  mysql -u root -p ecommerce < sql_implementation/02_seed_massa.sql
-- Tempo: ~30–60 s em um MySQL 8 local.
-- =============================================================================

-- Charset explicito na conexao. O entrypoint do container mysql executa os
-- scripts com o cliente nos padroes dele; sem esta linha, um arquivo UTF-8
-- e lido como latin1 e 'Moveis' entra no banco como 'MA3veis'.
SET NAMES utf8mb4;
USE ecommerce;

-- Carga em massa: desligar checagens e autocommit reduz o tempo em ordens de
-- grandeza. São religados no fim do script.
SET @old_fk = @@foreign_key_checks, @old_uc = @@unique_checks, @old_ac = @@autocommit;
SET foreign_key_checks = 0, unique_checks = 0, autocommit = 0;

-- -----------------------------------------------------------------------------
-- Tabela auxiliar de números: 0..999999, montada por cross join.
-- Mais rápida que CTE recursiva nesta ordem de grandeza e não esbarra em
-- cte_max_recursion_depth (1000 por padrão).
-- -----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS numeros;
-- InnoDB e não MEMORY: uma tabela MEMORY com 100 mil linhas estoura
-- max_heap_table_size (16 MB por padrão) e o insert falha com "table is full".
CREATE TEMPORARY TABLE numeros (n INT PRIMARY KEY) ENGINE = InnoDB;

INSERT INTO numeros (n)
SELECT d0.d + d1.d * 10 + d2.d * 100 + d3.d * 1000 + d4.d * 10000
FROM   (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d0
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d1
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d2
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d3
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d4;
COMMIT;

-- Limpa o que existir, na ordem das dependências.
DELETE FROM produto_pedido;
DELETE FROM estoque_produto;
DELETE FROM produto_fornecedor;
DELETE FROM pagamento;
DELETE FROM entrega;
DELETE FROM pedido;
DELETE FROM pessoa_fisica;
DELETE FROM pessoa_juridica;
DELETE FROM cliente;
DELETE FROM produto;
COMMIT;

-- -----------------------------------------------------------------------------
-- Clientes: 20.000
-- -----------------------------------------------------------------------------
INSERT INTO cliente (id_cliente, nome, endereco, email)
SELECT n + 1,
       CONCAT('Cliente ', n + 1),
       CONCAT('Rua ', 1 + (n % 900), ', nº ', 1 + (n % 2000), ' - Cidade ', 1 + (n % 120)),
       CONCAT('cliente', n + 1, '@exemplo.com.br')
FROM numeros WHERE n < 20000;
COMMIT;

-- 70% pessoa física, 30% jurídica — a herança do modelo precisa ter as duas
-- pernas populadas para que as consultas sobre especialização façam sentido.
INSERT INTO pessoa_fisica (id_cliente, cpf, rg, nascimento)
SELECT n + 1,
       LPAD(n + 1, 11, '0'),
       LPAD(n + 1, 9, '0'),
       DATE_SUB('2006-01-01', INTERVAL (n % 18000) DAY)
FROM numeros WHERE n < 14000;

INSERT INTO pessoa_juridica (id_cliente, cnpj, razao_social, nome_fantasia)
SELECT n + 1,
       LPAD(n + 1, 14, '0'),
       CONCAT('Empresa ', n + 1, ' LTDA'),
       CONCAT('Marca ', n + 1)
FROM numeros WHERE n >= 14000 AND n < 20000;
COMMIT;

-- -----------------------------------------------------------------------------
-- Produtos: 50.000, distribuídos em 10 categorias
-- -----------------------------------------------------------------------------
INSERT INTO produto (id_produto, categoria, descricao, valor)
SELECT n + 1,
       ELT(1 + (n % 10), 'Móveis', 'Eletrônicos', 'Informática', 'Vestuário', 'Alimentos',
                          'Livros', 'Brinquedos', 'Esporte', 'Beleza', 'Automotivo'),
       CONCAT('Produto ', n + 1),
       ROUND(10 + (n % 4990) + RAND(42) * 10, 2)
FROM numeros WHERE n < 50000;
COMMIT;

-- -----------------------------------------------------------------------------
-- Pedidos: 100.000
-- -----------------------------------------------------------------------------
-- A distribuição de pedidos por cliente é deliberadamente desigual (`n % 7919`,
-- primo): sem isso, todo cliente teria exatamente 5 pedidos e a consulta "quem
-- mais comprou" devolveria um empate de 20 mil linhas, sem valor de teste.
INSERT INTO pedido (id_pedido, id_cliente, status_pedido, descricao, frete, valor_total)
SELECT n + 1,
       1 + (n % 7919),
       ELT(1 + (n % 4), 'Em andamento', 'Processando', 'Enviado', 'Entregue'),
       CONCAT('Pedido ', n + 1),
       ROUND(5 + (n % 60), 2),
       ROUND(50 + (n % 9950), 2)
FROM numeros WHERE n < 100000;
COMMIT;

-- -----------------------------------------------------------------------------
-- Itens do pedido: 2 a 3 produtos por pedido (~250 mil linhas)
-- -----------------------------------------------------------------------------
INSERT INTO produto_pedido (id_pedido, id_produto, quantidade, status)
SELECT p.id_pedido,
       1 + ((p.id_pedido * k.k) % 50000),
       1 + (p.id_pedido % 5),
       'Disponível'
FROM pedido p
CROSS JOIN (SELECT 1 k UNION ALL SELECT 2 UNION ALL SELECT 3) k
WHERE k.k <= 2 + (p.id_pedido % 2)
ON DUPLICATE KEY UPDATE quantidade = produto_pedido.quantidade;
COMMIT;

-- -----------------------------------------------------------------------------
-- Entregas: uma por pedido
-- -----------------------------------------------------------------------------
-- Cinco status com frequências bem diferentes: num GROUP BY, distribuição
-- uniforme esconde o custo real da leitura.
INSERT INTO entrega (id_entrega, id_pedido, codigo_rastreio, status_entrega, data_previsao)
SELECT p.id_pedido,
       p.id_pedido,
       CONCAT('BR', LPAD(p.id_pedido, 9, '0'), 'XX'),
       ELT(1 + (p.id_pedido % 10),
           'Entregue', 'Entregue', 'Entregue', 'Entregue', 'Entregue',
           'Em trânsito', 'Em trânsito', 'Saiu para entrega',
           'Aguardando coleta', 'Devolvido'),
       DATE_ADD('2025-01-01', INTERVAL (p.id_pedido % 365) DAY)
FROM pedido p;
COMMIT;

-- -----------------------------------------------------------------------------
-- Pagamentos: 1 ou 2 por pedido (o modelo permite N formas por pedido)
-- -----------------------------------------------------------------------------
INSERT INTO pagamento (id_pedido, tipo_pagamento, valor, status)
SELECT p.id_pedido,
       ELT(1 + (p.id_pedido % 3), 'Boleto', 'Cartão', 'Pix'),
       p.valor_total,
       'Aprovado'
FROM pedido p;

INSERT INTO pagamento (id_pedido, tipo_pagamento, valor, status)
SELECT p.id_pedido,
       'Pix',
       ROUND(p.frete, 2),
       'Aprovado'
FROM pedido p
WHERE p.id_pedido % 5 = 0;
COMMIT;

-- -----------------------------------------------------------------------------
-- Fornecedores, estoques e seus vínculos
-- -----------------------------------------------------------------------------
INSERT INTO fornecedor (id_fornecedor, razao_social, cnpj)
SELECT n + 1, CONCAT('Fornecedor ', n + 1, ' S.A.'), LPAD(900000000 + n, 14, '0')
FROM numeros WHERE n < 50
ON DUPLICATE KEY UPDATE razao_social = VALUES(razao_social);

INSERT INTO estoque (id_estoque, local)
SELECT n + 1, CONCAT('CD ', ELT(1 + (n % 5), 'Sudeste', 'Sul', 'Nordeste', 'Norte', 'Centro-Oeste'))
FROM numeros WHERE n < 5
ON DUPLICATE KEY UPDATE local = VALUES(local);
COMMIT;

INSERT INTO produto_fornecedor (id_fornecedor, id_produto)
SELECT 1 + (p.id_produto % 50), p.id_produto FROM produto p;

INSERT INTO estoque_produto (id_estoque, id_produto, quantidade)
SELECT 1 + (p.id_produto % 5), p.id_produto, 10 + (p.id_produto % 500) FROM produto p;
COMMIT;

SET foreign_key_checks = @old_fk, unique_checks = @old_uc, autocommit = @old_ac;

-- Sem ANALYZE o otimizador trabalha com estatísticas da tabela vazia e pode
-- escolher o plano errado logo após a carga — o que falsearia o benchmark.
ANALYZE TABLE cliente, pedido, produto, produto_pedido, entrega, pagamento;

DROP TEMPORARY TABLE IF EXISTS numeros;

SELECT 'clientes'        AS tabela, COUNT(*) AS linhas FROM cliente
UNION ALL SELECT 'produtos',        COUNT(*) FROM produto
UNION ALL SELECT 'pedidos',         COUNT(*) FROM pedido
UNION ALL SELECT 'itens de pedido', COUNT(*) FROM produto_pedido
UNION ALL SELECT 'entregas',        COUNT(*) FROM entrega
UNION ALL SELECT 'pagamentos',      COUNT(*) FROM pagamento;
