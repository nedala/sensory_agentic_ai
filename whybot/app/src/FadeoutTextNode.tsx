import React, { useEffect, useState } from "react";
import useMeasure from "react-use-measure";
import { Handle, Position } from "reactflow";
import "./fadeout-text.css";
import classNames from "classnames";
import { NodeDims } from "./GraphPage";
import { useFocused } from "./FocusedContext";
import { MagnifyingGlassIcon, PencilIcon } from "@heroicons/react/24/outline";
import ReactMarkdown from 'react-markdown';

const getScaleFactor = (): number => {
  const viewportElement = document.querySelector(
    ".react-flow__viewport"
  ) as HTMLElement;

  if (!viewportElement) {
    console.error(
      'Element with the classname "react-flow__viewport" not found'
    );
    return 1; // default scale factor
  }

  const style = getComputedStyle(viewportElement);
  const transformValue = style.transform;

  // Example transform value: matrix(1, 0, 0, 1, 0, 0)
  // The scale factor is the first value in the matrix
  const match = /matrix\((.+),/.exec(transformValue);

  if (!match) {
    console.warn(
      "Unable to find scale factor from the element's transform property"
    );
    return 1; // default scale factor
  }

  return parseFloat(match[1]);
};

type FadeoutTextNodeProps = {
  data: {
    text: string;
    nodeID: string;
    setNodeDims: React.Dispatch<React.SetStateAction<NodeDims>>;
    question: boolean;
    isLeaf?: boolean;
    probeFurther?: (nodeId: string) => void;
    onEdit?: (nodeId: string, newText: string) => void;
    questionText?: string;
    answerText?: string;
  };
};
export const FadeoutTextNode: React.FC<FadeoutTextNodeProps & { active?: boolean }> = (props) => {
  const [ref, bounds] = useMeasure();
  const [expanded, setExpanded] = useState(
    // Auto-expand the first question and answer nodes
    props.data.nodeID === "a-0" || props.data.nodeID === "q-0" ? true : false
  );
  const [actualHeight, setActualHeight] = useState(bounds.height);
  const [editing, setEditing] = useState(false);
  const [editValue, setEditValue] = useState(props.data.text);
  useEffect(() => {
    setActualHeight(bounds.height / getScaleFactor());
  }, [bounds.height]);
  const { focusedId, setFocusedId, isInFocusedBranch } = useFocused();

  // Determine if this is a leaf node and if probeFurther is available
  const isLeaf = props.data && props.data.isLeaf;
  const probeFurther = props.data && props.data.probeFurther;
  const nodeId = props.data && props.data.nodeID;
  const onEdit = props.data && props.data.onEdit;

  useEffect(() => {
    const isRoot = props.data.nodeID.slice(2) === "0";
    const isSelected = (focusedId === null && isRoot) || focusedId === props.data.nodeID.slice(2);
    setExpanded(isSelected);
  }, [focusedId, props.data.nodeID]);

  // Expand/collapse based on active prop
  useEffect(() => {
    if (props.active) {
      setExpanded(true);
    } else if (props.active === false) {
      setExpanded(false);
    }
  }, [props.active]);

  return (
    <div
      onClick={() => {
        if (props.data.question) {
          setFocusedId(props.data.nodeID.slice(2));
        }
        setExpanded(true);
        props.data.setNodeDims((prevState) => ({
          ...prevState,
          [props.data.nodeID]: { width: 260, height: actualHeight + 36 },
        }));
      }}
      onMouseDown={(e) => {
        e.stopPropagation();
      }}
      className={classNames("fadeout-text border shadow-lg", {
        "cursor-pointer": !expanded,
        "cursor-default": expanded,
        "border-sky-300": props.data.question,
        "border-white/50": !props.data.question,
        "opacity-40":
          focusedId != null && !isInFocusedBranch(props.data.nodeID.slice(2)),
        "border-yellow-100":
          props.data.question && focusedId === props.data.nodeID.slice(2),
        "ring-4 ring-yellow-300 ring-opacity-60 animate-pulse": props.active, // HALO
      })}
      style={{
        position: "relative",
        borderRadius: 6,
        padding: "16px 18px 14px 18px",
        maxWidth: 260,
        width: 260,
        minHeight: 50,
        overflow: "hidden",
        background: `repeating-linear-gradient(135deg, #fdf6e3 0px, #fdf6e3 18px, #f5ecd7 18px, #f5ecd7 36px)`,
        boxShadow: "0 4px 16px 0 rgba(0,0,0,0.20)",
        height: expanded
          ? Math.max(actualHeight + 16 + 12, 50)
          : Math.max(50, Math.min(140 + 16 + 12, actualHeight + 16 + 12)),
        transition:
          "transform 0.5s, height 0.5s, width 0.5s, opacity 0.15s, border 0.15s",
      }}
    >
      <Handle type={"target"} position={Position.Left} />
      <Handle type={"source"} position={Position.Right} />
      {editing ? (
        <div className="flex flex-col gap-1 min-h-[100px] justify-center p-2">
          <input
            className="border rounded px-2 py-1 text-xs w-full"
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            autoFocus
          />
          <div className="flex gap-1 mt-1">
            <button
              className="px-2 py-1 bg-blue-600 text-white rounded text-xs"
              onClick={() => {
                setEditing(false);
                if (onEdit) onEdit(nodeId, editValue);
              }}
            >
              Save
            </button>
            <button
              className="px-2 py-1 bg-gray-300 text-xs rounded"
              onClick={() => setEditing(false)}
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <>
          <div
            className="fadeout-text-inner h-[140px] select-text"
            style={expanded ? { WebkitMaskImage: "none" } : {}}
          >
            <div ref={ref}>
              <div className="mb-1 mt-1 font-extrabold text-xs text-gray-900">Q: {props.data.questionText}</div>
              {props.data.answerText && (
                <>
                  <hr className="my-2 border-dotted border-t-2 border-gray-300" />
                  <div className="mt-1 text-xs text-gray-800 markdown-body">
                    <ReactMarkdown>{props.data.answerText}</ReactMarkdown>
                  </div>
                </>
              )}
            </div>
          </div>
          {isLeaf && probeFurther && (
            <button
              className="absolute top-1 right-1 p-1 bg-white/80 rounded-full hover:bg-blue-200 shadow"
              title="Probe further"
              onClick={() => probeFurther(nodeId)}
            >
              <MagnifyingGlassIcon className="w-4 h-4 text-blue-700" />
            </button>
          )}
          {props.data.question && (
            <button
              className="absolute top-1 left-1 p-1 bg-white/80 rounded-full hover:bg-yellow-200 shadow"
              title="Edit question"
              onClick={() => setEditing(true)}
            >
              <PencilIcon className="w-4 h-4 text-yellow-700" />
            </button>
          )}
        </>
      )}
    </div>
  );
};
