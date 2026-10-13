// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv struct DagPlan {
  order_ids : Array[String]
  reverse_edge_indices : Array[Int32]
  self_loop_edge_indices : Array[Int32]
}

///|
fn require_index(
  id_to_idx : Map[String, Int32],
  id : String,
) -> Int32 raise @engine_api.LayoutError {
  match id_to_idx.get(id) {
    Some(i) => i
    None => raise Unsupported("unknown object id: \{id}")
  }
}

///|
fn els_ordering_indices(
  n : Int32,
  out_adj : Array[Array[Int32]],
  in_adj : Array[Array[Int32]],
) -> Array[Int32] {
  let indeg = Array::makei(n, i => in_adj[i].length())
  let outdeg = Array::makei(n, i => out_adj[i].length())
  let alive = Array::make(n, true)
  let left : Array[Int32] = []
  let right : Array[Int32] = []
  let mut remaining = n
  let sinks : Array[Int32] = []
  let sources : Array[Int32] = []
  for v in 0..<n {
    if outdeg[v] == 0 {
      sinks.push(v)
    }
    if indeg[v] == 0 {
      sources.push(v)
    }
  }
  let mut sink_i = 0
  let mut source_i = 0
  fn remove_vertex(v : Int32, to_left : Bool) -> Unit {
    alive[v] = false
    remaining = remaining - 1
    if to_left {
      left.push(v)
    } else {
      right.push(v)
    }
    for w in out_adj[v] {
      if alive[w] {
        indeg[w] = indeg[w] - 1
        if indeg[w] == 0 {
          sources.push(w)
        }
      }
    }
    for u in in_adj[v] {
      if alive[u] {
        outdeg[u] = outdeg[u] - 1
        if outdeg[u] == 0 {
          sinks.push(u)
        }
      }
    }
  }

  while remaining > 0 {
    while true {
      let remaining_before = remaining
      while sink_i < sinks.length() {
        let v = sinks[sink_i]
        sink_i = sink_i + 1
        if alive[v] && outdeg[v] == 0 {
          remove_vertex(v, false)
        }
      }
      while source_i < sources.length() {
        let v = sources[source_i]
        source_i = source_i + 1
        if alive[v] && indeg[v] == 0 {
          remove_vertex(v, true)
        }
      }
      if remaining == remaining_before {
        break
      }
    }
    if remaining == 0 {
      break
    }
    let mut best = -1
    let mut best_abs = -1
    let mut best_score = 0
    for v in 0..<n {
      if alive[v] {
        let score = outdeg[v] - indeg[v]
        let a = Int32::abs(score)
        if a > best_abs || (a == best_abs && score > best_score) {
          best = v
          best_abs = a
          best_score = score
        }
      }
    }
    remove_vertex(best, best_score >= 0)
  }
  right.rev_in_place()
  left.append(right)
  left
}

///|
fn tarjan_scc_indices(
  n : Int32,
  out_adj : Array[Array[Int32]],
) -> Array[Array[Int32]] {
  let index = Array::make(n, -1)
  let low = Array::make(n, 0)
  let on_stack = Array::make(n, false)
  let stack : Array[Int32] = []
  let mut time = 0
  let comps : Array[Array[Int32]] = []
  fn dfs(v : Int32) -> Unit {
    index[v] = time
    low[v] = time
    time = time + 1
    stack.push(v)
    on_stack[v] = true
    for w in out_adj[v] {
      if index[w] == -1 {
        dfs(w)
        low[v] = low[v].min(low[w])
      } else if on_stack[w] {
        low[v] = low[v].min(index[w])
      }
    }
    if low[v] == index[v] {
      let comp : Array[Int32] = []
      while stack.pop() is Some(x) {
        on_stack[x] = false
        comp.push(x)
        if x == v {
          break
        }
      }
      comps.push(comp)
    }
  }

  for v in 0..<n {
    if index[v] == -1 {
      dfs(v)
    }
  }
  comps
}

///|
fn els_order_component(
  comp : Array[Int32],
  out_adj : Array[Array[Int32]],
  locals_idx : Array[Int32],
  locals_mark : Array[Int32],
  mark : Int32,
) -> Array[Int32] {
  let k = comp.length()
  if k <= 1 {
    return comp
  }
  for i in 0..<k {
    let v = comp[i]
    locals_idx[v] = i
    locals_mark[v] = mark
  }
  let out_local : Array[Array[Int32]] = Array::makei(k, _ => ([] : Array[Int32]))
  let in_local : Array[Array[Int32]] = Array::makei(k, _ => ([] : Array[Int32]))
  for gu in comp {
    let lu = locals_idx[gu]
    for gv in out_adj[gu] {
      if locals_mark[gv] == mark {
        let lv = locals_idx[gv]
        out_local[lu].push(lv)
        in_local[lv].push(lu)
      }
    }
  }
  let order_local = els_ordering_indices(k, out_local, in_local)
  order_local.map(li => comp[li])
}

///|
fn topo_scc_order(
  scc_count : Int32,
  comp_id : Array[Int32],
  out_adj : Array[Array[Int32]],
) -> Array[Int32] raise @engine_api.LayoutError {
  let scc_out : Array[Array[Int32]] = Array::makei(scc_count, _ => {
    ([] : Array[Int32])
  })
  let indeg = Array::make(scc_count, 0)
  for u in 0..<comp_id.length() {
    let cu = comp_id[u]
    for v in out_adj[u] {
      let cv = comp_id[v]
      if cu != cv {
        scc_out[cu].push(cv)
        indeg[cv] = indeg[cv] + 1
      }
    }
  }
  let q : Array[Int32] = []
  for c in 0..<scc_count {
    if indeg[c] == 0 {
      q.push(c)
    }
  }
  let topo : Array[Int32] = []
  let mut qi = 0
  while qi < q.length() {
    let c = q[qi]
    qi = qi + 1
    topo.push(c)
    for d in scc_out[c] {
      indeg[d] = indeg[d] - 1
      if indeg[d] == 0 {
        q.push(d)
      }
    }
  }
  if topo.length() != scc_count {
    raise Unsupported("unexpected: SCC condensation not a DAG")
  }
  topo
}

///|
fn els_tarjan_plan(
  g : @graph.GraphInput,
) -> DagPlan raise @engine_api.LayoutError {
  let n = g.objects.length()
  let ids : Array[String] = g.objects.map(o => o.id)
  let id_to_idx : Map[String, Int32] = Map([], capacity=n * 2)
  for i in 0..<n {
    id_to_idx.set(ids[i], i)
  }
  let out_adj : Array[Array[Int32]] = Array::makei(n, _ => ([] : Array[Int32]))
  let self_loops : Array[Int32] = []
  for e in g.edges {
    let u = require_index(id_to_idx, e.src_id)
    let v = require_index(id_to_idx, e.dst_id)
    if u == v {
      self_loops.push(e.index)
      continue
    }
    out_adj[u].push(v)
  }
  let comps = tarjan_scc_indices(n, out_adj)
  let scc_count = comps.length()
  let comp_id = Array::make(n, -1)
  for c in 0..<scc_count {
    for v in comps[c] {
      comp_id[v] = c
    }
  }
  let topo = topo_scc_order(scc_count, comp_id, out_adj)
  let order_vertices : Array[Int32] = []
  let locals_idx = Array::make(n, 0)
  let locals_mark = Array::make(n, 0)
  for c in topo {
    let comp = comps[c]
    let ord = els_order_component(comp, out_adj, locals_idx, locals_mark, c + 1)
    order_vertices.append(ord)
  }
  let pos = Array::make(n, -1)
  for i in 0..<order_vertices.length() {
    pos[order_vertices[i]] = i
  }
  let rev_edges : Array[Int32] = []
  for e in g.edges {
    let u = require_index(id_to_idx, e.src_id)
    let v = require_index(id_to_idx, e.dst_id)
    if u == v {
      continue
    }
    if pos[u] > pos[v] {
      rev_edges.push(e.index)
    }
  }
  {
    order_ids: order_vertices.map(i => ids[i]),
    reverse_edge_indices: rev_edges,
    self_loop_edge_indices: self_loops,
  }
}
