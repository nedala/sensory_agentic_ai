import { useEffect, useMemo, useState, Dispatch, SetStateAction } from "react";
import { FlowProvider } from "./Flow";
import { convertTreeToFlow, NodeDims, QATree } from "./GraphPage";
import { ArrowLeftIcon } from "@heroicons/react/24/solid";
import { Example } from "./App";
import "./GraphPageExample.css";
import { exportNetworkX, exportHTML, exportMermaid } from "./util/json";
import { PERSONAS } from "./personas";
import { MODELS } from "./models";

export const streamQuestion = async (
  id: string,
  growingTree: QATree,
  exampleTree: QATree,
  setResultTree: Dispatch<SetStateAction<QATree>>
) => {
  return new Promise((resolve) => {
    const node = exampleTree[id];

    let i = 0;
    const intervalQuestion = setInterval(() => {
      i += 5;
      growingTree[id].question = node.question.slice(0, i);
      setResultTree((prevState) => {
        return { ...prevState, ...growingTree };
      });
      if (i >= node.question.length) {
        clearInterval(intervalQuestion);
        resolve("done streaming question");
      }
    }, 5);
  });
};

export const streamAnswer = async (
  id: string,
  growingTree: QATree,
  exampleTree: QATree,
  setResultTree: Dispatch<SetStateAction<QATree>>
) => {
  return new Promise((resolve) => {
    const node = exampleTree[id];
    let i = 0;
    const intervalAnswer = setInterval(() => {
      i += 5;
      growingTree[id].answer = node.answer.slice(0, i);
      setResultTree((prevState) => {
        return { ...prevState, ...growingTree };
      });
      if (i >= node.answer.length) {
        clearInterval(intervalAnswer);
        resolve("done streaming answer");
      }
    }, 5);
  });
};

export const streamQANode = async (
  id: string,
  growingTree: QATree,
  exampleTree: QATree,
  setResultTree: Dispatch<SetStateAction<QATree>>
) => {
  return new Promise(async (resolve) => {
    // reference text
    const node = exampleTree[id];

    if (!(id in growingTree)) {
      growingTree[id] = {
        question: "",
        answer: "",
        parent: node.parent,
        children: node.children,
      };
    }

    await streamQuestion(id, growingTree, exampleTree, setResultTree);
    await streamAnswer(id, growingTree, exampleTree, setResultTree);
    resolve("done streaming node");
  });
};

export const streamExample = async (
  example: Example,
  setResultTree: Dispatch<SetStateAction<QATree>>
) => {
  const growingTree: QATree = {};
  const exampleTree = example.tree;
  let layer: string[] = ["0"];
  await streamQANode("0", growingTree, exampleTree, setResultTree);
  while (true) {
    if (layer.length === 0) {
      break;
    }
    let nextLayer: string[] = [];
    for (const id of layer) {
      if (id in exampleTree && exampleTree[id].children != null) {
        const children: string[] = exampleTree[id].children!;
        nextLayer = [...nextLayer, ...children];
      }
    }
    const promises = [];
    for (const id of nextLayer) {
      promises.push(streamQANode(id, growingTree, exampleTree, setResultTree));
    }
    await Promise.all(promises);
    layer = nextLayer;
  }
};

type GraphPageExampleProps = {
  example: Example;
  onExit(): void;
};
// `exampleTree` holds the complete graph of the example
// `resultTree` is actually rendered & grows over time to become `exampleTree`
export function GraphPageExample({ example, onExit }: GraphPageExampleProps) {
  const [resultTree, setResultTree] = useState<QATree>({});
  const [nodeDims, setNodeDims] = useState<NodeDims>({});
  const [saveStatus, setSaveStatus] = useState<string | null>(null);
  const { nodes, edges } = useMemo(() => {
    return convertTreeToFlow(resultTree, setNodeDims, () => {}, true);
  }, [resultTree]);

  // Build a playQueue from the current growingTree keys in order
  const playQueue = Object.keys(resultTree);

  useEffect(() => {
    streamExample(example, setResultTree);
  }, [example]);

  // Export handlers (now using shared utils)
  const handleExportNetworkX = () => exportNetworkX(resultTree);
  const handleExportHTML = () => exportHTML(resultTree);
  const handleExportMermaid = () => exportMermaid(resultTree);

  const handleSaveAsExample = async () => {
    setSaveStatus("Saving...");
    try {
      const resp = await fetch("/api/save-example", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          persona: example.persona,
          model: example.model,
          tree: resultTree,
        }),
      });
      if (resp.ok) {
        setSaveStatus("Saved!");
      } else {
        const data = await resp.json();
        setSaveStatus(data.message || "Failed to save");
      }
    } catch (e) {
      setSaveStatus("Failed to save");
    }
    setTimeout(() => setSaveStatus(null), 2000);
  };

  return (
    <div className="text-sm graph-page-example">
      <FlowProvider
        flowNodes={nodes}
        flowEdges={edges}
        nodeDims={nodeDims}
        deleteBranch={() => {}}
        playQueue={playQueue}
        handleExportHTML={handleExportHTML}
        handleExportMermaid={handleExportMermaid}
        handleExportNetworkX={handleExportNetworkX}
        handleSaveAsExample={handleSaveAsExample}
        saveStatus={saveStatus}
      />
      <div
        onClick={() => {
          onExit();
        }}
        className="absolute top-4 left-4 bg-black/40 rounded p-2 cursor-pointer hover:bg-black/60 backdrop-blur touch-none"
      >
        <ArrowLeftIcon className="w-5 h-5" />
      </div>
    </div>
  );
}
