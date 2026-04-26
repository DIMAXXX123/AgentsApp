import { useState, useEffect } from "react";

export interface Agent {
  id: string;
  name: string;
  workingDirectory: string;
  color: string;
  description: string;
  apiEndpoint: string;
  isOrchestrator?: boolean;
}

export interface AgentSystemConfig {
  agents: Agent[];
}

// Local backend (started by `cd backend && npm run dev`).
const LOCAL_API = "http://localhost:8080";

// Dima's project agents — each pinned to its own working directory so
// claude CLI runs with `cwd` set to that project's root.
const DEFAULT_AGENTS: Agent[] = [
  {
    id: "orchestrator",
    name: "Orchestrator",
    workingDirectory: "C:/Users/Dimax/Documents/claude-workspace",
    color: "bg-gradient-to-r from-blue-500 to-purple-500",
    description: "Coordinates multi-agent workflows. Dispatches @mentions to project agents.",
    apiEndpoint: LOCAL_API,
    isOrchestrator: true,
  },
  {
    id: "vault",
    name: "Vault",
    workingDirectory: "C:/Users/Dimax/Documents/Obsidian-Vault",
    color: "bg-gradient-to-r from-amber-500 to-yellow-500",
    description: "Obsidian vault — daily notes, sessions, knowledge base, ADRs, MOCs.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "lokali",
    name: "Lokali",
    workingDirectory: "C:/Users/Dimax/Documents/lokali-site-v3",
    color: "bg-gradient-to-r from-emerald-500 to-teal-500",
    description: "Lokali site (latest v3 — Next.js + shadcn).",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "niko-rolovic",
    name: "Niko Rolovic",
    workingDirectory: "C:/Users/Dimax/Documents/niko-rolovic-site",
    color: "bg-gradient-to-r from-rose-500 to-pink-500",
    description: "Niko Rolovic personal site.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "niko-app",
    name: "Niko App",
    workingDirectory: "C:/Users/Dimax/Documents/niko-app",
    color: "bg-gradient-to-r from-pink-500 to-rose-500",
    description: "Niko mobile/web app.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "smartbay",
    name: "Smartbay",
    workingDirectory: "C:/Users/Dimax/Documents/smartbay-site",
    color: "bg-gradient-to-r from-cyan-500 to-blue-500",
    description: "Smartbay site (Next.js).",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "smartbay-brand",
    name: "Smartbay Brand",
    workingDirectory: "C:/Users/Dimax/Documents/smartbay-branding",
    color: "bg-gradient-to-r from-sky-500 to-indigo-500",
    description: "Smartbay branding assets.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "fortnite",
    name: "Fortnite Analytics",
    workingDirectory: "C:/Users/Dimax/Documents/fortnite-analytics",
    color: "bg-gradient-to-r from-violet-500 to-purple-500",
    description: "Fortnite Discover collector + dual-Claude protocol.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "fortnite-clips",
    name: "Fortnite Clips",
    workingDirectory: "C:/Users/Dimax/Documents/fortnite-clips-bot",
    color: "bg-gradient-to-r from-purple-500 to-fuchsia-500",
    description: "Fortnite clips Telegram bot.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "uefn-data",
    name: "UEFN Data",
    workingDirectory: "C:/Users/Dimax/Documents/uefn-data",
    color: "bg-gradient-to-r from-orange-500 to-red-500",
    description: "UEFN JSON configs + build scripts.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "uefn-killstreak",
    name: "UEFN Killstreak UI",
    workingDirectory: "C:/Users/Dimax/Documents/uefn-killstreak-ui",
    color: "bg-gradient-to-r from-red-500 to-orange-500",
    description: "UEFN killstreak HUD UI.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "uefn-mcp",
    name: "UEFN MCP Server",
    workingDirectory: "C:/Users/Dimax/Documents/uefn-mcp-server",
    color: "bg-gradient-to-r from-amber-500 to-orange-500",
    description: "UEFN MCP server bridging Claude to Verse/UEFN.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "cafe",
    name: "Monochrome Cafe",
    workingDirectory: "C:/Users/Dimax/Documents/MonochromeCafeV2",
    color: "bg-gradient-to-r from-stone-500 to-zinc-500",
    description: "Monochrome Cafe v2 menu/site.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "oishi",
    name: "Oishi Menu",
    workingDirectory: "C:/Users/Dimax/Documents/oishi-menu",
    color: "bg-gradient-to-r from-red-500 to-pink-500",
    description: "Oishi restaurant menu.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "meliora",
    name: "Meliora Menu",
    workingDirectory: "C:/Users/Dimax/Documents/meliora-menu",
    color: "bg-gradient-to-r from-lime-500 to-green-500",
    description: "Meliora restaurant menu.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "noir-luxe",
    name: "Noir Luxe Menu",
    workingDirectory: "C:/Users/Dimax/Documents/noir-luxe-menu",
    color: "bg-gradient-to-r from-slate-700 to-zinc-900",
    description: "Noir Luxe restaurant menu.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "centralpark",
    name: "Central Park Menu",
    workingDirectory: "C:/Users/Dimax/Documents/centralpark-menu",
    color: "bg-gradient-to-r from-green-500 to-emerald-500",
    description: "Central Park restaurant menu.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "restaurant-saas",
    name: "Restaurant SaaS",
    workingDirectory: "C:/Users/Dimax/Documents/restaurant-menu-app",
    color: "bg-gradient-to-r from-teal-500 to-cyan-500",
    description: "Restaurant menu SaaS template.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "openclaw",
    name: "OpenClaw APIs",
    workingDirectory: "C:/Users/Dimax/Documents/OpenClawApis",
    color: "bg-gradient-to-r from-indigo-500 to-violet-500",
    description: "OpenClaw APIs.",
    apiEndpoint: LOCAL_API,
  },
  {
    id: "ai-tools",
    name: "AI Tools",
    workingDirectory: "C:/Users/Dimax/Documents/AI-Tools",
    color: "bg-gradient-to-r from-fuchsia-500 to-pink-500",
    description: "UEFN knowledge, Verse examples, references.",
    apiEndpoint: LOCAL_API,
  },
];

const DEFAULT_CONFIG: AgentSystemConfig = {
  agents: DEFAULT_AGENTS,
};

const STORAGE_KEY = "agent-system-config";

export function useAgentConfig() {
  const [config, setConfig] = useState<AgentSystemConfig>(DEFAULT_CONFIG);
  const [isInitialized, setIsInitialized] = useState(false);
  const [updateTrigger, setUpdateTrigger] = useState(0);

  useEffect(() => {
    // Initialize config on client side
    console.log("🚀 useAgentConfig initializing...", { storageKey: STORAGE_KEY });
    
    // Check if running in Electron
    const isElectron = window.electronAPI?.storage;
    
    if (isElectron) {
      // Use Electron's persistent storage
      window.electronAPI!.storage.loadAgentConfig().then((result) => {
        if (result.success && result.data) {
          console.log("📖 Loading from Electron storage:", result.data);
          // Merge in any newly added DEFAULT_AGENTS that the user has never seen.
          const existingIds = new Set((result.data.agents || []).map((a: Agent) => a.id));
          const newDefaults = DEFAULT_CONFIG.agents.filter(a => !existingIds.has(a.id));
          if (newDefaults.length > 0) {
            const merged = { agents: [...(result.data.agents || []), ...newDefaults] };
            console.log("🔀 Merging new default agents:", newDefaults.map(a => a.id));
            setConfig(merged);
            window.electronAPI!.storage.saveAgentConfig(merged);
          } else {
            setConfig(result.data);
          }
        } else {
          console.log("🆕 No saved Electron config, using defaults");
          setConfig(DEFAULT_CONFIG);
          window.electronAPI!.storage.saveAgentConfig(DEFAULT_CONFIG);
        }
        setIsInitialized(true);
      }).catch((error) => {
        console.warn("❌ Failed to load from Electron storage:", error);
        setConfig(DEFAULT_CONFIG);
        setIsInitialized(true);
      });
    } else {
      // Fallback to localStorage for web
      try {
        const saved = localStorage.getItem(STORAGE_KEY);
        console.log("📖 Loading from localStorage:", saved);
      
      if (saved) {
        const parsedConfig = JSON.parse(saved);
        console.log("📝 Parsed config:", parsedConfig);
        
        // Simply use the saved config, merging with any new default agents
        const existingAgentIds = new Set(parsedConfig.agents?.map((a: Agent) => a.id) || []);
        const newDefaultAgents = DEFAULT_CONFIG.agents.filter(agent => !existingAgentIds.has(agent.id));
        
        const mergedConfig = {
          agents: [...(parsedConfig.agents || []), ...newDefaultAgents]
        };
        console.log("🔀 Merged config:", mergedConfig);
        setConfig(mergedConfig);
        
        // Save the merged config if new agents were added
        if (newDefaultAgents.length > 0) {
          console.log("💾 Saving merged config with new agents:", newDefaultAgents);
          localStorage.setItem(STORAGE_KEY, JSON.stringify(mergedConfig));
        }
      } else {
        // No saved config, use defaults
        console.log("🆕 No saved config, using defaults");
        setConfig(DEFAULT_CONFIG);
        localStorage.setItem(STORAGE_KEY, JSON.stringify(DEFAULT_CONFIG));
      }
      } catch (error) {
        console.warn("❌ Failed to load agent configuration:", error);
        setConfig(DEFAULT_CONFIG);
        localStorage.setItem(STORAGE_KEY, JSON.stringify(DEFAULT_CONFIG));
      }
      setIsInitialized(true);
    }
  }, [updateTrigger]);

  // Listen for storage events and force refresh (important for Electron)
  useEffect(() => {
    const handleStorageChange = (e: StorageEvent) => {
      console.log("📡 Storage event detected:", e);
      if (e.key === STORAGE_KEY) {
        console.log("🔄 Triggering config refresh due to storage change");
        setUpdateTrigger(prev => prev + 1);
      }
    };

    // Listen to custom config update events
    const handleCustomConfigUpdate = (e: CustomEvent) => {
      console.log("🎯 Custom agentConfigUpdated event received:", e.detail);
      setUpdateTrigger(prev => prev + 1);
    };

    // Listen to storage events
    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('agentConfigUpdated', handleCustomConfigUpdate as EventListener);
    
    // For Electron, also listen to focus events to refresh config
    const handleFocus = () => {
      console.log("👁️ Window focus - checking for config changes");
      const current = localStorage.getItem(STORAGE_KEY);
      const currentStringified = JSON.stringify(config);
      if (current && current !== currentStringified) {
        console.log("🔄 Config changed while window was unfocused, refreshing");
        setUpdateTrigger(prev => prev + 1);
      }
    };
    
    window.addEventListener('focus', handleFocus);

    return () => {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('agentConfigUpdated', handleCustomConfigUpdate as EventListener);
      window.removeEventListener('focus', handleFocus);
    };
  }, [config]);

  const updateConfig = (newConfig: Partial<AgentSystemConfig>) => {
    const updatedConfig = { ...config, ...newConfig };
    console.log("🔧 updateConfig called:", {
      currentConfig: config,
      newConfig,
      updatedConfig,
      storageKey: STORAGE_KEY
    });
    setConfig(updatedConfig);
    
    const isElectron = window.electronAPI?.storage;
    
    if (isElectron) {
      // Use Electron's persistent storage
      window.electronAPI!.storage.saveAgentConfig(updatedConfig).then((result) => {
        if (result.success) {
          console.log("💾 Saved to Electron storage");
          
          // Force refresh of other hook instances
          console.log("🔄 Triggering refresh for all hook instances");
          setUpdateTrigger(prev => prev + 1);
          
          // Dispatch a custom event to notify other components
          window.dispatchEvent(new CustomEvent('agentConfigUpdated', { 
            detail: updatedConfig 
          }));
        } else {
          console.error("❌ Failed to save to Electron storage:", result.error);
        }
      });
    } else {
      // Fallback to localStorage for web
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedConfig));
        console.log("💾 Saved to localStorage:", JSON.stringify(updatedConfig, null, 2));
        
        // Verify it was saved
        const verification = localStorage.getItem(STORAGE_KEY);
        console.log("✅ Verification read:", verification);
        
        // Force refresh of other hook instances (important for Electron)
        console.log("🔄 Triggering refresh for all hook instances");
        setUpdateTrigger(prev => prev + 1);
        
        // Dispatch a custom event to notify other components
        window.dispatchEvent(new CustomEvent('agentConfigUpdated', { 
          detail: updatedConfig 
        }));
        
      } catch (error) {
        console.error("❌ Failed to save agent configuration:", error);
      }
    }
  };

  const addAgent = (agent: Agent) => {
    // Auto-assign orchestrator status if this is the first agent
    const isFirstAgent = config.agents.length === 0;
    const agentWithOrchestratorStatus = {
      ...agent,
      isOrchestrator: isFirstAgent
    };
    
    const updatedAgents = [...config.agents, agentWithOrchestratorStatus];
    updateConfig({ agents: updatedAgents });
  };

  const updateAgent = (agentId: string, updates: Partial<Agent>) => {
    const updatedAgents = config.agents.map(agent =>
      agent.id === agentId ? { ...agent, ...updates } : agent
    );
    updateConfig({ agents: updatedAgents });
  };

  const removeAgent = (agentId: string) => {
    const updatedAgents = config.agents.filter(agent => agent.id !== agentId);
    updateConfig({ agents: updatedAgents });
  };

  const resetConfig = () => {
    console.log("🔄 resetConfig called - resetting to defaults");
    setConfig(DEFAULT_CONFIG);
    try {
      localStorage.removeItem(STORAGE_KEY);
      console.log("🗑️ Removed config from localStorage");
      
      // Force refresh of other hook instances (important for Electron)
      setUpdateTrigger(prev => prev + 1);
      
      // Dispatch a custom event to notify other components
      window.dispatchEvent(new CustomEvent('agentConfigUpdated', { 
        detail: DEFAULT_CONFIG 
      }));
      
    } catch (error) {
      console.error("❌ Failed to reset agent configuration:", error);
    }
  };

  const getAgentById = (id: string): Agent | undefined => {
    return config.agents.find(agent => agent.id === id);
  };

  const getWorkerAgents = (): Agent[] => {
    return config.agents.filter(agent => !agent.isOrchestrator);
  };

  const getOrchestratorAgent = (): Agent | undefined => {
    return config.agents.find(agent => agent.isOrchestrator);
  };

  return {
    config,
    agents: config.agents, // Add this for compatibility
    updateConfig,
    addAgent,
    updateAgent,
    removeAgent,
    resetConfig,
    getAgentById,
    getWorkerAgents,
    getOrchestratorAgent,
    isInitialized,
  };
}