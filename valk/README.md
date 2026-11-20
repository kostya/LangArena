# LangArena in Valk: notes on the port

LangArena asks for "roughly equivalent code across languages" and says its aim is "not to squeeze
the maximum performance out of each language". So the benchmarks follow the other implementations,
and this code only gets faster through the language and its libraries, such as `json.read` or a
faster regex engine.

There is one place where the implementations differ and the port had to pick a data layout, and
there are four rows where a faster layout exists that the port does not use. Both are listed here.

Times are for the row alone on an AMD Ryzen 5 7600X; a full suite takes about 35 s.

## The layout we picked: maze and Game of Life cells

In every implementation a cell refers to its neighbor cells. How the cells are stored differs:

| Implementation | Cells | Neighbors |
|---|---|---|
| Crystal | One object per cell | An array of cell references per cell |
| C | One block per row | Pointers, in the cell |
| Goose | One pool | References into the pool, in the cell |
| Valk | One `Arena` | `Link`s into the arena, in the cell |

The port uses the layout of the C and Goose versions, which is the fast one in Valk. Crystal's
layout also works in Valk, but it takes three objects per cell and is slower. It is not in the code:

| Row | This port | With one object per cell |
|---|---:|---:|
| `Maze::Generator` | 0.28 s | 1.4 s |
| `Maze::BFS` | 0.24 s | 1.8 s |
| `Maze::AStar` | 0.73 s | 2.4 s |

The cells of `Etc::GameOfLife` are stored the same way.

## Faster layouts we did not use

These rows are written like the other implementations and could be faster with a different layout.
The "possible" times come from separate experiments that are not in the code. Together they would
take about 1.1 s off a full suite.

| Row | This port | Possible | What it would take |
|---|---:|---:|---|
| `Binarytrees::Obj` | 0.35 s | 0.21 s | Nodes in one block. Separate objects are the point of this row: `Binarytrees::Arena` is the flat version |
| `Calculator::Ast` | 0.27 s | 0.08 s | Nodes in one block and names as offsets; `Calculator::Interpreter` could then no longer share the tree |
| `Graph::BFS` | 1.45 s | 0.82 s | All edges in one block instead of one array per vertex, with about 20% more peak memory |
| `Graph::DFS` | 1.08 s | 0.90 s | The same |

`Graph::AStar` hardly changes with flat edges (0.58 to 0.57 s).

One more row has a known gap that the table does not count:

- `Hash::SHA256` (0.79 s) walks its data with `i % 8`, as the C port does. The same loop in C runs
  about 2.5 times as fast with clang when it is written in chunks of 8, and Goose's compiler does
  that rewrite itself. A compiler pass would be within the rules, but we found no other loop that
  indexes an array this way, so we have not built one.
