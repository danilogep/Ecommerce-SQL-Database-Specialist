# Desafio de Projeto: Refinando um Projeto Conceitual de Banco de Dados – E-COMMERCE

Este repositório contém a resolução do desafio de projeto **"Refinando um Projeto Conceitual de Banco de Dados – E-COMMERCE"**, parte da formação de Ciência de Dados / SQL.

O objetivo foi refinar um modelo conceitual existente para atender a cenários mais complexos e realistas de um sistema de comércio eletrônico.

## 📋 Objetivos do Desafio

O projeto original precisava de melhorias em três áreas principais, que foram implementadas neste modelo:

1.  **Cliente PJ e PF:** Uma conta pode ser Pessoa Jurídica ou Física, mas não pode ter as duas informações simultaneamente.
2.  **Pagamento:** Capacidade de cadastrar mais de uma forma de pagamento para o mesmo pedido.
3.  **Entrega:** Controle de status e código de rastreio independente do pedido.

## 🚀 Melhorias Implementadas e Justificativas

Abaixo, detalho as decisões de modelagem tomadas para atender aos requisitos (Baseado no Diagrama EER desenvolvido no MySQL Workbench).

### 1. Cliente: Generalização e Especialização (Herança)
Para resolver a questão de PJ (Pessoa Jurídica) e PF (Pessoa Física), foi utilizada a técnica de herança.
* **Tabela Pai (`Cliente`):** Contém os dados comuns a todos (ID, Nome, Endereço, Contato).
* **Tabelas Filhas (`Pessoa_Fisica` e `Pessoa_Juridica`):** Contêm apenas os dados específicos (CPF/RG para PF e CNPJ/Razão Social para PJ).
* **Justificativa:** Essa abordagem evita campos nulos (NULL) no banco de dados e garante a integridade dos dados, impedindo que um cliente tenha CPF e CNPJ ao mesmo tempo incorretamente.

### 2. Gestão de Pagamentos (Relacionamento 1:N)
A entidade `Pagamento` foi separada da entidade `Pedido`.
* **Mudança:** Criação de uma tabela dedicada `Pagamento` conectada a `Pedido` através de um relacionamento **1 para Muitos (1:N)**.
* **Justificativa:** No e-commerce moderno, é comum um cliente dividir o pagamento (ex: parte no cartão, parte em vale-presente). A nova estrutura permite registrar múltiplos métodos de pagamento vinculados a um único ID de pedido.

### 3. Logística e Entrega
A entidade `Entrega` foi criada como uma tabela independente, vinculada ao `Pedido`.
* **Atributos:** Inclui `status_entrega` (ex: Em trânsito, Entregue), `codigo_rastreio` e `data_previsao`.
* **Justificativa:** O status do pedido (Financeiro) é diferente do status da entrega (Logístico). Separar essas entidades permite, por exemplo, gerenciar múltiplas entregas para um mesmo pedido (caso os produtos saiam de armazéns diferentes) e atualizações de rastreio sem afetar a integridade do registro de vendas.

## 🖼️ Diagrama EER (Entity Relationship Diagram)

Abaixo está a representação gráfica do modelo refinado:

![Diagrama EER do E-commerce](/img/diagrama_ecommerce.png)

## 🛠️ Ferramentas Utilizadas

* **MySQL Workbench:** Para modelagem do diagrama EER e criação do esquema.
* **Notação Pé de Galinha (Crow's Foot):** Para representação dos relacionamentos.

## 📂 Estrutura do Repositório

* `ecommerce.mwb`: Arquivo original do projeto no MySQL Workbench.
* `\img\diagrama_ecommerce.png`: Imagem do diagrama visual.
* `README.md`: Documentação do projeto.