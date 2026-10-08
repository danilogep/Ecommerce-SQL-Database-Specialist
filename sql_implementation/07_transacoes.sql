-- Charset explicito na conexao. O entrypoint do container mysql executa os
-- scripts com o cliente nos padroes dele; sem esta linha, um arquivo UTF-8
-- e lido como latin1 e 'Moveis' entra no banco como 'MA3veis'.
SET NAMES utf8mb4;
USE ecommerce;

-- ==============================================================================
-- PARTE 1: TRANSAÇÕES (Statements Simples)
-- ==============================================================================
-- Cenário: Atualização de status de pedido e inserção de rastreio.
-- Regra: Ou faz tudo (atualiza status e cria entrega), ou não faz nada.

-- 1. Desabilitar o Autocommit (Padrão do MySQL é 1)
SET autocommit = 0;

-- 2. Iniciar a Transação
START TRANSACTION;

-- Passo A: Atualizar o status do pedido para 'Enviado'
UPDATE pedido SET status_pedido = 'Enviado' WHERE id_pedido = 1;

-- Passo B: Inserir a informação de entrega (Logística)
-- (Vamos supor que o id_pedido 1 existe)
INSERT INTO entrega (id_pedido, codigo_rastreio, status_entrega, data_previsao) 
VALUES (1, 'TRK998877BR', 'Em trânsito', '2023-12-30');

-- 3. Confirmar as alterações (Persistir no banco)
COMMIT;

-- Reabilitar autocommit se necessário
SET autocommit = 1;


-- ==============================================================================
-- PARTE 2: TRANSAÇÃO COM PROCEDURE (Com Rollback/Savepoint)
-- ==============================================================================
-- Cenário: Inserir um Pedido e seus Itens. Se der erro na inserção do item, desfaz o pedido.

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_inserir_pedido_seguro $$

CREATE PROCEDURE sp_inserir_pedido_seguro(
    IN p_id_cliente INT,
    IN p_descricao VARCHAR(255),
    IN p_frete DECIMAL(10,2),
    IN p_id_produto INT,
    IN p_quantidade INT,
    IN p_erro_simulado BOOLEAN -- Parâmetro para testarmos o ROLLBACK
)
BEGIN
    -- Declaração de variável para pegar o ID do pedido criado
    DECLARE v_id_pedido INT;
    
    -- Handler de Erro: Se der qualquer erro SQL (SQLEXCEPTION), executa o bloco abaixo
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK; -- Desfaz tudo que foi feito na transação
        SELECT 'Erro na transação! Operação desfeita.' AS Resultado;
    END;

    START TRANSACTION;

    -- 1. Inserir o cabeçalho do pedido
    INSERT INTO pedido (id_cliente, status_pedido, descricao, frete, valor_total)
    VALUES (p_id_cliente, 'Processando', p_descricao, p_frete, 0);
    
    -- Recuperar o ID gerado (LAST_INSERT_ID)
    SET v_id_pedido = LAST_INSERT_ID();

    -- 2. Simulação de erro (para testar o Rollback)
    IF p_erro_simulado THEN
        -- Forçamos um erro (ex: select de tabela inexistente ou sinalização de erro)
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro simulado para testar Rollback';
    END IF;

    -- 3. Inserir o item do pedido
    INSERT INTO produto_pedido (id_pedido, id_produto, quantidade, status)
    VALUES (v_id_pedido, p_id_produto, p_quantidade, 'Disponível');

    -- Se chegou até aqui sem erros, confirma!
    COMMIT;
    SELECT CONCAT('Sucesso! Pedido ', v_id_pedido, ' criado.') AS Resultado;

END $$

DELIMITER ;

-- ==============================================================================
-- TESTES DA PROCEDURE
-- ==============================================================================

-- Teste 1: Transação com Sucesso
CALL sp_inserir_pedido_seguro(1, 'Pedido Seguro Teste', 25.00, 1, 2, FALSE);

-- Teste 2: Transação com Falha (Simulando erro)
-- Verifique na tabela 'pedido' que nenhum registro novo será criado, pois o ROLLBACK anulou o INSERT do pedido.
CALL sp_inserir_pedido_seguro(1, 'Pedido Falha', 25.00, 1, 2, TRUE);