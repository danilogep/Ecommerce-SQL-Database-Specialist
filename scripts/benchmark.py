"""Mede o efeito dos índices: EXPLAIN e tempo, antes e depois.

    python scripts/benchmark.py --host 127.0.0.1 --porta 3306 --usuario root --senha ...

O que o script faz, nesta ordem:

1. derruba os índices de `script_indices.sql` (volta ao estado "sem otimização");
2. para cada consulta, roda `EXPLAIN` e cronometra N execuções;
3. cria os índices;
4. repete a medição;
5. escreve `docs/benchmark.md` com a tabela comparativa.

Cada consulta roda uma vez como aquecimento antes de medir: a primeira leitura
traz as páginas do disco para o buffer pool, e incluí-la na média mediria o
disco, não o índice. O que interessa comparar é plano contra plano, com os dois
lados já aquecidos.
"""

from __future__ import annotations

import argparse
import statistics
import time
from pathlib import Path

import pymysql

RAIZ = Path(__file__).resolve().parents[1]
SAIDA = RAIZ / "docs" / "benchmark.md"

REPETICOES = 7

# As três consultas que o script_indices.sql diz otimizar.
CONSULTAS = [
    {
        "id": 1,
        "titulo": "Pedidos por cliente",
        "pergunta": "Qual o cliente com maior número de pedidos?",
        "indice": "idx_pedido_cliente ON pedido(id_cliente)",
        "sql": """
            SELECT c.nome, COUNT(p.id_pedido) AS total
            FROM cliente c
            INNER JOIN pedido p ON c.id_cliente = p.id_cliente
            GROUP BY c.id_cliente
            ORDER BY total DESC
            LIMIT 10
        """,
    },
    {
        "id": 2,
        "titulo": "Produtos de uma categoria",
        "pergunta": "Quais são os produtos de uma determinada categoria?",
        "indice": "idx_produto_categoria ON produto(categoria)",
        "sql": "SELECT * FROM produto WHERE categoria = 'Móveis'",
    },
    {
        "id": 3,
        "titulo": "Contagem por categoria",
        "pergunta": "Quantos produtos existem nesta categoria?",
        "indice": "idx_produto_categoria ON produto(categoria)  — mesmo índice da consulta 2",
        # Mesma coluna, mesmo índice, pergunta diferente: aqui a resposta inteira
        # cabe no índice e o MySQL não precisa voltar à tabela. É o contraste com
        # a consulta 2, onde o `SELECT *` obriga a buscar cada linha.
        "sql": "SELECT COUNT(*) FROM produto WHERE categoria = 'Móveis'",
    },
    {
        "id": 4,
        "titulo": "Entregas por status",
        "pergunta": "Quantas entregas há em cada status?",
        "indice": "idx_entrega_status ON entrega(status_entrega)",
        "sql": "SELECT status_entrega, COUNT(*) FROM entrega GROUP BY status_entrega",
    },
]

# (índice, tabela, coluna, índice que a FK mantinha antes — ou None)
#
# `pedido.id_cliente` tem chave estrangeira, e o InnoDB exige um índice nela. Ao
# criar `idx_pedido_cliente`, o MySQL passa a usá-lo para sustentar a FK e
# **descarta** o `fk_pedido_cliente` que ele próprio havia criado. Por isso, para
# medir o estado "sem índice", é preciso recriar o índice da FK antes de derrubar
# o nosso — senão o DROP falha com o erro 1553.
INDICES = [
    ("idx_pedido_cliente", "pedido", "id_cliente", "fk_pedido_cliente"),
    ("idx_produto_categoria", "produto", "categoria", None),
    ("idx_entrega_status", "entrega", "status_entrega", None),
]

ERRO_INDICE_EXIGIDO_POR_FK = 1553


def existe_indice(cur, tabela: str, indice: str) -> bool:
    cur.execute(
        "SELECT 1 FROM information_schema.statistics "
        "WHERE table_schema = DATABASE() AND table_name = %s AND index_name = %s LIMIT 1",
        (tabela, indice),
    )
    return cur.fetchone() is not None


def derrubar_indices(cur) -> None:
    """Volta ao estado anterior à otimização, inclusive restaurando índices de FK."""
    for indice, tabela, coluna, indice_fk in INDICES:
        if not existe_indice(cur, tabela, indice):
            continue
        try:
            cur.execute(f"DROP INDEX {indice} ON {tabela}")
        except pymysql.err.OperationalError as erro:
            if erro.args[0] != ERRO_INDICE_EXIGIDO_POR_FK or not indice_fk:
                raise
            # O índice virou o suporte da chave estrangeira. Recria o índice
            # original da FK e só então derruba o nosso.
            if not existe_indice(cur, tabela, indice_fk):
                cur.execute(f"CREATE INDEX {indice_fk} ON {tabela}({coluna})")
            cur.execute(f"DROP INDEX {indice} ON {tabela}")


def criar_indices(cur) -> None:
    for indice, tabela, coluna, _ in INDICES:
        if not existe_indice(cur, tabela, indice):
            cur.execute(f"CREATE INDEX {indice} ON {tabela}({coluna})")


def explicar(cur, sql: str) -> list[dict]:
    cur.execute("EXPLAIN " + sql)
    colunas = [c[0] for c in cur.description]
    return [dict(zip(colunas, linha, strict=True)) for linha in cur.fetchall()]


def cronometrar(cur, sql: str, repeticoes: int = REPETICOES) -> dict:
    cur.execute(sql)  # aquecimento, descartado
    cur.fetchall()

    tempos = []
    for _ in range(repeticoes):
        inicio = time.perf_counter()
        cur.execute(sql)
        linhas = cur.fetchall()
        tempos.append((time.perf_counter() - inicio) * 1000)

    return {
        "mediana_ms": statistics.median(tempos),
        "min_ms": min(tempos),
        "max_ms": max(tempos),
        "linhas": len(linhas),
    }


def medir_tudo(cur) -> list[dict]:
    resultados = []
    for consulta in CONSULTAS:
        plano = explicar(cur, consulta["sql"])
        resultados.append({"plano": plano, **cronometrar(cur, consulta["sql"])})
    return resultados


def _resumo_plano(plano: list[dict]) -> str:
    partes = []
    for linha in plano:
        tabela = linha.get("table") or "—"
        tipo = linha.get("type") or "—"
        chave = linha.get("key") or "NULL"
        lidas = linha.get("rows")
        extra = (linha.get("Extra") or "").replace("Using ", "")
        texto = f"`{tabela}` {tipo} · key={chave} · rows≈{lidas:,}".replace(",", ".")
        if extra:
            texto += f" · {extra}"
        partes.append(texto)
    return "<br>".join(partes)


def _linhas_lidas(plano: list[dict]) -> int:
    total = 1
    for linha in plano:
        total *= max(int(linha.get("rows") or 1), 1)
    return total


def escrever_relatorio(antes: list[dict], depois: list[dict], contagens: dict, versao: str) -> None:
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    L: list[str] = []
    a = L.append

    a("# Benchmark — efeito dos índices\n")
    a(
        "Gerado por `python scripts/benchmark.py`. Mediana de "
        f"{REPETICOES} execuções, após uma execução de aquecimento descartada.\n"
    )
    a(f"**Ambiente:** MySQL {versao} · InnoDB · massa de `00_seed_massa.sql`\n")
    a("| tabela | linhas |")
    a("|---|---:|")
    for nome, total in contagens.items():
        a(f"| `{nome}` | {total:,} |".replace(",", "."))
    a("")

    a("## Resumo\n")
    a("| # | consulta | sem índice | com índice | variação |")
    a("|---|---|---:|---:|---:|")
    for consulta, m_antes, m_depois in zip(CONSULTAS, antes, depois, strict=True):
        delta = m_depois["mediana_ms"] - m_antes["mediana_ms"]
        if m_antes["mediana_ms"] > 0:
            fator = m_antes["mediana_ms"] / max(m_depois["mediana_ms"], 1e-9)
            variacao = f"**{fator:.1f}× mais rápido**" if fator >= 1.15 else (
                f"{fator:.2f}× (sem ganho)" if fator > 0.85 else f"**{1 / fator:.1f}× mais lento**"
            )
        else:
            variacao = "—"
        a(
            f"| {consulta['id']} | {consulta['titulo']} | {m_antes['mediana_ms']:.1f} ms "
            f"| {m_depois['mediana_ms']:.1f} ms | {variacao} |"
        )
        del delta
    a("")

    for consulta, m_antes, m_depois in zip(CONSULTAS, antes, depois, strict=True):
        a(f"## {consulta['id']}. {consulta['titulo']}\n")
        a(f"> {consulta['pergunta']}\n")
        a(f"Índice avaliado: `{consulta['indice']}`\n")
        a("```sql")
        a(" ".join(consulta["sql"].split()))
        a("```\n")
        a("| | plano de execução | linhas estimadas | mediana | min | max |")
        a("|---|---|---:|---:|---:|---:|")
        for rotulo, m in (("**sem índice**", m_antes), ("**com índice**", m_depois)):
            a(
                f"| {rotulo} | {_resumo_plano(m['plano'])} | "
                f"{_linhas_lidas(m['plano']):,} | {m['mediana_ms']:.1f} ms | "
                f"{m['min_ms']:.1f} ms | {m['max_ms']:.1f} ms |".replace(",", ".")
            )
        a("")

    SAIDA.write_text("\n".join(L), encoding="utf-8")
    print(f"relatório escrito em {SAIDA}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--porta", type=int, default=3306)
    ap.add_argument("--usuario", default="root")
    ap.add_argument("--senha", default="")
    ap.add_argument("--banco", default="ecommerce")
    args = ap.parse_args(argv)

    conexao = pymysql.connect(
        host=args.host,
        port=args.porta,
        user=args.usuario,
        password=args.senha,
        database=args.banco,
        charset="utf8mb4",
        autocommit=True,
    )

    with conexao, conexao.cursor() as cur:
        cur.execute("SELECT VERSION()")
        versao = cur.fetchone()[0]

        contagens = {}
        for tabela in ("cliente", "produto", "pedido", "produto_pedido", "entrega", "pagamento"):
            cur.execute(f"SELECT COUNT(*) FROM {tabela}")
            contagens[tabela] = cur.fetchone()[0]

        print("medindo sem índices...")
        derrubar_indices(cur)
        antes = medir_tudo(cur)

        print("criando índices e medindo de novo...")
        criar_indices(cur)
        cur.execute("ANALYZE TABLE pedido, produto, entrega")
        cur.fetchall()
        depois = medir_tudo(cur)

        escrever_relatorio(antes, depois, contagens, versao)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
