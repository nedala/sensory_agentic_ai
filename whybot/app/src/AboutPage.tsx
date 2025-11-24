import { ArrowLeftIcon } from "@heroicons/react/24/solid";
import { Link } from "react-router-dom";

const PROFILES = [
  <div className="flex gap-4">
    <img className="w-20 h-20 object-cover rounded" src="john.png"></img>
    <div className="flex flex-col justify-between">
      <div>
        <div>John Qian</div>
        <div className="text-sm opacity-70">
          <a
            className="underline hover:text-white/90"
            target="_blank"
            rel="noreferrer"
            href="https://www.adept.ai/"
          >
            Adept
          </a>
        </div>
      </div>
      <div className="flex gap-2 items-center">
        <a
          target="_blank"
          rel="noreferrer"
          href="https://twitter.com/johnlqian"
        >
          <img src="twitter.svg" className="h-4 hover:brightness-110" />
        </a>
        <a target="_blank" rel="noreferrer" href="https://github.com/Xyzrr">
          <img
            src="github.svg"
            className="h-5 rounded-full invert hover:opacity-90"
          />
        </a>
        <a
          target="_blank"
          rel="noreferrer"
          href="https://www.linkedin.com/in/qianjohn?original_referer=https%3A%2F%2Fwww.google.com%2F"
        >
          <img
            src="linkedin.svg"
            className="h-7 rounded-full opacity-90 hover:opacity-80"
          />
        </a>
      </div>
    </div>
  </div>,
  <div className="flex gap-4">
    <img className="w-20 h-20 object-cover rounded" src="vish.jpg"></img>
    <div className="flex flex-col justify-between">
      <div>
        <div>Vish Rajiv</div>
        <div className="text-sm opacity-70">
          <a
            className="underline hover:text-white/90"
            target="_blank"
            rel="noreferrer"
            href="https://wandb.ai/site"
          >
            Weights & Biases
          </a>
        </div>
      </div>
      <div className="flex gap-2 items-center">
        <a target="_blank" rel="noreferrer" href="https://twitter.com/vwrj3">
          <img src="twitter.svg" className="h-4 hover:brightness-110" />
        </a>
        <a target="_blank" rel="noreferrer" href="https://github.com/vwrj">
          <img
            src="github.svg"
            className="h-5 rounded-full invert hover:opacity-90"
          />
        </a>
        <a
          target="_blank"
          rel="noreferrer"
          href="https://www.linkedin.com/in/vishwaesh-rajiv?original_referer=https%3A%2F%2Fwww.google.com%2F"
        >
          <img
            src="linkedin.svg"
            className="h-7 rounded-full opacity-90 hover:opacity-80"
          />
        </a>
      </div>
    </div>
  </div>,
];

if (Math.random() < 0.5) {
  PROFILES.reverse();
}

function AboutPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-zinc-900 via-zinc-800 to-zinc-900 text-gray-100 p-4 flex flex-col items-center justify-center">
      <Link
        to="/"
        className="inline-block bg-black/10 rounded p-2 cursor-pointer hover:bg-black/20 backdrop-blur mb-4"
      >
        <ArrowLeftIcon className="w-5 h-5 text-gray-600" />
      </Link>
      <div className="w-full max-w-xl bg-white/10 rounded-2xl shadow-xl p-8 flex flex-col items-center space-y-6">
        <h1 className="text-4xl font-extrabold text-blue-300 mb-2 tracking-tight">Pearl Growing Deep Research</h1>
        <div className="text-lg text-gray-200 mb-4 text-center">
          An interactive tool for deep, structured exploration of questions using large language models. Generate, organize, and export your research mindmaps.
        </div>
        <div className="flex flex-col md:flex-row gap-6 w-full justify-center items-center">
          <div className="flex flex-col items-center">
            <img className="w-20 h-20 object-cover rounded-full border-4 border-blue-200 shadow" src="john.png" alt="John Qian" />
            <div className="mt-2 font-semibold text-blue-200">John Qian</div>
            <div className="text-xs text-gray-200">Co-creator</div>
          </div>
          <div className="flex flex-col items-center">
            <img className="w-20 h-20 object-cover rounded-full border-4 border-blue-200 shadow" src="vish.jpg" alt="Vish Rajiv" />
            <div className="mt-2 font-semibold text-blue-200">Vish Rajiv</div>
            <div className="text-xs text-gray-200">Co-creator</div>
          </div>
          <div className="flex flex-col items-center">
            <img className="w-20 h-20 object-cover rounded-full border-4 border-blue-200 shadow" src="seshu_ai.png" alt="Seshu Edala" />
            <div className="mt-2 font-semibold text-blue-200">Seshu Edala</div>
            <div className="text-xs text-gray-200">Local LLM adaptation</div>
          </div>
        </div>
        <div className="w-full border-t border-dotted border-gray-300 my-6"></div>
        <div className="text-base text-gray-200 text-center">
          <span className="font-semibold text-blue-300">Whybot</span> was created by John Qian and Vish Rajiv.<br/>
          <span className="text-gray-400">All original credits and images retained.</span>
          <br/>
          <span className="block mt-2">This version has been adapted for local LLMs by <span className="font-semibold text-blue-300">Seshu Edala</span> 
            <a href="https://seshu.gnyan.ai:8443/" className="underline text-blue-300 hover:text-blue-400 ml-1" target="_blank" rel="noopener noreferrer">(https://seshu.gnyan.ai:8443/)</a>.
          </span>
        </div>
      </div>
    </div>
  );
}

export default AboutPage;
