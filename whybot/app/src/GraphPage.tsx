import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { FlowProvider, openai } from "./Flow";
import { Edge, MarkerType, Node } from "reactflow";
import {
  ArrowDownTrayIcon,
  ArrowLeftIcon,
  PauseIcon,
  PlayIcon,
} from "@heroicons/react/24/solid";
import { closePartialJson, downloadDataAsJson, exportNetworkX, exportHTML, exportMermaid } from "./util/json";
import { PERSONAS } from "./personas";
import { ApiKey } from "./App";
import { SERVER_HOST } from "./constants";
import { MODELS, Model } from "./models";
import { FocusedContextProvider, isChild } from "./FocusedContext";
import React from "react";

export interface QATreeNode {
  question: string;
  parent?: string;
  answer: string;
  children?: string[];
  startedProcessing?: boolean;
}

export interface QATree {
  [key: string]: QATreeNode;
}

export type NodeDims = {
  [key: string]: {
    width: number;
    height: number;
  };
};

type TreeNode = Node & {
  parentNodeID: string;
};

export const convertTreeToFlow = (
  tree: QATree,
  setNodeDims: any,
  deleteBranch: any,
  playing: boolean,
  probeFurther?: (id: string) => void,
  onEdit?: (nodeId: string, newText: string) => void
): any => {
  const nodes: TreeNode[] = [];
  Object.keys(tree).forEach((key) => {
    const isLeaf = !tree[key].children || tree[key].children.length === 0;
    nodes.push({
      id: key,
      type: "fadeText",
      data: {
        questionText: tree[key].question,
        answerText: tree[key].answer,
        nodeID: key,
        setNodeDims,
        question: true,
        isLeaf,
        probeFurther: isLeaf && probeFurther ? probeFurther : undefined,
        onEdit: onEdit ? (newText: string) => onEdit(key, newText) : undefined,
      },
      position: { x: 0, y: 0 },
      parentNodeID: tree[key].parent != null ? tree[key].parent : "",
    });
  });
  const edges: Edge[] = [];
  nodes.forEach((n) => {
    if (n.parentNodeID != "") {
      edges.push({
        id: `${n.parentNodeID}-${n.id}`,
        type: "deleteEdge",
        source: n.parentNodeID,
        target: n.id,
        data: {
          deleteBranch,
        },
        animated: playing,
        markerEnd: { type: MarkerType.Arrow },
      });
    }
  });

  return { nodes, edges };
};

export interface ScoredQuestion {
  question: string;
  score: number;
}

async function getQuestions(
  apiKey: ApiKey,
  model: string,
  persona: string,
  node: QATreeNode,
  tree: QATree,
  onIntermediate: (partial: ScoredQuestion[]) => void
) {
  const person = PERSONAS[persona];
  if ("getQuestions" in person) {
    onIntermediate(person.getQuestions(node, tree));
    return;
  }
  const promptForQuestions = person.getPromptForQuestions(node, tree);

  let buffer = "";
  let afterThink = false;
  await openai(promptForQuestions, {
    apiKey: apiKey.key,
    temperature: 1,
    model: MODELS[model].key,
    onChunk: (chunk) => {
      buffer += chunk;
      if (!afterThink) {
        const endThinkIdx = buffer.indexOf("</think>");
        if (endThinkIdx !== -1) {
          buffer = buffer.slice(endThinkIdx + 8); // skip past </think>
          afterThink = true;
        } else {
          // Not past </think> yet, do not process
          // But if model never emits <think>, just keep buffering
          return;
        }
      }
      // If afterThink is true, keep buffering
    },
  });
  // At the end, if </think> was never found, use the whole buffer
  let jsonText = buffer;
  if (!afterThink) {
    jsonText = buffer;
  }
  // Prefer ```json ... ``` block if present
  const jsonBlockMatch = jsonText.match(/```json([\s\S]*?)```/);
  if (jsonBlockMatch) {
    jsonText = jsonBlockMatch[1];
  } else {
    // Otherwise, look for first [ or { and parse from there
    const firstJson = jsonText.search(/[\[{]/);
    if (firstJson >= 0) jsonText = jsonText.slice(firstJson);
  }
  jsonText = jsonText.replace(/[`\s]+$/g, '').trim();
  try {
    const parsed = JSON.parse(jsonText);
    console.log("Parsed JSON:", parsed);
    onIntermediate(parsed);
  } catch (e) {
    console.error("Error parsing JSON at end of getQuestions:", e, "The malformed JSON was:", jsonText);
  }
}

interface NodeGeneratorOpts {
  apiKey: ApiKey;
  model: string;
  persona: string;
  questionQueue: string[];
  qaTree: QATree;
  focusedId: string | null;
  onChangeQATree: () => void;
  onNodeGenerated: () => void;
}

async function* nodeGenerator(
  opts: NodeGeneratorOpts
): AsyncIterableIterator<void> {
  while (true) {
    while (opts.questionQueue.length === 0) {
      await new Promise((resolve) => setTimeout(resolve, 100));
      yield;
    }

    console.log("Popped from queue", opts.questionQueue);

    const nodeId = opts.questionQueue.shift();
    if (nodeId == null) {
      throw new Error("Impossible");
    }

    const node = opts.qaTree[nodeId];
    if (node == null) {
      throw new Error(`Node ${nodeId} not found`);
    }
    node.startedProcessing = true;

    const promptForAnswer = PERSONAS[opts.persona].getPromptForAnswer(
      node,
      opts.qaTree
    );

    await openai(promptForAnswer, {
      apiKey: opts.apiKey.key,
      temperature: 0,
      model: MODELS[opts.model].key,
      onChunk: (() => {
        let buffer = "";
        let inThink = false;
        let thoughtBuffer = "";
        let answerBuffer = "";
        return (chunk: string) => {
          buffer += chunk;
          let i = 0;
          while (i < buffer.length) {
            if (!inThink && buffer.startsWith("<think>", i)) {
              inThink = true;
              i += 7;
              continue;
            }
            if (inThink && buffer.startsWith("</think>", i)) {
              inThink = false;
              thoughtBuffer = "";
              answerBuffer = "";
              // Clear node and start fresh for answer
              const node = opts.qaTree[nodeId];
              if (node) node.answer = "";
              opts.onChangeQATree();
              i += 8;
              continue;
            }
            if (inThink) {
              thoughtBuffer += buffer[i];
              // Show animated thought process
              const node = opts.qaTree[nodeId];
              if (node) node.answer = "🤔 " + thoughtBuffer;
              opts.onChangeQATree();
            } else {
              answerBuffer += buffer[i];
              const node = opts.qaTree[nodeId];
              if (node) node.answer = answerBuffer;
              opts.onChangeQATree();
            }
            i++;
          }
          // Remove processed content from buffer
          buffer = "";
        };
      })(),
    });

    yield;

    const ids: string[] = [];
    await getQuestions(
      opts.apiKey,
      opts.model,
      opts.persona,
      node,
      opts.qaTree, // Pass the tree as 5th argument
      (partial) => {
        if (partial.length > ids.length) {
          for (let i = ids.length; i < partial.length; i++) {
            const newId = Math.random().toString(36).substring(2, 9);
            ids.push(newId);
            opts.qaTree[newId] = {
              question: "",
              parent: nodeId,
              answer: "",
            };
            if (opts.qaTree[nodeId].children == null) {
              opts.qaTree[nodeId].children = [newId];
            } else {
              opts.qaTree[nodeId].children?.push(newId);
            }
          }
        }
        for (let i = 0; i < partial.length; i++) {
          opts.qaTree[ids[i]].question = partial[i].question;
        }
        opts.onChangeQATree();
      }
    );

    opts.onNodeGenerated();
    yield;

    ids.forEach((id) => {
      if (
        !opts.qaTree[id].startedProcessing &&
        (!opts.focusedId || isChild(opts.qaTree, opts.focusedId, id))
      ) {
        opts.questionQueue.push(id);
      }
    });
  }
}

class NodeGenerator {
  generator: AsyncIterableIterator<void>;
  playing: boolean;
  ran: boolean;
  destroyed: boolean;
  opts: NodeGeneratorOpts;
  fullyPaused: boolean;
  onFullyPausedChange: (fullyPaused: boolean) => void;

  constructor(
    opts: NodeGeneratorOpts,
    onFullyPausedChange: (fullyPaused: boolean) => void
  ) {
    this.opts = opts;
    this.generator = nodeGenerator(opts);
    this.playing = true;
    this.ran = false;
    this.destroyed = false;
    this.fullyPaused = false;
    this.onFullyPausedChange = onFullyPausedChange;
  }

  setFullyPaused(fullyPaused: boolean) {
    if (this.fullyPaused !== fullyPaused) {
      this.fullyPaused = fullyPaused;
      this.onFullyPausedChange(fullyPaused);
    }
  }

  async run() {
    if (this.ran) {
      throw new Error("Already ran");
    }
    this.ran = true;
    while (true) {
      while (!this.playing) {
        this.setFullyPaused(true);
        if (this.destroyed) {
          break;
        }
        await new Promise((resolve) => setTimeout(resolve, 100));
      }
      this.setFullyPaused(false);
      const { done } = await this.generator.next();
      if (done || this.destroyed) {
        break;
      }
    }
  }

  resume() {
    this.playing = true;
  }

  pause() {
    this.playing = false;
  }

  destroy() {
    this.destroyed = true;
    this.opts.onChangeQATree = () => { };
  }
}

class MultiNodeGenerator {
  // Warning: opts gets mutated a lot, which is probably bad practice.
  opts: NodeGeneratorOpts;
  generators: NodeGenerator[];
  onFullyPausedChange: (fullyPaused: boolean) => void;

  constructor(
    n: number,
    opts: NodeGeneratorOpts,
    onFullyPausedChange: (fullyPaused: boolean) => void
  ) {
    this.opts = opts;
    this.generators = [];
    for (let i = 0; i < n; i++) {
      this.generators.push(
        new NodeGenerator(opts, () => {
          this.onFullyPausedChange(
            this.generators.every((gen) => gen.fullyPaused)
          );
        })
      );
    }
    this.onFullyPausedChange = onFullyPausedChange;
  }

  run() {
    for (const gen of this.generators) {
      gen.run();
    }
  }

  resume() {
    for (const gen of this.generators) {
      gen.resume();
    }
  }

  pause() {
    for (const gen of this.generators) {
      gen.pause();
    }
  }

  destroy() {
    for (const gen of this.generators) {
      gen.destroy();
    }
  }

  setFocusedId(id: string | null) {
    this.opts.focusedId = id;
  }
}

const NODE_LIMIT_PER_PLAY = 8;

function GraphPage(props: {
  seedQuery: string;
  model: string;
  persona: string;
  apiKey: ApiKey;
  onExit(): void;
}) {
  const [resultTree, setResultTree] = useState<QATree>({});
  const questionQueueRef = useRef<string[]>([]);
  const qaTreeRef = useRef<QATree>({});
  const generatorRef = useRef<MultiNodeGenerator>();
  const [playing, setPlaying] = useState(true);
  const [fullyPaused, setFullyPaused] = useState(false);
  const nodeCountRef = useRef(0);
  const pauseAtNodeCountRef = useRef(NODE_LIMIT_PER_PLAY);
  const [saveStatus, setSaveStatus] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    questionQueueRef.current = ["0"];
    qaTreeRef.current = {
      "0": {
        question: props.seedQuery,
        answer: "",
      },
    };
    setResultTree(qaTreeRef.current);

    generatorRef.current = new MultiNodeGenerator(
      2,
      {
        apiKey: props.apiKey,
        model: props.model,
        persona: props.persona,
        questionQueue: questionQueueRef.current,
        qaTree: qaTreeRef.current,
        focusedId: null,
        onChangeQATree: () => {
          setResultTree(JSON.parse(JSON.stringify(qaTreeRef.current)));
          const anyProcessing = Object.values(qaTreeRef.current).some(
            (n: QATreeNode) => !n.answer || n.startedProcessing
          );
          setIsProcessing(anyProcessing);
        },
        onNodeGenerated: () => {
          nodeCountRef.current += 1;
          if (nodeCountRef.current >= pauseAtNodeCountRef.current) {
            pause();
          }
        },
      },
      (fp) => {
        setFullyPaused(fp);
        if (fp && questionQueueRef.current.length === 0) {
          setIsProcessing(false);
        }
      }
    );
    generatorRef.current.run();
    return () => {
      generatorRef.current?.destroy();
    };
  }, [props.model, props.persona, props.seedQuery]);

  const [nodeDims, setNodeDims] = useState<NodeDims>({});

  const deleteBranch = useCallback(
    (id: string) => {
      const qaNode = resultTree[id];
      console.log("deleting qaNode, question", qaNode.question);

      if (id in qaTreeRef.current) {
        delete qaTreeRef.current[id];
        setResultTree(JSON.parse(JSON.stringify(qaTreeRef.current)));
      }

      const children = "children" in qaNode ? qaNode.children ?? [] : [];
      for (var child of children) {
        deleteBranch(child);
      }
    },
    [resultTree, setResultTree]
  );

  const probeFurther = useCallback((id: string) => {
    if (!questionQueueRef.current.includes(id)) {
      questionQueueRef.current.unshift(id); // Insert at the front
      generatorRef.current?.resume();
    }
  }, []);

  const onEdit = useCallback((nodeId: string, newText: string) => {
    // Update the question text
    qaTreeRef.current[nodeId.slice(2)].question = newText;
    // Remove all children recursively
    function removeChildren(id: string) {
      const node = qaTreeRef.current[id];
      if (node && node.children) {
        for (const childId of node.children) {
          removeChildren(childId);
          delete qaTreeRef.current[childId];
          // Remove from queue if present
          const idx = questionQueueRef.current.indexOf(childId);
          if (idx !== -1) questionQueueRef.current.splice(idx, 1);
        }
        node.children = [];
      }
    }
    removeChildren(nodeId.slice(2));
    // Remove from queue if present
    const idx = questionQueueRef.current.indexOf(nodeId.slice(2));
    if (idx !== -1) questionQueueRef.current.splice(idx, 1);
    // Add back to queue for regeneration
    questionQueueRef.current.unshift(nodeId.slice(2));
    setResultTree(JSON.parse(JSON.stringify(qaTreeRef.current)));
    generatorRef.current?.resume();
  }, []);

  const { nodes, edges } = useMemo(() => {
    return convertTreeToFlow(resultTree, setNodeDims, deleteBranch, playing, probeFurther, onEdit);
  }, [resultTree, playing, probeFurther, onEdit]);

  function resume() {
    pauseAtNodeCountRef.current = nodeCountRef.current + NODE_LIMIT_PER_PLAY;
    generatorRef.current?.resume();
    setPlaying(true);
  }

  function pause() {
    generatorRef.current?.pause();
    setPlaying(false);
  }

  const handleSaveAsExample = async () => {
    setSaveStatus("Saving...");
    try {
      const resp = await fetch("/api/save-example", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          persona: props.persona,
          model: props.model,
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

  // Export handlers (now using shared utils)
  const handleExportNetworkX = () => exportNetworkX(resultTree);
  const handleExportHTML = () => exportHTML(resultTree);
  const handleExportMermaid = () => exportMermaid(resultTree);

  return (
    <FocusedContextProvider
      qaTree={resultTree}
      onSetFocusedId={(id) => {
        generatorRef.current?.setFocusedId(id);
        const newQueue: string[] = [];
        for (const [id, node] of (Object.entries(resultTree) as [string, QATreeNode][])) {
          if (
            !node.children &&
            !node.answer &&
            (id == null || isChild(resultTree, id, id))
          ) {
            newQueue.push(id);
          }
        }
        console.log("setting queue", questionQueueRef.current);
        questionQueueRef.current.splice(
          0,
          questionQueueRef.current.length,
          ...newQueue
        );
        console.log("set queue", questionQueueRef.current);
      }}
    >
      <div className="text-sm">
        <FlowProvider
          flowNodes={nodes}
          flowEdges={edges}
          nodeDims={nodeDims}
          deleteBranch={deleteBranch}
          playQueue={questionQueueRef.current}
          handleExportHTML={handleExportHTML}
          handleExportMermaid={handleExportMermaid}
          handleExportNetworkX={handleExportNetworkX}
          handleSaveAsExample={handleSaveAsExample}
          saveStatus={saveStatus}
        />
        <div className="fixed right-4 bottom-4 flex items-center space-x-2 z-50">
          {SERVER_HOST.includes("") && (
            <div
              className="bg-black/40 p-2 flex items-center justify-center rounded cursor-pointer hover:text-green-400 backdrop-blur"
              onClick={() => {
                // we want to save the current resultTree as JSON
                const filename = props.seedQuery
                  .toLowerCase()
                  .replace(/\s+/g, "-");
                const dict: any = {
                  persona: props.persona,
                  model: props.model,
                  tree: { ...resultTree },
                };
                downloadDataAsJson(dict, filename);
              }}
            >
              <ArrowDownTrayIcon className="w-5 h-5" />
            </div>
          )}
          <div className="bg-black/40 p-2 pl-3 rounded flex items-center space-x-3 backdrop-blur touch-none">
            <div className="text-white/60 select-none">
              {PERSONAS[props.persona].name} • {MODELS[props.model].name}
            </div>
            <div
              className="rounded-full bg-white/20 w-5 h-5 flex items-center justify-center cursor-pointer hover:bg-white/30"
              onClick={() => {
                if (playing) {
                  pause();
                } else {
                  resume();
                }
              }}
            >
              {playing ? (
                <PauseIcon className="w-4 h-4" />
              ) : fullyPaused ? (
                <PlayIcon className="w-4 h-4" />
              ) : (
                <PlayIcon className="w-4 h-4 animate-pulse" />
              )}
            </div>
            {/* Animated queue/in-flight status */}
            <QueueStatus
              isProcessing={isProcessing}
              fullyPaused={fullyPaused}
            />
          </div>
        </div>
        {/* Add status indicator below toolbar */}
        {/* <div className="fixed right-4 bottom-2 z-50">
          <QueueStatus inFlight={!fullyPaused} />
        </div> */}
        <div
          onClick={() => {
            props.onExit();
          }}
          className="fixed top-4 left-4 bg-black/40 rounded p-2 cursor-pointer hover:bg-black/60 backdrop-blur touch-none"
        >
          <ArrowLeftIcon className="w-5 h-5" />
        </div>
      </div>
    </FocusedContextProvider>
  );
}

// Update QueueStatus to accept isProcessing and fullyPaused only, and update its logic
function QueueStatus({ isProcessing, fullyPaused }: { isProcessing: boolean; fullyPaused: boolean }) {
  const [dotCount, setDotCount] = useState(0);
  useEffect(() => {
    if (isProcessing && !fullyPaused) {
      const interval = setInterval(() => {
        setDotCount((c: number) => (c + 1) % 4);
      }, 500);
      return () => clearInterval(interval);
    } else {
      setDotCount(0);
    }
  }, [isProcessing, fullyPaused]);
  if (!isProcessing || fullyPaused) {
    return <span className="text-green-400 text-xs ml-2">Idle</span>;
  }
  return (
    <span className="text-yellow-300 text-xs ml-2">
      Processing{'.'.repeat(dotCount)}
    </span>
  );
}

// @ts-ignore
declare global {
  namespace JSX {
    interface IntrinsicElements {
      [elemName: string]: any;
    }
  }
}

export default GraphPage;
