-- -----------------------------------------------------
-- 1. CRIAÇÃO DO BANCO DE DADOS E TABELAS
-- -----------------------------------------------------
DROP DATABASE IF EXISTS ecommerce;
CREATE DATABASE ecommerce;
USE ecommerce;

-- Tabela Cliente (Pai)
CREATE TABLE cliente (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(45),
    endereco VARCHAR(255),
    email VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela Pessoa Física (Filha)
CREATE TABLE pessoa_fisica (
    id_cliente INT PRIMARY KEY,
    cpf CHAR(11) NOT NULL UNIQUE,
    rg VARCHAR(15),
    nascimento DATE,
    CONSTRAINT fk_pf_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
);

-- Tabela Pessoa Jurídica (Filha)
CREATE TABLE pessoa_juridica (
    id_cliente INT PRIMARY KEY,
    cnpj CHAR(14) NOT NULL UNIQUE,
    razao_social VARCHAR(100),
    nome_fantasia VARCHAR(100),
    CONSTRAINT fk_pj_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
);

-- Tabela Pedido
CREATE TABLE pedido (
    id_pedido INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    status_pedido ENUM('Em andamento', 'Processando', 'Enviado', 'Entregue') DEFAULT 'Processando',
    descricao VARCHAR(255),
    frete DECIMAL(10,2),
    valor_total DECIMAL(10,2),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
);

-- Tabela Pagamento (1:N com Pedido - Desafio cumprido)
CREATE TABLE pagamento (
    id_pagamento INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT,
    tipo_pagamento ENUM('Boleto', 'Cartão', 'Pix'),
    valor DECIMAL(10,2),
    status VARCHAR(45),
    CONSTRAINT fk_pagamento_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido)
);

-- Tabela Entrega (Logística separada - Desafio cumprido)
CREATE TABLE entrega (
    id_entrega INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT,
    codigo_rastreio VARCHAR(50),
    status_entrega VARCHAR(45),
    data_previsao DATE,
    CONSTRAINT fk_entrega_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido)
);

-- Tabela Produto
CREATE TABLE produto (
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    categoria VARCHAR(45),
    descricao VARCHAR(45),
    valor DECIMAL(10,2)
);

-- Tabela Fornecedor
CREATE TABLE fornecedor (
    id_fornecedor INT AUTO_INCREMENT PRIMARY KEY,
    razao_social VARCHAR(45),
    cnpj CHAR(14)
);

-- Tabela Estoque
CREATE TABLE estoque (
    id_estoque INT AUTO_INCREMENT PRIMARY KEY,
    local VARCHAR(45)
);

-- Tabela Relacionamento Produto/Pedido
CREATE TABLE produto_pedido (
    id_pedido INT,
    id_produto INT,
    quantidade INT,
    status VARCHAR(45),
    PRIMARY KEY (id_pedido, id_produto),
    CONSTRAINT fk_pp_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido),
    CONSTRAINT fk_pp_produto FOREIGN KEY (id_produto) REFERENCES produto(id_produto)
);

-- Tabela Relacionamento Produto/Fornecedor
CREATE TABLE produto_fornecedor (
    id_fornecedor INT,
    id_produto INT,
    PRIMARY KEY (id_fornecedor, id_produto),
    CONSTRAINT fk_pf_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES fornecedor(id_fornecedor),
    CONSTRAINT fk_pf_produto FOREIGN KEY (id_produto) REFERENCES produto(id_produto)
);

-- Tabela Relacionamento Produto/Estoque
CREATE TABLE estoque_produto (
    id_estoque INT,
    id_produto INT,
    quantidade INT,
    PRIMARY KEY (id_estoque, id_produto),
    CONSTRAINT fk_ep_estoque FOREIGN KEY (id_estoque) REFERENCES estoque(id_estoque),
    CONSTRAINT fk_ep_produto FOREIGN KEY (id_produto) REFERENCES produto(id_produto)
);


-- -----------------------------------------------------
-- 2. INSERÇÃO DE DADOS (PERSISTÊNCIA)
-- -----------------------------------------------------

-- Clientes
INSERT INTO cliente (nome, endereco, email) VALUES 
('Danilo Pereira', 'Rua das Flores, 123', 'danilo@email.com'),
('Tech Solutions', 'Av. Paulista, 1000', 'contato@tech.com'),
('Maria Silva', 'Rua do Sol, 45', 'maria@email.com');

-- Definindo quem é PF e PJ
INSERT INTO pessoa_fisica (id_cliente, cpf, rg, nascimento) VALUES (1, '12345678900', '1234567', '1990-05-20');
INSERT INTO pessoa_fisica (id_cliente, cpf, rg, nascimento) VALUES (3, '98765432100', '7654321', '1985-10-10');
INSERT INTO pessoa_juridica (id_cliente, cnpj, razao_social) VALUES (2, '12345678000199', 'Tech Solutions LTDA');

-- Produtos
INSERT INTO produto (categoria, descricao, valor) VALUES 
('Eletrônicos', 'Notebook Gamer', 4500.00),
('Eletrônicos', 'Mouse Sem Fio', 150.00),
('Móveis', 'Cadeira Ergonomica', 800.00);

-- Pedidos
-- Pedido 1: Danilo comprou um Notebook
INSERT INTO pedido (id_cliente, status_pedido, descricao, frete, valor_total) VALUES (1, 'Enviado', 'Compra Web', 50.00, 4550.00);
-- Pedido 2: Tech Solutions comprou cadeiras
INSERT INTO pedido (id_cliente, status_pedido, descricao, frete, valor_total) VALUES (2, 'Processando', 'Móveis Escritório', 100.00, 1600.00);

-- Itens dos Pedidos
INSERT INTO produto_pedido (id_pedido, id_produto, quantidade, status) VALUES (1, 1, 1, 'Disponível');
INSERT INTO produto_pedido (id_pedido, id_produto, quantidade, status) VALUES (2, 3, 2, 'Disponível');

-- Pagamentos (O Pedido 1 foi pago com dois métodos - Desafio)
INSERT INTO pagamento (id_pedido, tipo_pagamento, valor, status) VALUES (1, 'Pix', 2000.00, 'Aprovado');
INSERT INTO pagamento (id_pedido, tipo_pagamento, valor, status) VALUES (1, 'Cartão', 2550.00, 'Aprovado');

-- Entregas
INSERT INTO entrega (id_pedido, codigo_rastreio, status_entrega, data_previsao) VALUES (1, 'BR123456789', 'Em trânsito', '2023-12-25');