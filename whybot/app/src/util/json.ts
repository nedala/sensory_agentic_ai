export function closePartialJson(jsonString: string): string {
  let output = "";
  let bracketStack: string[] = [];

  for (let i = 0; i < jsonString.length; i++) {
    let currentChar = jsonString.charAt(i);
    let prevChar = jsonString.charAt(i - 1);

    if (currentChar === "{" || currentChar === "[") {
      bracketStack.push(currentChar);
    } else if (currentChar === "}" || currentChar === "]") {
      if (bracketStack.length === 0) {
        // Ignore invalid closing brackets
        continue;
      }

      let matchingOpeningBracket = bracketStack.pop();
      if (
        (currentChar === "}" && matchingOpeningBracket !== "{") ||
        (currentChar === "]" && matchingOpeningBracket !== "[")
      ) {
        // Ignore unmatched closing brackets
        continue;
      }
    } else if (currentChar === '"' && prevChar !== "\\") {
      let lastBracket = bracketStack[bracketStack.length - 1];
      if (lastBracket === '"') {
        bracketStack.pop();
      } else {
        bracketStack.push(currentChar);
      }
    } else if (currentChar === "," && i === jsonString.length - 1) {
      // Skip dangling commas
      continue;
    }

    output += currentChar;
  }

  while (bracketStack.length > 0) {
    let bracket = bracketStack.pop();
    if (bracket === "{") {
      output += "}";
    } else if (bracket === "[") {
      output += "]";
    } else if (bracket === '"') {
      output += '"';
    }
  }

  return output;
}

// Function to download data as JSON file
export function downloadDataAsJson(data: any, filename: string) {
  const json = JSON.stringify(data);
  const blob = new Blob([json], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// Reusable export handlers for QA trees
export function exportNetworkX(resultTree: any, filenamePrefix = "qa_graph") {
  const nodes = (Object.entries(resultTree) as [string, any][]) // QATreeNode
    .filter(([_id, node]) => node.answer && node.answer.trim() !== "")
    .map(([id, node]) => ({ id, ...node }));
  const edges = nodes.flatMap((n: any) => (n.children || []).map((child: string) => [n.id, child]));
  const py = [
    'import networkx as nx',
    'G = nx.DiGraph()'
  ];
  for (const n of nodes) {
    py.push(`G.add_node('${n.id}', question=${JSON.stringify(n.question)}, answer=${JSON.stringify(n.answer)})`);
  }
  for (const [src, tgt] of edges) {
    py.push(`G.add_edge('${src}', '${tgt}')`);
  }
  py.push('print(nx.info(G))');
  const blob = new Blob([py.join('\n')], { type: 'text/x-python' });
  let rootQ = (resultTree["0"]?.question as string) || filenamePrefix;
  rootQ = rootQ.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 48);
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${rootQ || filenamePrefix}.py`;
  a.click();
  URL.revokeObjectURL(a.href);
}

export function exportHTML(resultTree: any, filenamePrefix = "qa_graph") {
  let html = '<html><head><title>QA Graph Dossier</title></head><body>';
  html += `<h1>QA Graph Dossier</h1>`;
  let qNum = 1;
  for (const [_id, node] of Object.entries(resultTree) as [string, any][]) {
    if (node.answer && node.answer.trim() !== "") {
      html += `<div style='margin-bottom:1em;'><b>${qNum}. Q:</b> ${node.question}<br/><b>A:</b> ${node.answer || ''}</div>`;
      qNum++;
    }
  }
  html += '</body></html>';
  const blob = new Blob([html], { type: 'text/html' });
  let rootQ = (resultTree["0"]?.question as string) || filenamePrefix;
  rootQ = rootQ.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 48);
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${rootQ || filenamePrefix}.html`;
  a.click();
  URL.revokeObjectURL(a.href);
}

export function exportMermaid(resultTree: any, filenamePrefix = "qa_graph") {
  const nodes = (Object.entries(resultTree) as [string, any][]) // QATreeNode
    .filter(([_id, node]) => node.answer && node.answer.trim() !== "")
    .map(([id, node]) => ({ id, ...node }));
  const validIds = new Set(nodes.map((n: any) => n.id));
  function escapeMermaid(text: string) {
    return text
      .replace(/\n/g, " ")
      .replace(/\|/g, "\\|")
      .replace(/[()\[\]{}:]/g, " ")
      .replace(/"/g, "'")
      .replace(/'/g, "\'");
  }
  function buildMermaid(id: string, depth: number): string {
    const node = resultTree[id] as any;
    if (!node || !node.answer || !validIds.has(id)) return "";
    let indent = "  ".repeat(depth);
    let q = escapeMermaid(node.question);
    let a = escapeMermaid(node.answer);
    let str = `${indent}${q} (Answer ${a})\n`;
    if (node.children) {
      for (const child of node.children) {
        if (validIds.has(child)) {
          str += buildMermaid(child, depth + 1);
        }
      }
    }
    return str;
  }
  let mermaid = "mindmap\n  root\n" + buildMermaid("0", 2);
  const blob = new Blob([mermaid], { type: 'text/plain' });
  let rootQ = (resultTree["0"]?.question as string) || filenamePrefix;
  rootQ = rootQ.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 48);
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${rootQ || filenamePrefix}.mmd`;
  a.click();
  URL.revokeObjectURL(a.href);
}
