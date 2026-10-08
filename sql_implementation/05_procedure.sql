-- Charset explicito na conexao. O entrypoint do container mysql executa os
-- scripts com o cliente nos padroes dele; sem esta linha, um arquivo UTF-8
-- e lido como latin1 e 'Moveis' entra no banco como 'MA3veis'.
SET NAMES utf8mb4;
USE ecommerce;

-- ==============================================================================
-- PARTE 2: STORED PROCEDURES (Manipulação de Dados)
-- ==============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS gerenciar_cliente $$

CREATE PROCEDURE gerenciar_cliente(
    IN p_opcao INT,              -- Variável de Controle: 1=Insert, 2=Update, 3=Delete
    IN p_id_cliente INT,         -- ID do cliente (usado em Update e Delete)
    IN p_nome VARCHAR(45),       -- Dados para Insert/Update
    IN p_endereco VARCHAR(255),
    IN p_email VARCHAR(45)
)
BEGIN
    -- OPÇÃO 1: INSERT (Inserir novo cliente)
    IF p_opcao = 1 THEN
        INSERT INTO cliente (nome, endereco, email) 
        VALUES (p_nome, p_endereco, p_email);
        
        SELECT 'Cliente inserido com sucesso!' AS Mensagem, LAST_INSERT_ID() as Novo_ID;

    -- OPÇÃO 2: UPDATE (Atualizar dados)
    ELSEIF p_opcao = 2 THEN
        UPDATE cliente 
        SET nome = p_nome, 
            endereco = p_endereco, 
            email = p_email 
        WHERE id_cliente = p_id_cliente;
        
        SELECT CONCAT('Cliente ID ', p_id_cliente, ' atualizado com sucesso!') AS Mensagem;

    -- OPÇÃO 3: DELETE (Remover cliente)
    ELSEIF p_opcao = 3 THEN
        DELETE FROM cliente WHERE id_cliente = p_id_cliente;
        
        SELECT CONCAT('Cliente ID ', p_id_cliente, ' removido com sucesso!') AS Mensagem;

    -- Tratamento de Erro para opção inválida
    ELSE
        SELECT 'Opção Inválida! Use: 1-Insert, 2-Update, 3-Delete' AS Erro;
    END IF;
END $$

DELIMITER ;

-- ==============================================================================
-- TESTES DA PROCEDURE
-- ==============================================================================

-- O teste trabalha sobre um cliente criado aqui mesmo, capturado em @id. Fixar
-- um ID na mao (era 4) quebra assim que o banco tem volume: o cliente 4 passa a
-- ter pedidos e o DELETE esbarra na chave estrangeira.

-- 1. Insercao (opcao 1) -> ID nulo porque a coluna e AUTO_INCREMENT
CALL gerenciar_cliente(1, NULL, 'Cliente Teste Procedure', 'Rua Procedure, 99', 'teste@proc.com');
SET @id = LAST_INSERT_ID();

-- 2. Atualizacao (opcao 2) sobre o cliente recem-criado
CALL gerenciar_cliente(2, @id, 'Cliente Teste ATUALIZADO', 'Rua Nova, 100', 'novo@proc.com');
SELECT id_cliente, nome, email FROM cliente WHERE id_cliente = @id;

-- 3. Delecao (opcao 3). Como o cliente nao tem pedidos, nao ha FK no caminho.
--    Depois que 06_triggers.sql rodar, esta mesma delecao passa a deixar rastro
--    em cliente_backup.
CALL gerenciar_cliente(3, @id, NULL, NULL, NULL);