# Auto-Research (Agentic Deep Research) Frameworks — Landscape Survey

*Compiled August 2026*

Automated research agents split into four distinct layers. Pick based on what you actually want to do: use a ready-made research tool, build your own research agent, run an open-weights model trained to research, or automate scientific discovery end-to-end.

---

## 1. Ready-to-use open-source deep research frameworks

These take a question, plan searches, browse/crawl the web (and often local files), and write a cited report.

### DeerFlow (ByteDance) — the trending one
- Repo: https://github.com/bytedance/deer-flow (MIT)
- Started May 2025 as a LangGraph-based deep research framework; **DeerFlow 2.0** (relaunched late Feb 2026) evolved into a long-horizon "SuperAgent" harness that researches, codes, and creates — sandboxes, memory, tools, skills, subagents, message gateway.
- Fastest-growing project in the space: ~47k GitHub stars within three months of the 2.0 relaunch, 66–68k+ by mid-2026.
- Good default if you want a self-hosted "Manus-style" general agent whose core strength is research.

### GPT Researcher — the most battle-tested
- Repo: https://github.com/assafelovic/gpt-researcher (~28k stars)
- The original open deep-research agent (mid-2023, pre-dates OpenAI's Deep Research by 18 months). Plan-and-execute architecture: planner generates questions, parallel execution agents gather sources, publisher writes a long cited report.
- Works with any LLM provider, many retrievers (Tavily, Google, etc.), local documents, MCP; has a multi-agent LangGraph pipeline and a "Deep Research" recursive mode.
- Best choice for a production-ready, pluggable report generator you can embed via `pip install gpt-researcher`.

### LangChain open_deep_research + deepagents
- Repos: https://github.com/langchain-ai/open_deep_research and https://github.com/langchain-ai/deepagents
- `open_deep_research`: clean supervisor→parallel-researchers→writer architecture on LangGraph; bring your own models, search tools, MCP servers. Ranked top-10 on DeepResearch Bench; MIT.
- `deepagents`: the newer "batteries-included agent harness" (planning todos, virtual filesystem, subagents, skills) — LangChain's recommended way to build Claude-Code-style long-running research/coding agents.
- Best choice as a **starting codebase to customize** rather than a finished product.

### STORM / Co-STORM (Stanford OVAL)
- Repo: https://github.com/stanford-oval/storm (~26k+ stars, NAACL 2024 paper)
- Writes Wikipedia-style articles: discovers perspectives, simulates expert interviews to generate good questions, builds an outline, then writes section-by-section with citations. Co-STORM adds human-in-the-loop collaborative curation.
- Best for structured encyclopedic reports rather than free-form research memos.

### Also worth knowing
- **SkyworkAI DeepResearchAgent** — hierarchical planner coordinating specialized sub-agents (https://github.com/SkyworkAI/DeepResearchAgent)
- **Hugging Face smolagents `open_deep_research`** — the famous reproduction of OpenAI Deep Research that hit ~55% on GAIA with a code-acting agent
- **Camel-AI OWL** — multi-agent workforce framework, ~69% GAIA average, long a top open-source scorer (https://github.com/camel-ai/owl)
- **OpenManus** (FoundationAgents) — community open Manus clone
- **dzhng/deep-research** and **Jina node-DeepResearch** — minimal TypeScript search/read/reason loops, great for learning the pattern
- **u14app/deep-research**, **nickscamara/open-deep-research** (Firecrawl-based), **local-deep-research** (fully local/private), **Zilliz deep-searcher** (RAG-over-your-data flavor), **PraisonAI** (multi-agent framework with built-in deep research)
- Curated trackers: https://github.com/DavidZWZ/Awesome-Deep-Research and https://github.com/ai-agents-2030/awesome-deep-research-agent

---

## 2. Open-weights models trained to *be* research agents

The 2025→2026 shift: instead of prompt-orchestrating a generic LLM, train the model end-to-end (agentic pre-training → SFT → RL) to do long-horizon search/browse/synthesize.

- **Tongyi DeepResearch (Alibaba)** — https://github.com/Alibaba-NLP/DeepResearch — 30.5B MoE (3.3B active), Apache 2.0. SOTA-level on Humanity's Last Exam, BrowseComp, WebWalkerQA, xbench-DeepSearch; called the "DeepSeek moment for AI agents." Ships the full inference stack + data-synthesis pipeline. Run it inside their ReAct/IterResearch harness.
- **WebSailor-V2 / OpenSeeker / Search-R1 / R1-Searcher** — the RL-for-search research lineage behind these agents.
- Relevance: if you want deep research **self-hosted on open weights** rather than piped to GPT/Claude/Gemini APIs, this is the leading option.

---

## 3. "AI Scientist" frameworks — automating the full research lifecycle

These go beyond web reports: hypothesis generation → experiments/code → analysis → paper writing → (simulated) peer review.

- **The AI Scientist v2 (Sakana AI)** — https://github.com/SakanaAI/AI-Scientist-v2 — agentic tree search over experiments, VLM feedback loop; produced the first fully AI-generated paper to pass workshop-level peer review (ICLR 2025 workshop).
- **AI-Researcher (HKU Data Science)** — https://github.com/HKUDS/AI-Researcher — NeurIPS 2025; end-to-end from concept to publication, with a benchmark suite for evaluating AI researchers; hosted version at novix.science.
- **Agent Laboratory + AgentRxiv (Schmidgall et al.)** — https://github.com/SamuelSchmidgall/AgentLaboratory — LLM-agent teams take a human idea through literature review, experiments, and report; AgentRxiv lets agent labs share and build on each other's preprints.
- **Kosmos (Edison Scientific / FutureHouse spin-off)** — commercial, not open source, but the current headline "AI scientist": 12-hour autonomous runs, ~1,500 papers read + ~42k lines of analysis code per run, structured world model shared between literature and data-analysis agents; claims ~6 months of work per day of compute (~80% conclusion reproducibility). FutureHouse's open stack (PaperQA2, Aviary, Robin) is on GitHub.
- **Google AI Co-Scientist** — Gemini-based multi-agent hypothesis generator (generate→debate→evolve tournament loop), validated in biomedical case studies (drug repurposing, AMR).

---

## 4. General agent frameworks people build research agents on

Not research-specific, but most custom research agents are built on one of these: **LangGraph** (stateful graphs, most production research agents), **CrewAI** (fast role-based multi-agent), **Microsoft Agent Framework / AutoGen+AG2**, **OpenAI Agents SDK**, **Google ADK**, **smolagents** (code-acting), **Mastra** (TypeScript), **Haystack** (pipeline RAG), **Claude Agent SDK** (the harness behind Claude Code — strong for long-running tool-using agents).

Hosted products for reference/benchmarking: OpenAI Deep Research, Gemini Deep Research, Perplexity Deep Research (fast/free-tier), Anthropic Claude Research, Kimi-Researcher, Manus, Microsoft Copilot Researcher; Elicit/Consensus/SciSpace for literature-specific work.

---

## Quick recommendations

| You want | Use |
|---|---|
| Self-hosted deep-research tool that works today | **GPT Researcher** (mature, embeddable) or **DeerFlow** (trending, broader agent harness) |
| A codebase to fork and customize | **LangChain open_deep_research / deepagents** |
| Open weights doing the research (no closed API) | **Tongyi DeepResearch** |
| Wikipedia-style structured articles | **STORM / Co-STORM** |
| Automated ML/science experiments + papers | **AI-Scientist-v2**, **HKUDS AI-Researcher**, **Agent Laboratory** |
| Max benchmark performance on agentic search (GAIA) | **Camel-AI OWL**, smolagents open_deep_research |

**Trend summary (mid-2026):** the field is consolidating around (1) long-horizon "SuperAgent" harnesses (DeerFlow 2.0, deepagents) with sandboxes/memory/subagents, (2) RL-trained open research models (Tongyi lineage) closing the gap with OpenAI/Google products, and (3) serious AI-scientist systems (Kosmos, AI-Scientist-v2) producing peer-review-grade output. Prompt-chained single-shot "search and summarize" pipelines are now considered the baseline.
