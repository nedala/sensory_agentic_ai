import React, { useEffect, useRef } from "react";

import ReactFlow, {
  Edge,
  Node,
  Position,
  ReactFlowProvider,
  useEdgesState,
  useNodesState,
  useReactFlow,
} from "reactflow";
import dagre from "dagre";

import "reactflow/dist/style.css";
import { FadeoutTextNode } from "./FadeoutTextNode";
import { DeletableEdge } from "./DeletableEdge";
import { NodeDims } from "./GraphPage";
import { getFingerprint } from "./main";
import { SERVER_HOST_WS } from "./constants";

const nodeTypes = { fadeText: FadeoutTextNode };
const edgeTypes = { deleteEdge: DeletableEdge };

// Layout the nodes automatically
const layoutElements = (
  nodes: Node[],
  edges: Edge[],
  nodeDims: NodeDims,
  direction = "LR"
) => {
  const isHorizontal = direction === "LR";
  const dagreGraph = new dagre.graphlib.Graph();
  dagreGraph.setDefaultEdgeLabel(() => ({}));

  const nodeWidth = 360;
  const nodeHeight = 240;
  dagreGraph.setGraph({ rankdir: direction, nodesep: 100 });

  nodes.forEach((node) => {
    if (node.id in nodeDims) {
      dagreGraph.setNode(node.id, {
        width: nodeDims[node.id]["width"],
        height: nodeDims[node.id]["height"],
      });
    } else {
      dagreGraph.setNode(node.id, { width: nodeWidth, height: nodeHeight });
    }
  });

  edges.forEach((edge) => {
    dagreGraph.setEdge(edge.source, edge.target);
  });

  dagre.layout(dagreGraph);

  nodes.forEach((node) => {
    const nodeWithPosition = dagreGraph.node(node.id);
    node.targetPosition = isHorizontal ? Position.Left : Position.Top;
    node.sourcePosition = isHorizontal ? Position.Right : Position.Bottom;

    // We are shifting the dagre node position (anchor=center center) to the top left
    // so it matches the React Flow node anchor point (top left).
    node.position = {
      x: nodeWithPosition.x - nodeWidth / 2 + 60,
      y: nodeWithPosition.y - nodeHeight / 2 + 60,
    };

    return node;
  });

  return { nodes, edges };
};

// Always use relative path for WebSocket server so nginx can proxy
const WS_SERVER = "/ws";

export const openai_server = async (
  prompt: string,
  opts: {
    model: string;
    temperature: number;
    num_predict?: number;
    onChunk: (chunk: string) => void;
  }
) => {
  const fingerprint = await getFingerprint();
  return new Promise((resolve, reject) => {
    if (opts.temperature < 0 || opts.temperature > 1) {
      console.error(
        `Temperature is set to an invalid value: ${opts.temperature}`
      );
      return;
    }
    const ws = new WebSocket(`${WS_SERVER}?fp=${fingerprint}`);
    ws.onopen = () => {
      ws.send(
        JSON.stringify({
          prompt,
          model: opts.model,
          temperature: opts.temperature,
          num_predict: 1024,
        })
      );
    };
    ws.onmessage = (event) => {
      const message = event.data;
      if (message === "[DONE]") {
        resolve(message);
        ws.close();
      } else {
        opts.onChunk(message);
      }
    };
    ws.onerror = (error) => {
      console.error("WebSocket error:", error);
      reject(error);
    };
    ws.onclose = (event) => {
      console.log("WebSocket connection closed:", event);
    };
  });
};

// Function to get streaming openai completion
export const openai = async (
  prompt: string,
  opts: {
    apiKey?: string;
    model: string;
    temperature: number;
    onChunk: (chunk: string) => void;
  }
) => {
  // Always use the local backend
  return openai_server(prompt, {
    model: opts.model,
    temperature: opts.temperature,
    onChunk: opts.onChunk,
  });
};

type FlowProps = {
  flowNodes: Node[];
  flowEdges: Edge[];
  nodeDims: NodeDims;
  deleteBranch: (id: string) => void;
};
export const Flow: React.FC<FlowProps> = (props) => {
  const [nodes, setNodes, onNodesChangeDefault] = useNodesState<Node[]>(
    props.flowNodes
  );
  const [edges, setEdges, onEdgesChangeDefault] = useEdgesState<Edge[]>(
    props.flowEdges
  );

  const reactFlowInstance = useReactFlow();
  const prevActiveNodeRef = useRef<string | null>(null);

  // Use the head of the play queue (questionQueueRef.current) as the selected/active node
  // and set it as focused/expanded for animation
  const playQueue = (props as any).playQueue || [];
  const [activeNodeId, setActiveNodeId] = React.useState<string | null>(null);

  // Get the root question for display
  const rootNode = nodes.find((n: any) => n.id === "0");
  const rootQuestion = rootNode?.data?.questionText || "";
  const [typedRoot, setTypedRoot] = React.useState("");
  useEffect(() => {
    if (!rootQuestion) return;
    let i = 0;
    setTypedRoot("");
    function typeNext() {
      if (i <= rootQuestion.length) {
        setTypedRoot(rootQuestion.slice(0, i));
        i++;
        setTimeout(typeNext, 18);
      }
    }
    typeNext();
  }, [rootQuestion]);

  useEffect(() => {
    // The first node in the play queue is the active node
    const activeId = playQueue.length > 0 ? playQueue[0] : null;
    setActiveNodeId(activeId);
    if (activeId) {
      // Center and zoom to the active node
      const activeNode = nodes.find((n: any) => n.id === activeId);
      if (reactFlowInstance && activeNode) {
        reactFlowInstance.setCenter(
          activeNode.position.x + (activeNode.width || 0) / 2,
          activeNode.position.y + (activeNode.height || 0) / 2,
          { zoom: 1.2, duration: 600 }
        );
      }
    }
  }, [nodes, edges, playQueue]);

  // Pass activeNodeId as prop to nodeTypes for halo/animation
  const nodeTypesWithActive = React.useMemo(() => {
    return {
      fadeText: (nodeProps: any) => (
        <FadeoutTextNode
          {...nodeProps}
          active={activeNodeId === nodeProps.id}
        />
      ),
    };
  }, [activeNodeId]);

  // When a node is selected, center and zoom to it, and expand it (collapse others)
  useEffect(() => {
    const handler = (e: CustomEvent) => {
      const nodeId = e.detail;
      const node = nodes.find((n) => n.id === nodeId);
      if (node) {
        reactFlowInstance.setCenter(
          node.position.x + (node.width || 180) / 2,
          node.position.y + (node.height || 120) / 2,
          { zoom: 1.2, duration: 600 }
        );
      }
    };
    window.addEventListener('focus-node', handler as EventListener);
    return () => window.removeEventListener('focus-node', handler as EventListener);
  }, [nodes, reactFlowInstance]);

  useEffect(() => {
    const handler = () => {
      reactFlowInstance.fitView({ padding: 0.2 });
    };
    window.addEventListener('autofit-flow-canvas', handler);
    return () => window.removeEventListener('autofit-flow-canvas', handler);
  }, [reactFlowInstance]);

  // when props.flowNodes changes, then I need to call setNodes
  useEffect(() => {
    setNodes(() => {
      return props.flowNodes;
    });
  }, [props.flowNodes]);

  useEffect(() => {
    setEdges(() => {
      return props.flowEdges;
    });
  }, [props.flowEdges]);

  // Listen for autofit event
  useEffect(() => {
    function handleAutofit() {
      reactFlowInstance.fitView({ padding: 0.2 });
    }
    window.addEventListener('autofit-flow-canvas', handleAutofit);
    return () => {
      window.removeEventListener('autofit-flow-canvas', handleAutofit);
    };
  }, [reactFlowInstance]);

  const laid = React.useMemo(
    () => layoutElements(nodes, edges, props.nodeDims),
    [nodes, edges, props.nodeDims]
  );

  // Toolbar button handlers to avoid passing them to ReactFlow
  const handleExportHTML = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (props.handleExportHTML) props.handleExportHTML();
  };
  const handleExportMermaid = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (props.handleExportMermaid) props.handleExportMermaid();
  };
  const handleExportNetworkX = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (props.handleExportNetworkX) props.handleExportNetworkX();
  };
  const handleSaveAsExample = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (props.handleSaveAsExample) props.handleSaveAsExample();
  };

  return (
    <div className="w-full h-full fixed top-0 left-0">
      {/* Root question at top center with typing effect */}
      <div className="absolute top-32 left-1/2 -translate-x-1/2 z-50 text-center w-max pointer-events-none select-none">
        <span className="font-semibold text-2xl md:text-3xl text-blue-500 drop-shadow-lg">
          {typedRoot}
        </span>
      </div>
      {/* Toolbar for export/save actions - always visible */}
      <div className="absolute top-4 right-32 z-50 flex flex-row gap-2 backdrop-blur-md rounded-lg shadow-lg px-3 py-2 items-center border border-gray-500">
        <button
          title="Export HTML"
          className="text-xs px-3 py-1 rounded bg-blue-100 hover:bg-gray-200 text-gray-700 transition-colors"
          onClick={handleExportHTML}
        >
          HTML
        </button>
        <button
          title="Export Mermaid"
          className="text-xs px-3 py-1 rounded bg-blue-100 hover:bg-gray-200 text-gray-700 transition-colors"
          onClick={handleExportMermaid}
        >
          Mermaid
        </button>
        <button
          title="Export NetworkX"
          className="text-xs px-3 py-1 rounded bg-blue-100 hover:bg-gray-200 text-gray-700 transition-colors"
          onClick={handleExportNetworkX}
        >
          NetworkX
        </button>
      </div>
      <ReactFlow
        panOnScroll
        minZoom={0.1}
        nodeTypes={nodeTypesWithActive}
        edgeTypes={edgeTypes}
        nodes={laid.nodes}
        edges={laid.edges}
        onNodesChange={onNodesChangeDefault}
        onEdgesChange={onEdgesChangeDefault}
        {...props}
      ></ReactFlow>
      <button
        className="absolute top-4 right-4 z-50 bg-gray-700 text-white px-3 py-2 rounded text-xs hover:bg-gray-800"
        onClick={() => reactFlowInstance.fitView({ padding: 0.2 })}
      >
        Fit to Page
      </button>
    </div>
  );
};

type FlowProviderProps = {
  flowNodes: Node[];
  flowEdges: Edge[];
  nodeDims: NodeDims;
  deleteBranch: (id: string) => void;
};
export const FlowProvider: React.FC<FlowProviderProps> = (props: FlowProviderProps) => {
  return (
    <ReactFlowProvider>
      <Flow {...props} />
    </ReactFlowProvider>
  );
};
