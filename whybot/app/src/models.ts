export interface Model {
    name: string;
    key: string;
    description: string;
}

export const MODELS: { [key: string]: Model } = {
    "ollama/qwen2.5vl:7b": {
        name: "Ollama Qwen",
        key: "ollama/qwen2.5vl:7b",
        description: "Local Qwen model via Ollama (fast, private)",
    },
    "openai/gpt-3.5-turbo": {
        name: "GPT-3.5 Turbo",
        key: "gpt-3.5-turbo",
        description: "Fast and semi-smart",
    },
    "openai/gpt4": {
        name: "GPT-4",
        key: "gpt-4",
        description: "Slow but very smart",
    },
};
