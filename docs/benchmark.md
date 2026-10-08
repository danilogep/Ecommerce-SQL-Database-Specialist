# Benchmark — efeito dos índices

Gerado por `python scripts/benchmark.py`. Mediana de 7 execuções, após uma execução de aquecimento descartada.

**Ambiente:** MySQL 8.4.3 · InnoDB · massa de `00_seed_massa.sql`

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
| 1 | Pedidos por cliente | 238.7 ms | 235.9 ms | 1.01× (sem ganho) |
| 2 | Produtos de uma categoria | 134.1 ms | 124.4 ms | 1.08× (sem ganho) |
| 3 | Contagem por categoria | 26.6 ms | 3.3 ms | **8.1× mais rápido** |
| 4 | Entregas por status | 189.4 ms | 74.3 ms | **2.6× mais rápido** |

## 1. Pedidos por cliente

> Qual o cliente com maior número de pedidos?

Índice avaliado: `idx_pedido_cliente ON pedido(id_cliente)`

```sql
SELECT c.nome, COUNT(p.id_pedido) AS total FROM cliente c INNER JOIN pedido p ON c.id_cliente = p.id_cliente GROUP BY c.id_cliente ORDER BY total DESC LIMIT 10
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `p` index · key=fk_pedido_cliente · rows≈99.871 · where; index; temporary; filesort<br>`c` eq_ref · key=PRIMARY · rows≈1 | 99.871 | 238.7 ms | 225.5 ms | 332.5 ms |
| **com índice** | `p` index · key=fk_pedido_cliente · rows≈98.581 · where; index; temporary; filesort<br>`c` eq_ref · key=PRIMARY · rows≈1 | 98.581 | 235.9 ms | 234.6 ms | 246.8 ms |

## 2. Produtos de uma categoria

> Quais são os produtos de uma determinada categoria?

Índice avaliado: `idx_produto_categoria ON produto(categoria)`

```sql
SELECT * FROM produto WHERE categoria = 'Móveis'
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `produto` ALL · key=NULL · rows≈50.204 · where | 50.204 | 134.1 ms | 128.3 ms | 157.8 ms |
| **com índice** | `produto` ref · key=idx_produto_categoria · rows≈5.000 | 5.000 | 124.4 ms | 122.5 ms | 128.4 ms |

## 3. Contagem por categoria

> Quantos produtos existem nesta categoria?

Índice avaliado: `idx_produto_categoria ON produto(categoria)  — mesmo índice da consulta 2`

```sql
SELECT COUNT(*) FROM produto WHERE categoria = 'Móveis'
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `produto` ALL · key=NULL · rows≈50.204 · where | 50.204 | 26.6 ms | 24.8 ms | 29.9 ms |
| **com índice** | `produto` ref · key=idx_produto_categoria · rows≈5.000 · index | 5.000 | 3.3 ms | 3.1 ms | 4.6 ms |

## 4. Entregas por status

> Quantas entregas há em cada status?

Índice avaliado: `idx_entrega_status ON entrega(status_entrega)`

```sql
SELECT status_entrega, COUNT(*) FROM entrega GROUP BY status_entrega
```

| | plano de execução | linhas estimadas | mediana | min | max |
|---|---|---:|---:|---:|---:|
| **sem índice** | `entrega` ALL · key=NULL · rows≈105.003 · temporary | 105.003 | 189.4 ms | 182.0 ms | 193.5 ms |
| **com índice** | `entrega` index · key=idx_entrega_status · rows≈101.484 · index | 101.484 | 74.3 ms | 73.6 ms | 77.2 ms |
