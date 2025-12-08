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

-- 1. Testando Inserção (Opção 1) -> Passamos NULL no ID pois é Auto Increment
CALL gerenciar_cliente(1, NULL, 'Cliente Teste Procedure', 'Rua Procedure, 99', 'teste@proc.com');

-- 2. Testando Atualização (Opção 2) -> Vamos atualizar o cliente que acabamos de criar (supondo que seja o ID 4 ou o último criado)
-- (Verifique o ID criado no passo anterior e substitua abaixo se necessário)
CALL gerenciar_cliente(2, 4, 'Cliente Teste ATUALIZADO', 'Rua Nova, 100', 'novo@proc.com');

-- 3. Testando Deleção (Opção 3)
CALL gerenciar_cliente(3, 4, NULL, NULL, NULL);