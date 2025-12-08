USE ecommerce;

-- ==============================================================================
-- PARTE 1: ÍNDICES (Otimização de Performance)
-- ==============================================================================
-- O objetivo aqui é criar índices baseados nas consultas mais frequentes e críticas.

-- ------------------------------------------------------------------------------
-- PERGUNTA DE NEGÓCIO 1: Qual o cliente com maior número de pedidos?
-- Contexto: Essa consulta realiza um JOIN entre 'cliente' e 'pedido' e agrupa dados.
-- ------------------------------------------------------------------------------

-- Query de consulta para análise:
SELECT c.nome, COUNT(p.id_pedido) as total 
FROM cliente c 
INNER JOIN pedido p ON c.id_cliente = p.id_cliente 
GROUP BY c.id_cliente;

-- CRIAÇÃO DO ÍNDICE 1
-- Tabela: pedido
-- Coluna: id_cliente
-- Tipo de Índice: B-Tree (Padrão do MySQL)
-- Motivo: Como a tabela 'pedido' cresce muito, o JOIN pelo 'id_cliente' se torna lento. 
-- O índice B-Tree agiliza a junção de chaves estrangeiras, evitando Full Table Scan.
CREATE INDEX idx_pedido_cliente ON pedido(id_cliente);


-- ------------------------------------------------------------------------------
-- PERGUNTA DE NEGÓCIO 2: Quais são os produtos de uma determinada categoria?
-- Contexto: Filtrar produtos onde a coluna 'categoria' é igual a um valor específico.
-- ------------------------------------------------------------------------------

-- Query de consulta para análise:
SELECT * FROM produto WHERE categoria = 'Móveis';

-- CRIAÇÃO DO ÍNDICE 2
-- Tabela: produto
-- Coluna: categoria
-- Tipo de Índice: Hash (Idealmente) ou B-Tree (No InnoDB MySQL)
-- Motivo: A busca por igualdade (=) em colunas de texto (como categorias) é drasticamente 
-- acelerada por índices, evitando que o banco leia linha por linha para achar "Móveis".
CREATE INDEX idx_produto_categoria ON produto(categoria);


-- ------------------------------------------------------------------------------
-- PERGUNTA DE NEGÓCIO 3: Relação de Entregas por Status
-- Contexto: Relatórios operacionais que agrupam entregas.
-- ------------------------------------------------------------------------------

-- Query de consulta para análise:
SELECT status_entrega, COUNT(*) FROM entrega GROUP BY status_entrega;

-- CRIAÇÃO DO ÍNDICE 3
-- Tabela: entrega
-- Coluna: status_entrega
-- Tipo de Índice: B-Tree
-- Motivo: Índices em colunas usadas em GROUP BY e ORDER BY permitem que o banco já recupere 
-- os dados organizados, sem gastar processamento extra ordenando o resultado final.
CREATE INDEX idx_entrega_status ON entrega(status_entrega);