import { useState, Dispatch, SetStateAction, useEffect } from "react";
import { openai } from "./Flow";
import "./index.css";
import { PaperAirplaneIcon, InformationCircleIcon } from "@heroicons/react/24/outline";
import classNames from "classnames";
import TextareaAutosize from "react-textarea-autosize";
import { QATree } from "./GraphPage";
import { PERSONAS } from "./personas";
import { useQuery } from "@tanstack/react-query";
import { getFingerprint } from "./main";
import { SERVER_HOST } from "./constants";
import { MODELS } from "./models";
import Dropdown from "./Dropdown";
import { PlayCircleIcon } from "@heroicons/react/24/outline";
import { APIInfoModal, APIKeyModal, ApiKey } from "./APIKeyModal";
import { Link } from "react-router-dom";
import { collection, addDoc } from "firebase/firestore";
import { db } from "./firebase";
import { Sidebar } from "./CollapsibleSidebar";

export type Example = {
    persona: string;
    model: string;
    tree: QATree;
};

function StartPage(props: {
    model: string;
    persona: string;
    apiKey: ApiKey;
    onSubmitPrompt: (prompt: string) => void;
    onSetModel: (model: string) => void;
    onSetPersona: (persona: string) => void;
    onSetExample: (example: Example) => void;
    setApiKey: Dispatch<SetStateAction<ApiKey>>;
}) {
    const [query, setQuery] = useState("");
    const [isInfoModalOpen, setIsInfoModalOpen] = useState(false);
    const [isApiKeyModalOpen, setIsApiKeyModalOpen] = useState(false);
    const [isSidebarOpen, setSidebarOpen] = useState(false);

    const promptsRemainingQuery = useQuery({
        queryKey: ["promptsRemaining"],
        queryFn: async () => {
            const result = await fetch(
                `${SERVER_HOST}/api/prompts-remaining?model=${props.model}&fp=${await getFingerprint()}`
            );
            return result.json();
        },
    });

    useEffect(() => {
        promptsRemainingQuery.refetch();
    }, [props.model]);

    // On mount, check for ?question=... in the URL and pre-populate the query field
    useEffect(() => {
        const params = new URLSearchParams(window.location.search);
        const q = params.get("question");
        if (q) setQuery(q);
    }, []);

    // console.log("prompts remaining", promptsRemainingQuery);
    const promptsRemaining =
        promptsRemainingQuery.isLoading || promptsRemainingQuery.error ? "?" : promptsRemainingQuery.data.remaining;
    const disableEverything = !props.model.startsWith("ollama/") && promptsRemaining === 0 && !props.apiKey.valid;

    const examplesQuery = useQuery({
        queryKey: ["examples"],
        queryFn: async () => {
            const result = await fetch(`${SERVER_HOST}/api/examples`);
            return result.json();
        },
    });
    const examples: Example[] = examplesQuery.isLoading ? [] : examplesQuery.data;

    async function submitPrompt() {
        props.onSubmitPrompt(query);
        if (!props.apiKey.valid) {
            fetch(`${SERVER_HOST}/api/use-prompt?model=${props.model}&fp=${await getFingerprint()}`);
        }

        try {
            const docRef = await addDoc(collection(db, "prompts"), {
                userId: await getFingerprint(),
                model: props.model,
                persona: props.persona,
                prompt: query,
                createdAt: new Date(),
                href: window.location.href,
                usingPersonalApiKey: props.apiKey.valid,
            });
            console.log("Document written with ID: ", docRef.id);
        } catch (e) {
            console.error("Error adding document: ", e);
        }
    }

    const [randomQuestionLoading, setRandomQuestionLoading] = useState(false);

    return (
        <>
            <div className="m-4">
                <div className="flex justify-end items-center gap-4 mr-8 space-x-4">
                    <Sidebar
                        toggleSidebar={() => {
                            setSidebarOpen(!isSidebarOpen);
                        }}
                        isOpen={isSidebarOpen}
                        persona={props.persona}
                        onSetPersona={props.onSetPersona}
                        model={props.model}
                        onSetModel={props.onSetModel}
                    />
                    <div className="flex items-center gap-4 flex-wrap">
                        {props.apiKey.valid ? (
                            <div
                                className="flex space-x-1 cursor-pointer opacity-80 hover:opacity-90"
                                onClick={() => {
                                    setIsApiKeyModalOpen(true);
                                }}
                            >
                                <div className="border-b border-dashed border-gray-300 text-sm text-gray-300">
                                    Using personal API key
                                </div>
                                <InformationCircleIcon className="h-5 w-5 text-gray-400" />
                            </div>
                        ) : (
                            <div
                                className="flex items-center space-x-1 cursor-pointer opacity-80 hover:text-gray-100"
                                onClick={() => {
                                    setIsInfoModalOpen(true);
                                }}
                            >
                                {!props.model.startsWith("ollama/") && (
                                    <div
                                        className={classNames(
                                            "border-b border-dashed border-gray-300 text-sm text-gray-300 shrink-0",
                                            {
                                                "text-white rounded px-2 py-1 border-none bg-red-700 hover:bg-red-800":
                                                    disableEverything,
                                            }
                                        )}
                                    >
                                        {promptsRemaining} prompt{promptsRemaining === 1 ? "" : "s"} left
                                        {promptsRemaining < 5 && "—use own API key?"}
                                    </div>
                                )}
                                {!disableEverything && <InformationCircleIcon className="h-5 w-5 text-gray-400" />}
                            </div>
                        )}
                    </div>
                    <div>
                        <Link className="text-sm text-white/70 mt-1 hover:text-white/80" to="/about">
                            About
                        </Link>
                    </div>
                </div>
                <APIInfoModal
                    open={isInfoModalOpen}
                    onClose={() => {
                        setIsInfoModalOpen(false);
                    }}
                    setApiKeyModalOpen={() => {
                        setIsApiKeyModalOpen(true);
                    }}
                />
                <APIKeyModal
                    open={isApiKeyModalOpen}
                    onClose={() => {
                        setIsApiKeyModalOpen(false);
                    }}
                    apiKey={props.apiKey}
                    setApiKey={props.setApiKey}
                />
            </div>
            <div className="w-full max-w-4xl mx-auto flex flex-col mt-20 px-6 fs-unmask">
                <div
                    className={classNames("fs-unmask", {
                        "opacity-30 cursor-not-allowed": disableEverything,
                    })}
                >
                    <div
                        className={classNames("fs-unmask", {
                            "pointer-events-none": disableEverything,
                        })}
                    >
                        <div className="mb-4 fs-unmask">What would you like to understand?</div>
                        <div className="flex space-x-2 items-center mb-4 fs-unmask w-full max-w-2xl">
                            <TextareaAutosize
                                disabled={disableEverything}
                                className="fs-unmask w-full text-2xl outline-none bg-transparent border-b border-white/40 focus:border-white overflow-hidden shrink font-extrabold italic text-blue-300"
                                placeholder="What | Why | When | How | Where | Who..."
                                value={query}
                                onChange={(e) => {
                                    setQuery(e.target.value);
                                }}
                                onKeyDown={(e) => {
                                    if (e.key === "Enter") {
                                        submitPrompt();
                                    }
                                }}
                            />
                            <PaperAirplaneIcon
                                className={classNames("w-5 h-5 shrink-0 text-blue-300", {
                                    "opacity-30": !query,
                                    "cursor-pointer": query,
                                })}
                                onClick={async () => {
                                    if (query) {
                                        submitPrompt();
                                    }
                                }}
                            />
                        </div>
                        <div className={"flex space-x-4 items-center cursor-pointer group"}>
                            <svg
                                xmlns="http://www.w3.org/2000/svg"
                                fill="none"
                                viewBox="0 0 24 24"
                                strokeWidth={2}
                                stroke="currentColor"
                                className="w-6 h-6 text-blue-500"
                            >
                                <path
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    d="M4 12h16m0 0l-6-6m6 6l-6 6"
                                />
                            </svg>
                            <div className="flex items-center space-x-2">
                                <div
                                    className={"text-sm opacity-70 group-hover:opacity-80"}
                                    onClick={async () => {
                                        setQuery("");
                                        setRandomQuestionLoading(true);
                                        const prompt = `Generate a single, interesting [what|why|who|when|where|how] question that a curious researcher may explore (in 16 words or less). Please prefer a "Jeopardy style short trivia" question. Do not answer it. Only write the question, with no quotes.`;
                                        let question = "";
                                        let finalQuestion = "";
                                        await openai(prompt, {
                                            model: props.model, // use the selected model from sidebar
                                            apiKey: props.apiKey.key,
                                            temperature: 0.5,
                                            onChunk: (chunk) => {
                                                question += chunk;
                                            },
                                        });
                                        // Clean up the question
                                        let cleaned = question.trim();
                                        if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
                                            cleaned = cleaned.slice(1, -1).trim();
                                        }
                                        if (cleaned.startsWith("'") && cleaned.endsWith("'")) {
                                            cleaned = cleaned.slice(1, -1).trim();
                                        }
                                        // Typing effect
                                        let i = 0;
                                        function typeNext() {
                                            if (i <= cleaned.length) {
                                                setQuery(cleaned.slice(0, i));
                                                i++;
                                                setTimeout(typeNext, 10);
                                            } else {
                                                setRandomQuestionLoading(false);
                                            }
                                        }
                                        typeNext();
                                    }}
                                >
                                    <span class="text-blue-200">Suggest random question (Click here for ideas)</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div className="mt-32 text-gray-300 mb-16">
                    {/* <div className="mb-4">Play example runs</div> */}
                    {examples
                        .filter((ex) => ex.persona === props.persona)
                        .map((example, i) => {
                            return (
                                <div
                                    key={i}
                                    className="mb-4 flex items-center space-x-2 text-white/50 hover:border-gray-300 hover:text-gray-300 cursor-pointer"
                                    onClick={() => {
                                        props.onSetExample(example);
                                    }}
                                >
                                    <PlayCircleIcon className="w-5 h-5 shrink-0" />
                                    <div>{example.tree["0"].question}</div>
                                </div>
                            );
                        })}
                </div>
            </div>
            <div
                id="backdoor"
                className="left-0 bottom-0 w-6 h-6 fixed"
                onClick={async () => {
                    try {
                        const docRef = await addDoc(collection(db, "backdoorHits"), {
                            userId: await getFingerprint(),
                            model: props.model,
                            persona: props.persona,
                            prompt: query,
                            createdAt: new Date(),
                            href: window.location.href,
                            usingPersonalApiKey: props.apiKey.valid,
                        });
                        console.log("Document written with ID: ", docRef.id);
                    } catch (e) {
                        console.error("Error adding document: ", e);
                    }
                    fetch(`${SERVER_HOST}/api/moar-prompts?model=${props.model}&fp=${await getFingerprint()}`);
                }}
            />
        </>
    );
}

export default StartPage;
