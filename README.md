# Banco de dados de e-commerce — modelagem, otimização e medição

Modelagem completa de um e-commerce em MySQL 8: EER, DDL, especialização
cliente PF/PJ, views com controle de acesso, stored procedure de CRUD, triggers de
auditoria, transações — e um **benchmark que mede o efeito de cada índice em vez de
afirmar que ele ajuda**.

[![MySQL 8.4](https://img.shields.io/badge/MySQL-8.4-4479A1?logo=mysql&logoColor=white)](https://dev.mysql.com/)
[![Massa: 100k pedidos](https://img.shields.io/badge/massa-100k%20pedidos-informational)](sql_implementation/02_seed_massa.sql)
[![Benchmark](https://img.shields.io/badge/benchmark-medido-brightgreen)](docs/benchmark.md)
[![Licença MIT](https://img.shields.io/badge/licença-MIT-green)](LICENSE)

![Diagrama EER do modelo: cliente com especialização PF/PJ, pedido, pagamento, entrega, produto, fornecedor e estoque.](img/diagrama_final.png)

---

## Subindo tudo com um comando

```bash
docker compose up -d
```

O container do MySQL executa `sql_implementation/` inteiro na primeira subida — é
por isso que os arquivos são numerados. Em ~2 minutos existe um banco com **20 mil
clientes, 50 mil produtos, 100 mil pedidos, 250 mil itens, 100 mil entregas e 120 mil
pagamentos**, índices criados, views, procedure, triggers e transações aplicadas.

Já tem um MySQL no ar?

```bash
./scripts/bootstrap.sh                 # aplica os 8 scripts na ordem
```

| # | script | o que faz |
|---|---|---|
| 01 | `01_tabelas.sql` | recria o banco e o schema |
| 02 | `02_seed_massa.sql` | massa de volume realista |
| 03 | `03_indices.sql` | os três índices avaliados |
| 04 | `04_views_permissoes.sql` | views de negócio + usuários e GRANTs |
| 05 | `05_procedure.sql` | `gerenciar_cliente` (insert/update/delete) |
| 06 | `06_triggers.sql` | auditoria de exclusão e histórico de preços |
| 07 | `07_transacoes.sql` | commit/rollback e savepoint |
| 08 | `08_perguntas.sql` | as consultas analíticas do desafio |

O `docker compose up` executa a sequência do zero em volume limpo; o `bootstrap.sh`
roda os mesmos arquivos na mesma ordem contra um servidor existente. **A sequência
completa foi executada do zero, com a massa, antes deste README existir** — foi assim
que apareceram os dois erros corrigidos em
[Armadilhas que o volume revelou](#armadilhas-que-o-volume-revelou).

---

## O que o índice realmente fez

Relatório completo, com planos de execução lado a lado: **[docs/benchmark.md](docs/benchmark.md)**.
Mediana de 7 execuções após aquecimento, MySQL 8.4.3, InnoDB, buffer pool de 512 MB.

| # | consulta | sem índice | com índice | resultado |
|---|---|---:|---:|---|
| 1 | `JOIN cliente × pedido` agrupado por cliente | 238,7 ms | 235,9 ms | **sem ganho** |
| 2 | `SELECT * FROM produto WHERE categoria = ?` | 134,1 ms | 124,4 ms | **sem ganho** |
| 3 | `SELECT COUNT(*) FROM produto WHERE categoria = ?` | 26,6 ms | 3,3 ms | **8,1× mais rápido** |
| 4 | `GROUP BY status_entrega` sobre 100 mil entregas | 189,4 ms | 74,3 ms | **2,6× mais rápido** |

Dois dos quatro casos não melhoraram. Isso **não** é defeito do experimento — é o
resultado, e é a parte mais útil dele:

**1. O índice da consulta 1 já existia.** `pedido.id_cliente` é chave estrangeira, e o
InnoDB cria um índice automaticamente para sustentar a FK. `CREATE INDEX
idx_pedido_cliente ON pedido(id_cliente)` não adiciona capacidade nenhuma: o MySQL
apenas passa a usar o novo índice no lugar do que ele mesmo havia criado, e **descarta
o antigo**. O plano antes e depois é idêntico — `p index · key=…(id_cliente) ·
rows≈99.869` nos dois.

Efeito colateral que só aparece quando se tenta desfazer: depois disso, o `DROP INDEX
idx_pedido_cliente` falha com `ERROR 1553 — needed in a foreign key constraint`. O
índice "redundante" virou o único suporte da FK. O
[`scripts/benchmark.py`](scripts/benchmark.py) trata esse caso recriando o índice da
chave estrangeira antes de derrubar o nosso — senão a segunda medição seria impossível.

**2. O índice da consulta 2 funciona; a consulta é que não aproveita.** O `EXPLAIN`
muda de `ALL · rows≈50.256` para `ref · rows≈5.000` — o índice **está** sendo usado e
corta 90% das linhas examinadas. Só que o `SELECT *` obriga o MySQL a voltar à tabela
para buscar cada uma das 5.000 linhas, e é essa ida e volta que domina o tempo.

A consulta 3 é a prova: **mesma coluna, mesmo índice, só a lista de seleção muda.**
Com `COUNT(*)`, a resposta inteira cabe no índice, o MySQL nunca toca na tabela
(`Extra: Using index`) e o tempo cai 8×.

> **A lição que este repositório sustenta com número:** índice não acelera tabela,
> acelera *consulta*. O ganho mora na relação entre as colunas indexadas e as colunas
> pedidas — não no `CREATE INDEX`.

### Reproduzindo

```bash
pip install -r requirements.txt
python scripts/benchmark.py --host 127.0.0.1 --porta 3306 --usuario root --senha root
```

O script derruba os índices, mede, cria, mede de novo e reescreve `docs/benchmark.md`.

---

## Por que 100 mil pedidos

Com as 3 linhas de exemplo do script original, nenhum índice jamais apareceria no
`EXPLAIN`: ler 3 linhas sequencialmente é mais barato que percorrer uma B-Tree, e o
otimizador sabe disso. Qualquer afirmação sobre performance feita nesse volume é
afirmação sobre nada.

[`02_seed_massa.sql`](sql_implementation/02_seed_massa.sql) gera a massa em ~2 minutos,
e dois detalhes dela existem só para o benchmark fazer sentido:

* **Pedidos por cliente em distribuição desigual** (`id_cliente = 1 + (n % 7919)`, com
  7919 primo). Com distribuição uniforme, "quem mais comprou" devolveria um empate de
  20 mil linhas.
* **Status de entrega em frequências diferentes** — 50% entregue, 20% em trânsito, e o
  resto distribuído. Num `GROUP BY`, distribuição uniforme esconde o custo real.

E um `ANALYZE TABLE` no fim: sem ele, o otimizador trabalha com estatísticas da tabela
vazia logo após a carga e pode escolher o plano errado, falseando a medição.

---

## Armadilhas que o volume revelou

Rodar a sequência inteira do zero, com massa, quebrou dois scripts que passavam com
3 linhas de teste. Os dois estão corrigidos:

**`05_procedure.sql` — ID fixo na mão.** O teste da procedure fazia
`CALL gerenciar_cliente(3, 4, …)`, apostando que o cliente 4 era o recém-criado. Com
100 mil pedidos no banco, o cliente 4 tem pedidos e o `DELETE` bate na FK:

```
ERROR 1451 (23000): Cannot delete or update a parent row:
a foreign key constraint fails (`ecommerce`.`pedido`, CONSTRAINT `fk_pedido_cliente`)
```

O teste agora captura `LAST_INSERT_ID()` em `@id` e opera sobre o próprio registro que
criou.

**`04_views_permissoes.sql` — revogar o que nunca foi concedido.** Havia um
`REVOKE SELECT … FROM 'funcionario_logistica'` "por garantia". O MySQL recusa:

```
ERROR 1147 (42000): There is no such grant defined for user 'funcionario_logistica'
```

O privilégio nunca tinha sido dado àquele usuário. Privilégio mínimo se faz por
omissão, não por revogação — o `REVOKE` saiu e entraram dois `SHOW GRANTS` mostrando o
que cada usuário enxerga de fato.

---

## Modelagem

Especializações e separações que o desafio pedia:

| Decisão | Por quê |
|---|---|
| `cliente` → `pessoa_fisica` / `pessoa_juridica` | especialização em tabelas filhas: um cliente é PF **ou** PJ, e cada uma tem documento próprio (`cpf` / `cnpj`, ambos `UNIQUE`) |
| `pagamento` 1:N com `pedido` | um pedido aceita mais de uma forma de pagamento — no seed, 20% dos pedidos têm dois lançamentos |
| `entrega` em tabela própria | rastreio e status logístico têm ciclo de vida independente do status comercial do pedido |
| `produto_pedido` com PK composta | `(id_pedido, id_produto)` impede o mesmo produto duplicado dentro de um pedido |
| `estoque_produto`, `produto_fornecedor` | N:N resolvidos com tabela associativa |

---

## Triggers de auditoria, com o efeito visível

Descrever uma trigger não prova nada. Abaixo, a saída real de uma sessão do MySQL.

### Histórico de preço (`BEFORE UPDATE`)

```sql
SELECT id_produto, descricao, valor FROM produto WHERE id_produto = 42;
UPDATE produto SET valor = 4999.90 WHERE id_produto = 42;
SELECT * FROM historico_precos WHERE id_produto = 42;
```

```
+------------+------------+-------+
| id_produto | descricao  | valor |
+------------+------------+-------+
|         42 | Produto 42 | 60.43 |      ← antes
+------------+------------+-------+

+--------------+------------+--------------+------------+---------------------+
| id_historico | id_produto | valor_antigo | valor_novo | data_alteracao      |
+--------------+------------+--------------+------------+---------------------+
|            1 |         42 |        60.43 |    4999.90 | 2026-10-08 17:16:34 |
+--------------+------------+--------------+------------+---------------------+
```

A trigger tem uma guarda que vale notar:

```sql
IF OLD.valor <> NEW.valor THEN  -- só registra quando o preço realmente muda
```

Um `UPDATE` que mexe apenas na descrição **não** gera linha de histórico — conferido:
depois de `UPDATE produto SET descricao = descricao WHERE id_produto = 42`, a tabela
continua com uma única linha. Sem essa guarda, qualquer gravação de formulário inflaria
a auditoria com ruído.

### Cópia antes da exclusão (`BEFORE DELETE`)

```sql
INSERT INTO cliente (nome, endereco, email)
VALUES ('Joana Ribeiro', 'Rua das Flores, 10', 'joana@exemplo.com.br');
DELETE FROM cliente WHERE id_cliente = LAST_INSERT_ID();
SELECT * FROM cliente_backup;
```

```
+-----------+-------------+---------------+----------------------+---------------------+
| id_backup | id_original | nome          | email                | data_exclusao       |
+-----------+-------------+---------------+----------------------+---------------------+
|         1 |       20001 | Joana Ribeiro | joana@exemplo.com.br | 2026-10-08 17:16:43 |
+-----------+-------------+---------------+----------------------+---------------------+
```

A linha sumiu de `cliente` e sobreviveu em `cliente_backup`, com a data da exclusão.

---

## Views e controle de acesso

[`04_views_permissoes.sql`](sql_implementation/04_views_permissoes.sql) cria as views de
negócio e dois perfis com visões deliberadamente diferentes:

| View | `gerente` | `funcionario_logistica` |
|---|:---:|:---:|
| `vw_relatorio_pedidos` | ✅ | — |
| `vw_produtos_mais_vendidos` | ✅ | — |
| `vw_produtos_fornecedores` | ✅ | — |
| `vw_clientes_por_localidade` | — | ✅ |

A logística precisa saber **de onde** são os clientes para planejar rota; não precisa
saber quanto a empresa vendeu nem de quem compra. A view é o mecanismo: o `GRANT` é
sobre ela, nunca sobre a tabela.

## Stored procedure

`gerenciar_cliente(opcao, id, nome, endereco, email)` concentra insert (1), update (2) e
delete (3) em um ponto só, com variável de controle. É o padrão de CRUD único do
desafio — e o teste dela agora é autocontido, pelo motivo explicado acima.

## Transações

[`07_transacoes.sql`](sql_implementation/07_transacoes.sql) demonstra `COMMIT`,
`ROLLBACK` e `SAVEPOINT` sobre o cenário "atualizar status do pedido **e** criar o
registro de entrega": ou as duas coisas acontecem, ou nenhuma.

## Consultas analíticas

| Pergunta | Resultado |
|---|---|
| Quantos pedidos por cliente? | ![Resultado da consulta de pedidos por cliente](img/query_pedidos_cliente.png) |
| Status financeiro × status logístico | ![Resultado da consulta cruzando pagamento e entrega](img/query_status_entrega.png) |
| Clientes com ticket médio acima de 4.000 | ![Resultado da consulta de clientes de alto valor](img/query_clientes_vip.png) |

As três estão em [`08_perguntas.sql`](sql_implementation/08_perguntas.sql), com `JOIN`,
`GROUP BY`, `HAVING` e atributo derivado.

---

## Estrutura

```
sql_implementation/
  01_tabelas.sql … 08_perguntas.sql   a modelagem, em ordem de execução
  backup_ecommerce.sql                dump completo (mysqldump)
  ecommerce.mwb                       modelo do MySQL Workbench
scripts/
  bootstrap.sh                        aplica os 8 scripts em um MySQL existente
  benchmark.py                        mede EXPLAIN + tempo, antes e depois
docs/benchmark.md                     relatório gerado pelo benchmark
docker-compose.yml                    MySQL 8.4 + inicialização automática
img/                                  diagrama EER e resultados das consultas
```

## Backup e recuperação

```bash
# gerar
mysqldump -u root -p --routines --triggers ecommerce > sql_implementation/backup_ecommerce.sql

# restaurar
mysql -u root -p ecommerce < sql_implementation/backup_ecommerce.sql
```

`--routines --triggers` não é detalhe: sem essas duas flags o dump leva as tabelas e
deixa para trás a procedure e as duas triggers de auditoria — e a restauração parece
ter dado certo até alguém excluir um cliente e perceber que nada foi registrado.

## Projeto irmão

[**Desafio2-SQL-Database-Specialist**](https://github.com/danilogep/Desafio2-SQL-Database-Specialist) —
oficina mecânica. Mesmo stack, problema diferente: lá o eixo é **modelagem** (ordens de
serviço que congelam o preço praticado no momento da venda, para que uma atualização na
tabela de preços não reescreva o histórico financeiro). Aqui o eixo é **performance
medida**.

## Licença

[MIT](LICENSE).
