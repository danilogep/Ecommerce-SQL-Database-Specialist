# Benchmark — efeito dos índices

Gerado por `python scripts/benchmark.py`. Mediana de 7 execuções, após uma execução de aquecimento descartada.

**Ambiente:** MySQL 8.4.11 · InnoDB · massa de `00_seed_massa.sql`

| tabela | linhas |
|---|---:|
| `cliente` | 20.000 |
| `produto` | 50.000 |
| `pedido` | 100.001 |
| `produto_pedido` | 249.999 |
| `entrega` | 100.001 |
| `pagamento` | 120.000 |

## Resumo

| # | consulta | sem índice | com índice | variação |
|---|---|---:|---:|---:|
| 1 | Pedidos por cliente | 121.0 ms | 123.7 ms | 0.98× (sem ganho) |
| 2 | Produtos de uma categoria | 137.3 ms | 131.7 ms | 1.04× (sem ganho) |
| 3 | Contagem por categoria | 20.0 ms | 6.7 ms | **3.0× mais rápido** |
| 4 | Entregas por status | 84.5 ms | 46.7 ms | **1.8× mais rápido** |

## 1. Pedidos por cliente

> Qual o cliente com maior número de pedidos?

Índice avaliado: `idx_pedido_cliente ON pedido(id_cliente)`

```sql
SELECT c.nome, COUNT(p.id_pedido) AS total FROM cliente c INNER JOIN pedido p ON c.id_cliente = p.id_cliente GROUP BY c.id_cliente ORDER BY total DESC LIMIT 10
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `p` index · key=fk_pedido_cliente · rows≈99.937 · where; index; temporary; filesort<br>`c` eq_ref · key=PRIMARY · rows≈1 | 99.937 | 121.0 ms | 109.8 ms | 165.7 ms |
| **com índice** | `p` index · key=fk_pedido_cliente · rows≈99.869 · where; index; temporary; filesort<br>`c` eq_ref · key=PRIMARY · rows≈1 | 99.869 | 123.7 ms | 107.9 ms | 174.1 ms |

## 2. Produtos de uma categoria

> Quais são os produtos de uma determinada categoria?

Índice avaliado: `idx_produto_categoria ON produto(categoria)`

```sql
SELECT * FROM produto WHERE categoria = 'Móveis'
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `produto` ALL · key=NULL · rows≈48.068 · where | 48.068 | 137.3 ms | 133.4 ms | 175.0 ms |
| **com índice** | `produto` ref · key=idx_produto_categoria · rows≈5.000 | 5.000 | 131.7 ms | 125.7 ms | 167.9 ms |

## 3. Contagem por categoria

> Quantos produtos existem nesta categoria?

Índice avaliado: `idx_produto_categoria ON produto(categoria)  — mesmo índice da consulta 2`

```sql
SELECT COUNT(*) FROM produto WHERE categoria = 'Móveis'
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `produto` ALL · key=NULL · rows≈48.068 · where | 48.068 | 20.0 ms | 18.4 ms | 24.1 ms |
| **com índice** | `produto` ref · key=idx_produto_categoria · rows≈5.000 · index | 5.000 | 6.7 ms | 3.9 ms | 7.3 ms |

## 4. Entregas por status

> Quantas entregas há em cada status?

Índice avaliado: `idx_entrega_status ON entrega(status_entrega)`

```sql
SELECT status_entrega, COUNT(*) FROM entrega GROUP BY status_entrega
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `entrega` ALL · key=NULL · rows≈105.003 · temporary | 105.003 | 84.5 ms | 83.5 ms | 124.5 ms |
| **com índice** | `entrega` index · key=idx_entrega_status · rows≈100.662 · index | 100.662 | 46.7 ms | 45.6 ms | 89.1 ms |
