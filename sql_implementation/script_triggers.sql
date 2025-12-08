USE ecommerce;

-- ==============================================================================
-- PARTE 3.3: TRIGGERS (Gatilhos)
-- ==============================================================================

-- CENÁRIO 1: REMOÇÃO (BEFORE DELETE)
-- Objetivo: Salvar dados do cliente antes que ele seja excluído permanentemente.

-- 1. Criar tabela de backup (Espelho da tabela cliente)
CREATE TABLE IF NOT EXISTS cliente_backup (
    id_backup INT AUTO_INCREMENT PRIMARY KEY,
    id_original INT,
    nome VARCHAR(45),
    email VARCHAR(45),
    data_exclusao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Criar a Trigger
DELIMITER $$

CREATE TRIGGER trg_bkp_cliente_before_delete
BEFORE DELETE ON cliente
FOR EACH ROW
BEGIN
    INSERT INTO cliente_backup (id_original, nome, email)
    VALUES (OLD.id_cliente, OLD.nome, OLD.email);
END $$

DELIMITER ;


-- CENÁRIO 2: ATUALIZAÇÃO (BEFORE UPDATE)
-- Objetivo: Guardar o histórico de preços dos produtos antes de serem atualizados.
-- (Adaptado de "Atualização de Salário Base")

-- 1. Criar tabela de histórico
CREATE TABLE IF NOT EXISTS historico_precos (
    id_historico INT AUTO_INCREMENT PRIMARY KEY,
    id_produto INT,
    valor_antigo DECIMAL(10,2),
    valor_novo DECIMAL(10,2),
    data_alteracao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Criar a Trigger
DELIMITER $$

CREATE TRIGGER trg_atualiza_preco_produto
BEFORE UPDATE ON produto
FOR EACH ROW
BEGIN
    -- Só registra se houve mudança no valor
    IF OLD.valor <> NEW.valor THEN
        INSERT INTO historico_precos (id_produto, valor_antigo, valor_novo)
        VALUES (OLD.id_produto, OLD.valor, NEW.valor);
    END IF;
END $$

DELIMITER ;

-- ==============================================================================
-- TESTES DAS TRIGGERS
-- ==============================================================================

-- Teste Update: Aumentando o preço do produto ID 1
-- UPDATE produto SET valor = 5000.00 WHERE id_produto = 1;
-- SELECT * FROM historico_precos;

-- Teste Delete: Removendo o cliente ID 3
-- DELETE FROM cliente WHERE id_cliente = 3;
-- SELECT * FROM cliente_backup;