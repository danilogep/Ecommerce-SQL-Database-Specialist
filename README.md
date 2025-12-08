# 🛒 E-commerce Database Project: Do Modelo Conceitual à Implementação SQL

Este projeto consiste na modelagem completa e implementação de um banco de dados relacional para um cenário de E-commerce. 

O projeto começou com a refatoração de um modelo conceitual e evoluiu para a implementação física, otimização com índices e automação com procedures.

## 🎯 Objetivos do Desafio (Parte 1)

O esquema inicial foi estruturado para resolver lacunas comuns em modelagens simples, atendendo a requisitos de negócio complexos:

1.  **Cliente PJ e PF:** Implementação de especialização/herança para permitir que um cliente seja Pessoa Física (CPF) ou Jurídica (CNPJ), garantindo integridade e evitando redundância.
2.  **Múltiplos Meios de Pagamento:** Desacoplamento da entidade Pagamento para permitir que um único pedido seja pago com múltiplas formas (ex: Cartão + Pix).
3.  **Gestão de Entregas:** Criação de entidade de Entrega independente, permitindo rastreio (Tracking Code) e status logístico separado do status financeiro do pedido.

## 🛠️ Tecnologias Utilizadas

* **MySQL Workbench 8.0:** Modelagem EER e execução de scripts SQL.
* **Linguagem SQL:** DDL (Data Definition Language), DQL (Data Query Language) e DML.
* **Git/GitHub:** Versionamento e documentação.

## 📊 Modelagem de Dados (Diagrama EER)

Abaixo, o diagrama Entidade-Relacionamento final refinado.

![Diagrama EER Final](img/diagrama_final.png)

### Decisões de Arquitetura:
* **Herança na Tabela Cliente:** A tabela `cliente` armazena dados globais, enquanto `pessoa_fisica` e `pessoa_juridica` armazenam dados específicos.
* **Relacionamentos N:M:** Tabelas associativas criadas para gerenciar produtos por pedido e estoque.

## 🧠 Análise de Dados (Parte 1)

Queries SQL elaboradas para extrair insights valiosos do negócio.

### 1. Quantos pedidos foram feitos por cada cliente?
![Resultado Query 1](img/query_pedidos_cliente.png)

### 2. Relação de Pedidos: Status Financeiro vs. Status Logístico
![Resultado Query 2](img/query_status_entrega.png)

### 3. Clientes de Alto Valor (Ticket Médio > 4000)
![Resultado Query 3](img/query_clientes_vip.png)

---

# ⚡ Parte 2: Otimização e Recursos Avançados

Nesta etapa de evolução do projeto, o foco foi a **Performance** e a **Automação** de rotinas no banco de dados, atendendo aos novos requisitos de negócio.

## 🔍 Índices (Performance Tuning)

A criação de índices foi planejada considerando os **dados mais acessados** e a **relevância no contexto** das queries. O objetivo é reduzir o custo computacional de junções (JOINs) e filtros frequentes.

### Justificativa das Escolhas

| Contexto da Consulta (Pergunta de Negócio) | Tabela e Coluna Indexada | Tipo de Índice | Motivo Técnico da Escolha |
| :--- | :--- | :--- | :--- |
| **"Qual o cliente com maior número de pedidos?"**<br>Recuperação de histórico. | `pedido` (`id_cliente`) | **B-Tree** | Esta consulta realiza um `JOIN` massivo entre Clientes e Pedidos. O índice na chave estrangeira é crítico para evitar *Full Table Scan*, acelerando a junção dos registros. |
| **"Quais são os produtos de uma categoria?"**<br>Filtros de navegação no site. | `produto` (`categoria`) | **B-Tree** | Como a busca por produtos (WHERE) é a operação mais frequente em um e-commerce, indexar a coluna de categoria permite acesso direto aos itens sem varrer todo o catálogo. |
| **"Relação de Entregas por Status"**<br>Relatórios operacionais. | `entrega` (`status_entrega`) | **B-Tree** | Consultas que utilizam `GROUP BY` ou `ORDER BY` em colunas de status beneficiam-se do índice, pois o SGBD já recupera os dados pré-ordenados. |

> *Os scripts de criação estão no arquivo `script_indices.sql`.*

## ⚙️ Stored Procedures (Automação de CRUD)

Foi desenvolvida uma procedure para encapsular a lógica de manipulação de dados dos clientes, garantindo que as regras de inserção e atualização sejam centralizadas no banco.

### Procedure: `gerenciar_cliente`

Esta rotina utiliza uma **Variável de Controle** (`p_opcao`) para determinar a ação a ser executada através de condicionais (`IF/ELSEIF`):

* **Opção 1 (INSERT):** Recebe os dados e cria um novo cliente, retornando o ID gerado.
* **Opção 2 (UPDATE):** Atualiza os dados de um cliente existente com base no ID.
* **Opção 3 (DELETE):** Remove um cliente do banco de dados.

**Trecho da Lógica:**
```sql
IF p_opcao = 1 THEN
    INSERT INTO cliente (...) VALUES (...);
ELSEIF p_opcao = 2 THEN
    UPDATE cliente SET ... WHERE id_cliente = p_id_cliente;
... 
```

A implementação completa está no arquivo script_procedures.sql.
 
## 📂 Estrutura Atualizada do Repositório
* script_tabelas.sql: Criação do Banco de Dados (Parte 1).
* script_perguntas.sql: Queries analíticas (Parte 1).
* script_indices.sql: Otimização de performance (Parte 2).
* script_procedures.sql: Automação com Procedures (Parte 2).
* ecommerce.mwb: Modelo visual.