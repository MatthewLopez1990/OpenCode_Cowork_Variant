import React from 'react';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { useConfigStore } from '@/stores/useConfigStore';
import { useUIStore } from '@/stores/useUIStore';
import { useDeviceInfo } from '@/lib/device';
import { RiArrowDownSLine, RiArrowRightSLine, RiCheckLine, RiCloseLine, RiPencilAiLine, RiSearchLine, RiSparkling2Fill, RiStarFill, RiStarLine, RiTimeLine } from '@remixicon/react';
import { cn } from '@/lib/utils';
import { MobileOverlayPanel } from '@/components/ui/MobileOverlayPanel';
import { ProviderLogo } from '@/components/ui/ProviderLogo';
import { ScrollableOverlay } from '@/components/ui/ScrollableOverlay';
import { useModelLists } from '@/hooks/useModelLists';
import type { LatestFamilyModel, ModelMetadata } from '@/types';

type ProviderModel = Record<string, unknown> & { id?: string; name?: string };
type LatestFamilyKey = 'anthropic' | 'openai' | 'google';
const LATEST_FAMILY_ORDER: readonly LatestFamilyKey[] = ['anthropic', 'openai', 'google'] as const;
const LATEST_FAMILY_LABELS: Record<LatestFamilyKey, string> = {
    anthropic: 'Anthropic',
    openai: 'OpenAI',
    google: 'Google',
};

const formatReleasedAgo = (releaseDate: string | null | undefined): string => {
    if (!releaseDate) return '';
    const ts = Date.parse(releaseDate);
    if (!Number.isFinite(ts)) return '';
    const diffMs = Date.now() - ts;
    if (diffMs < 0) return '';
    const days = Math.floor(diffMs / (24 * 60 * 60 * 1000));
    if (days === 0) return 'released today';
    if (days === 1) return 'released yesterday';
    if (days < 30) return `released ${days}d ago`;
    const months = Math.floor(days / 30);
    if (months < 12) return months === 1 ? 'released 1mo ago' : `released ${months}mo ago`;
    const years = Math.floor(days / 365);
    return years === 1 ? 'released 1y ago' : `released ${years}y ago`;
};

interface ModelSelectorProps {
    providerId: string;
    modelId: string;
    onChange: (providerId: string, modelId: string) => void;
    className?: string;
    allowedProviderIds?: string[];
    placeholder?: string;
}

const COMPACT_NUMBER_FORMATTER = new Intl.NumberFormat('en-US', {
    notation: 'compact',
    compactDisplay: 'short',
    maximumFractionDigits: 1,
    minimumFractionDigits: 0,
});

const formatTokens = (value?: number | null) => {
    if (typeof value !== 'number' || Number.isNaN(value)) {
        return '';
    }
    if (value === 0) {
        return '0';
    }
    const formatted = COMPACT_NUMBER_FORMATTER.format(value);
    return formatted.endsWith('.0') ? formatted.slice(0, -2) : formatted;
};

export const ModelSelector: React.FC<ModelSelectorProps> = ({
    providerId,
    modelId,
    onChange,
    className,
    allowedProviderIds,
    placeholder
}) => {
    const { providers, modelsMetadata, latestByFamily } = useConfigStore();
    const isMobile = useUIStore(state => state.isMobile);
    const hiddenModels = useUIStore(state => state.hiddenModels);
    const { toggleFavoriteModel, isFavoriteModel, addRecentModel } = useUIStore();
    const { favoriteModelsList, recentModelsList } = useModelLists();
    const { isMobile: deviceIsMobile } = useDeviceInfo();
    const isActuallyMobile = isMobile || deviceIsMobile;

    const [isMobilePanelOpen, setIsMobilePanelOpen] = React.useState(false);
    const [expandedMobileProviders, setExpandedMobileProviders] = React.useState<Set<string>>(new Set());
    const [isDropdownOpen, setIsDropdownOpen] = React.useState(false);
    const [searchQuery, setSearchQuery] = React.useState('');
    const [selectedIndex, setSelectedIndex] = React.useState(0);
    const itemRefs = React.useRef<(HTMLDivElement | null)[]>([]);

    const allowedProviderSet = React.useMemo(() => {
        if (!Array.isArray(allowedProviderIds) || allowedProviderIds.length === 0) {
            return null;
        }
        return new Set(allowedProviderIds);
    }, [allowedProviderIds]);

    const visibleProviders = React.useMemo(() => {
        const baseProviders = allowedProviderSet
            ? providers.filter((provider) => allowedProviderSet.has(String(provider.id)))
            : providers;

        return baseProviders
            .map((provider) => {
                const providerModels = Array.isArray(provider.models) ? provider.models : [];
                const filteredModels = providerModels.filter((model: ProviderModel) => {
                    const modelId = typeof model?.id === 'string' ? model.id : '';
                    return !hiddenModels.some(
                        (hidden) => hidden.providerID === String(provider.id) && hidden.modelID === modelId
                    );
                });
                return { ...provider, models: filteredModels };
            })
            .filter((provider) => provider.models.length > 0);
    }, [providers, allowedProviderSet, hiddenModels]);

    const closeMobilePanel = () => setIsMobilePanelOpen(false);
    const toggleMobileProviderExpansion = (provId: string) => {
        setExpandedMobileProviders(prev => {
            const newSet = new Set(prev);
            if (newSet.has(provId)) {
                newSet.delete(provId);
            } else {
                newSet.add(provId);
            }
            return newSet;
        });
    };

    // Reset search and selection when dropdown closes
    React.useEffect(() => {
        if (!isDropdownOpen) {
            setSearchQuery('');
            setSelectedIndex(0);
        }
    }, [isDropdownOpen]);

    // Reset selection when search query changes
    React.useEffect(() => {
        setSelectedIndex(0);
    }, [searchQuery]);

    const getModelDisplayName = (model: Record<string, unknown>) => {
        const name = model?.name || model?.id || '';
        const nameStr = String(name);
        if (nameStr.length > 40) {
            return nameStr.substring(0, 37) + '...';
        }
        return nameStr;
    };

    const getModelMetadata = (provId: string, modId: string): ModelMetadata | undefined => {
        const key = `${provId}/${modId}`;
        return modelsMetadata.get(key);
    };

    const handleProviderAndModelChange = (newProviderId: string, newModelId: string) => {
        onChange(newProviderId, newModelId);
        if (newProviderId && newModelId) {
            addRecentModel(newProviderId, newModelId);
        }
        setIsDropdownOpen(false);
    };

    // Filter helper
    const filterByQuery = (modelName: string, providerName: string) => {
        if (!searchQuery.trim()) return true;
        const lowerQuery = searchQuery.toLowerCase();
        return (
            modelName.toLowerCase().includes(lowerQuery) ||
            providerName.toLowerCase().includes(lowerQuery)
        );
    };

    // Render a model row for desktop dropdown
    const renderModelRow = (
        model: ProviderModel,
        provID: string,
        modID: string,
        keyPrefix: string,
        flatIndex: number,
        isHighlighted: boolean
    ) => {
        const metadata = getModelMetadata(provID, modID);
        const contextTokens = formatTokens(metadata?.limit?.context);
        const isSelected = providerId === provID && modelId === modID;
        const isFavorite = isFavoriteModel(provID, modID);

        const showProviderLogo = keyPrefix === 'fav' || keyPrefix === 'recent';

        return (
            <div
                key={`${keyPrefix}-${provID}-${modID}`}
                ref={(el) => { itemRefs.current[flatIndex] = el; }}
                className={cn(
                    "typography-meta group flex items-center gap-2 px-2 py-1.5 rounded-md cursor-pointer",
                    isHighlighted ? "bg-interactive-selection" : "hover:bg-interactive-hover/50"
                )}
                onClick={() => handleProviderAndModelChange(provID, modID)}
                onMouseEnter={() => setSelectedIndex(flatIndex)}
            >
                <div className="flex items-center gap-1.5 flex-1 min-w-0">
                    {showProviderLogo && (
                        <ProviderLogo providerId={provID} className="h-3.5 w-3.5 flex-shrink-0" />
                    )}
                    <span className="font-medium truncate">
                        {getModelDisplayName(model)}
                    </span>
                    {contextTokens ? (
                        <span className="typography-micro text-muted-foreground flex-shrink-0">
                            {contextTokens}
                        </span>
                    ) : null}
                </div>
                <div className="flex items-center gap-1 flex-shrink-0">
                    {isSelected && (
                        <RiCheckLine className="h-4 w-4 text-primary" />
                    )}
                    <button
                        onClick={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            toggleFavoriteModel(provID, modID);
                        }}
                        className={cn(
                            "model-favorite-button flex h-4 w-4 items-center justify-center hover:text-primary/80",
                            isFavorite ? "text-primary" : "text-muted-foreground"
                        )}
                        aria-label={isFavorite ? "Unfavorite" : "Favorite"}
                        title={isFavorite ? "Remove from favorites" : "Add to favorites"}
                    >
                        {isFavorite ? (
                            <RiStarFill className="h-3.5 w-3.5" />
                        ) : (
                            <RiStarLine className="h-3.5 w-3.5" />
                        )}
                    </button>
                </div>
            </div>
        );
    };

    // Render a Latest quick-pick row for the desktop dropdown. Visually
    // distinct from regular rows: family logo + family label + "released Xd ago".
    const renderLatestRow = (
        family: LatestFamilyKey,
        entry: LatestFamilyModel,
        model: ProviderModel,
        flatIndex: number,
        isHighlighted: boolean
    ) => {
        const isSelected = providerId === entry.providerId && modelId === entry.modelId;
        const released = formatReleasedAgo(entry.releaseDate);
        const displayName = getModelDisplayName(model as Record<string, unknown>) || entry.displayName;
        return (
            <div
                key={`latest-${family}-${entry.providerId}-${entry.modelId}`}
                ref={(el) => { itemRefs.current[flatIndex] = el; }}
                className={cn(
                    'typography-meta group flex items-center gap-2 px-2 py-1.5 rounded-md cursor-pointer',
                    isHighlighted ? 'bg-interactive-selection' : 'hover:bg-interactive-hover/50'
                )}
                onClick={() => handleProviderAndModelChange(entry.providerId, entry.modelId)}
                onMouseEnter={() => setSelectedIndex(flatIndex)}
            >
                <ProviderLogo providerId={family} className="h-3.5 w-3.5 flex-shrink-0" />
                <div className="flex items-baseline gap-1.5 flex-1 min-w-0">
                    <span className="font-medium truncate">{displayName}</span>
                    <span className="typography-micro text-muted-foreground flex-shrink-0">
                        {LATEST_FAMILY_LABELS[family]}
                    </span>
                </div>
                {released ? (
                    <span className="typography-micro text-muted-foreground flex-shrink-0">
                        {released}
                    </span>
                ) : null}
                {isSelected && (
                    <RiCheckLine className="h-4 w-4 text-primary flex-shrink-0" />
                )}
            </div>
        );
    };

    // Build the "Latest" quick-pick list from the server-provided latestByFamily.
    // Each entry is the most recently released model in its family that is also
    // available in the current provider list (so users can actually select it).
    const latestItems = React.useMemo(() => {
        const items: Array<{ family: LatestFamilyKey; entry: LatestFamilyModel; model: ProviderModel }> = [];
        for (const family of LATEST_FAMILY_ORDER) {
            const entry = latestByFamily[family];
            if (!entry) continue;
            if (allowedProviderSet && !allowedProviderSet.has(entry.providerId)) continue;
            const provider = providers.find((p) => p.id === entry.providerId);
            if (!provider) continue;
            const providerModels = Array.isArray(provider.models) ? provider.models : [];
            const model = providerModels.find((m: ProviderModel) => m?.id === entry.modelId);
            if (!model) continue;
            if (hiddenModels.some((h) => h.providerID === entry.providerId && h.modelID === entry.modelId)) continue;
            items.push({ family, entry, model });
        }
        return items;
    }, [latestByFamily, allowedProviderSet, providers, hiddenModels]);

    const filteredLatest = latestItems.filter(({ family, entry, model }) => {
        const modelName = getModelDisplayName(model as Record<string, unknown>) || entry.displayName;
        return filterByQuery(modelName, LATEST_FAMILY_LABELS[family]);
    });

    // Filter data for desktop dropdown
    const filteredFavorites = favoriteModelsList.filter(({ model, providerID }) => {
        if (allowedProviderSet && !allowedProviderSet.has(providerID)) {
            return false;
        }
        const provider = providers.find(p => p.id === providerID);
        const providerName = provider?.name || providerID;
        const modelName = getModelDisplayName(model);
        return filterByQuery(modelName, providerName);
    });

    const filteredRecents = recentModelsList.filter(({ model, providerID }) => {
        if (allowedProviderSet && !allowedProviderSet.has(providerID)) {
            return false;
        }
        const provider = providers.find(p => p.id === providerID);
        const providerName = provider?.name || providerID;
        const modelName = getModelDisplayName(model);
        return filterByQuery(modelName, providerName);
    });

    const filteredProviders = visibleProviders
        .map((provider) => {
            const providerModels = Array.isArray(provider.models) ? provider.models : [];
            const filteredModels = providerModels.filter((model: ProviderModel) => {
                const modelName = getModelDisplayName(model);
                return filterByQuery(modelName, provider.name || provider.id || '');
            });
            return { ...provider, models: filteredModels };
        })
        .filter((provider) => provider.models.length > 0);

    const hasResults = filteredLatest.length > 0 || filteredFavorites.length > 0 || filteredRecents.length > 0 || filteredProviders.length > 0;

    const renderMobileModelPanel = () => {
        if (!isActuallyMobile) return null;

        return (
            <MobileOverlayPanel
                open={isMobilePanelOpen}
                onClose={closeMobilePanel}
                title="Select model"
            >
                <div className="space-y-1">
                    {/* Latest Section for Mobile */}
                    {latestItems.length > 0 && (
                        <div className="rounded-xl border border-border/40 bg-[var(--surface-elevated)] mb-2">
                            <div className="px-2 py-1.5 text-xs font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                                <RiSparkling2Fill className="h-3.5 w-3.5 text-primary" />
                                Latest
                            </div>
                            <div className="border-t border-border/20">
                                {latestItems.map(({ family, entry, model }) => {
                                    const isSelectedModel = entry.providerId === providerId && entry.modelId === modelId;
                                    const released = formatReleasedAgo(entry.releaseDate);
                                    const displayName = getModelDisplayName(model as Record<string, unknown>) || entry.displayName;
                                    return (
                                        <button
                                            key={`latest-mobile-${family}`}
                                            type="button"
                                            className={cn(
                                                'flex w-full items-center justify-between gap-2 px-2 py-1.5 text-left typography-meta',
                                                isSelectedModel ? 'bg-primary/10 text-primary' : 'text-foreground'
                                            )}
                                            onClick={() => {
                                                handleProviderAndModelChange(entry.providerId, entry.modelId);
                                                closeMobilePanel();
                                            }}
                                        >
                                            <div className="flex items-center gap-2 min-w-0 flex-1">
                                                <ProviderLogo providerId={family} className="h-3 w-3 flex-shrink-0" />
                                                <span className="font-medium truncate">{displayName}</span>
                                                <span className="typography-micro text-muted-foreground flex-shrink-0">
                                                    {LATEST_FAMILY_LABELS[family]}
                                                </span>
                                            </div>
                                            {released ? (
                                                <span className="typography-micro text-muted-foreground flex-shrink-0">{released}</span>
                                            ) : null}
                                        </button>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                    {/* Favorites Section for Mobile */}
                    {favoriteModelsList.length > 0 && (
                        <div className="rounded-xl border border-border/40 bg-[var(--surface-elevated)] mb-2">
                            <div className="px-2 py-1.5 text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                                Favorites
                            </div>
                            <div className="border-t border-border/20">
                                {favoriteModelsList.map(({ model, providerID, modelID }) => {
                                    const isSelectedModel = providerID === providerId && modelID === modelId;

                                    return (
                                        <div
                                            key={`fav-mobile-${providerID}-${modelID}`}
                                            className={cn(
                                                'flex w-full items-center justify-between px-2 py-1.5 text-left',
                                                'typography-meta',
                                                isSelectedModel ? 'bg-primary/10 text-primary' : 'text-foreground'
                                            )}
                                        >
                                            <button
                                                type="button"
                                                className="flex-1 flex flex-col min-w-0 mr-2"
                                                onClick={() => {
                                                    handleProviderAndModelChange(providerID, modelID);
                                                    closeMobilePanel();
                                                }}
                                            >
                                                <div className="flex items-center gap-2">
                                                    <ProviderLogo
                                                        providerId={providerID}
                                                        className="h-3 w-3 flex-shrink-0"
                                                    />
                                                    <span className="font-medium truncate">{getModelDisplayName(model)}</span>
                                                </div>
                                            </button>
                                            
                                            <button
                                                onClick={(e) => {
                                                    e.preventDefault();
                                                    e.stopPropagation();
                                                    toggleFavoriteModel(providerID, modelID);
                                                }}
                                                className="model-favorite-button flex h-8 w-8 items-center justify-center text-primary hover:text-primary/80 active:scale-95 touch-manipulation"
                                                aria-label="Unfavorite"
                                            >
                                                <RiStarFill className="h-4 w-4" />
                                            </button>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                    {/* Recents Section for Mobile */}
                    {recentModelsList.length > 0 && (
                        <div className="rounded-xl border border-border/40 bg-[var(--surface-elevated)] mb-2">
                            <div className="px-2 py-1.5 text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                                Recents
                            </div>
                            <div className="border-t border-border/20">
                                {recentModelsList.map(({ model, providerID, modelID }) => {
                                    const isSelectedModel = providerID === providerId && modelID === modelId;

                                    return (
                                        <div
                                            key={`recent-mobile-${providerID}-${modelID}`}
                                            className={cn(
                                                'flex w-full items-center justify-between px-2 py-1.5 text-left',
                                                'typography-meta',
                                                isSelectedModel ? 'bg-primary/10 text-primary' : 'text-foreground'
                                            )}
                                        >
                                            <button
                                                type="button"
                                                className="flex-1 flex flex-col min-w-0 mr-2"
                                                onClick={() => {
                                                    handleProviderAndModelChange(providerID, modelID);
                                                    closeMobilePanel();
                                                }}
                                            >
                                                <div className="flex items-center gap-2">
                                                    <ProviderLogo
                                                        providerId={providerID}
                                                        className="h-3 w-3 flex-shrink-0"
                                                    />
                                                    <span className="font-medium truncate">{getModelDisplayName(model)}</span>
                                                </div>
                                            </button>
                                            
                                            <button
                                                onClick={(e) => {
                                                    e.preventDefault();
                                                    e.stopPropagation();
                                                    toggleFavoriteModel(providerID, modelID);
                                                }}
                                                className="model-favorite-button flex h-8 w-8 items-center justify-center text-muted-foreground/50 hover:text-primary/80 active:scale-95 touch-manipulation"
                                                aria-label="Favorite"
                                            >
                                                <RiStarLine className="h-4 w-4" />
                                            </button>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                    {visibleProviders.map((provider) => {
                        const providerModels = Array.isArray(provider.models) ? provider.models : [];
                        if (providerModels.length === 0) return null;

                        const isActiveProvider = provider.id === providerId;
                        const isExpanded = expandedMobileProviders.has(provider.id);

                        return (
                            <div key={provider.id} className="rounded-xl border border-border/40 bg-[var(--surface-elevated)]">
                                <button
                                    type="button"
                                    className="flex w-full items-center justify-between gap-1.5 px-2 py-1.5 text-left"
                                    onClick={() => toggleMobileProviderExpansion(provider.id)}
                                >
                                    <div className="flex items-center gap-2">
                                        <ProviderLogo
                                            providerId={provider.id}
                                            className="h-3.5 w-3.5"
                                        />
                                        <span className="typography-meta font-medium text-foreground">
                                            {provider.name}
                                        </span>
                                        {isActiveProvider && (
                                            <span className="typography-micro text-primary/80">Current</span>
                                        )}
                                    </div>
                                    {isExpanded ? (
                                        <RiArrowDownSLine className="h-3 w-3 text-muted-foreground" />
                                    ) : (
                                        <RiArrowRightSLine className="h-3 w-3 text-muted-foreground" />
                                    )}
                                </button>

                                {isExpanded && (
                                    <div className="border-t border-border/20">
                                        {providerModels.map((modelItem: ProviderModel) => {
                                            const isSelectedModel = provider.id === providerId && modelItem.id === modelId;

                                            return (
                                                <div
                                                    key={modelItem.id as string}
                                                    className={cn(
                                                        'flex w-full items-center justify-between px-2 py-1.5 text-left',
                                                        'typography-meta',
                                                        isSelectedModel ? 'bg-primary/10 text-primary' : 'text-foreground'
                                                    )}
                                                >
                                                    <button
                                                        type="button"
                                                        className="flex-1 flex flex-col min-w-0 mr-2"
                                                        onClick={() => {
                                                            handleProviderAndModelChange(provider.id as string, modelItem.id as string);
                                                            closeMobilePanel();
                                                        }}
                                                    >
                                                        <span className="font-medium truncate">{getModelDisplayName(modelItem)}</span>
                                                    </button>
                                                    
                                                    <div className="flex items-center gap-2 flex-shrink-0">
                                                        <button
                                                            onClick={(e) => {
                                                                e.preventDefault();
                                                                e.stopPropagation();
                                                                toggleFavoriteModel(provider.id as string, modelItem.id as string);
                                                            }}
                                                            className={cn(
                                                                "flex h-8 w-8 items-center justify-center active:scale-95 touch-manipulation hover:text-primary/80",
                                                                isFavoriteModel(provider.id as string, modelItem.id as string)
                                                                    ? "text-primary"
                                                                    : "text-muted-foreground/50"
                                                            )}
                                                            aria-label={isFavoriteModel(provider.id as string, modelItem.id as string) ? "Unfavorite" : "Favorite"}
                                                        >
                                                            {isFavoriteModel(provider.id as string, modelItem.id as string) ? (
                                                                <RiStarFill className="h-4 w-4" />
                                                            ) : (
                                                                <RiStarLine className="h-4 w-4" />
                                                            )}
                                                        </button>
                                                        
                                                        {isSelectedModel && (
                                                            <div className="h-2 w-2 rounded-full bg-primary" />
                                                        )}
                                                    </div>
                                                </div>
                                            );
                                        })}
                                    </div>
                                )}
                            </div>
                        );
                    })}

                    <button
                        type="button"
                        className="flex w-full items-center justify-between rounded-lg border border-border/40 bg-[var(--surface-elevated)] px-2 py-1.5 text-left"
                        onClick={() => {
                            handleProviderAndModelChange('', '');
                            closeMobilePanel();
                        }}
                    >
                        <span className="typography-meta text-muted-foreground">{placeholder || 'No model (optional)'}</span>
                    </button>
                </div>
            </MobileOverlayPanel>
        );
    };

    return (
        <>
            {isActuallyMobile ? (
                <button
                    type="button"
                    onClick={() => setIsMobilePanelOpen(true)}
                    className={cn(
                        'flex w-full items-center justify-between gap-2 rounded-lg border border-border/40 bg-[var(--surface-elevated)] px-2 py-1.5 text-left',
                        className
                    )}
                >
                    <div className="flex items-center gap-2">
                        {providerId ? (
                            <ProviderLogo
                                providerId={providerId}
                                className="h-3.5 w-3.5"
                            />
                        ) : (
                            <RiPencilAiLine className="h-3 w-3 text-muted-foreground" />
                        )}
                        <span className="typography-meta font-medium text-foreground">
                            {providerId && modelId ? `${providerId}/${modelId}` : (placeholder || 'Select model...')}
                        </span>
                    </div>
                    <RiArrowDownSLine className="h-3 w-3 text-muted-foreground" />
                </button>
            ) : (
                <DropdownMenu open={isDropdownOpen} onOpenChange={setIsDropdownOpen}>
                    <DropdownMenuTrigger asChild>
                        <div className={cn(
                            'border-input data-[placeholder]:text-muted-foreground flex items-center justify-between gap-2 rounded-lg border bg-transparent px-2 py-2 typography-ui-label whitespace-nowrap shadow-none outline-none hover:bg-interactive-hover data-[state=open]:bg-interactive-active h-6 w-fit',
                            className
                        )}>
                            {providerId ? (
                                <>
                                    <ProviderLogo
                                        providerId={providerId}
                                        className="h-3.5 w-3.5 flex-shrink-0"
                                    />
                                    <RiPencilAiLine className="h-3 w-3 text-primary/60 hidden" />
                                </>
                            ) : (
                                <RiPencilAiLine className="h-3.5 w-3.5 text-muted-foreground" />
                            )}
                            <span className="typography-ui-label font-normal whitespace-nowrap text-foreground">
                                {providerId && modelId ? `${providerId}/${modelId}` : (placeholder || 'Not selected')}
                            </span>
                            <RiArrowDownSLine className="h-4 w-4 flex-shrink-0 text-muted-foreground/50" />
                        </div>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent className="w-[min(380px,calc(100vw-2rem))] p-0 flex flex-col" align="start">
                        {(() => {
                            // Build flat list for keyboard navigation
                            type FlatModelItem = { model: ProviderModel; providerID: string; modelID: string; section: string };
                            const flatModelList: FlatModelItem[] = [];

                            filteredLatest.forEach(({ entry, model }) => {
                                flatModelList.push({ model, providerID: entry.providerId, modelID: entry.modelId, section: 'latest' });
                            });
                            filteredFavorites.forEach(({ model, providerID, modelID }) => {
                                flatModelList.push({ model, providerID, modelID, section: 'fav' });
                            });
                            filteredRecents.forEach(({ model, providerID, modelID }) => {
                                flatModelList.push({ model, providerID, modelID, section: 'recent' });
                            });
                            filteredProviders.forEach((provider) => {
                                (provider.models as ProviderModel[]).forEach((model) => {
                                    flatModelList.push({ model, providerID: provider.id as string, modelID: model.id as string, section: 'provider' });
                                });
                            });

                            const totalItems = flatModelList.length;

                            // Handle keyboard navigation
                            const handleKeyDown = (e: React.KeyboardEvent) => {
                                e.stopPropagation();

                                if (e.key === 'ArrowDown') {
                                    e.preventDefault();
                                    const nextIndex = (selectedIndex + 1) % Math.max(1, totalItems);
                                    setSelectedIndex(nextIndex);
                                    setTimeout(() => {
                                        itemRefs.current[nextIndex]?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                                    }, 0);
                                } else if (e.key === 'ArrowUp') {
                                    e.preventDefault();
                                    const prevIndex = (selectedIndex - 1 + Math.max(1, totalItems)) % Math.max(1, totalItems);
                                    setSelectedIndex(prevIndex);
                                    setTimeout(() => {
                                        itemRefs.current[prevIndex]?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                                    }, 0);
                                } else if (e.key === 'Enter') {
                                    e.preventDefault();
                                    const selectedItem = flatModelList[selectedIndex];
                                    if (selectedItem) {
                                        handleProviderAndModelChange(selectedItem.providerID, selectedItem.modelID);
                                    }
                                } else if (e.key === 'Escape') {
                                    e.preventDefault();
                                    setIsDropdownOpen(false);
                                }
                            };

                            let currentFlatIndex = 0;

                            return (
                                <>
                                    {/* Search Input */}
                                    <div className="p-2 border-b border-border/40">
                                        <div className="relative">
                                            <RiSearchLine className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
                                            <Input
                                                type="text"
                                                placeholder="Search models"
                                                value={searchQuery}
                                                onChange={(e) => setSearchQuery(e.target.value)}
                                                onKeyDown={handleKeyDown}
                                                className="pl-8 h-8 typography-meta"
                                                autoFocus
                                            />
                                        </div>
                                    </div>

                                    {/* Scrollable content */}
                                    <ScrollableOverlay outerClassName="max-h-[min(400px,calc(100dvh-12rem))] flex-1">
                                        <div className="p-1">
                                            {/* Not selected option */}
                                            <div
                                                className={cn(
                                                    "typography-meta flex items-center gap-2 px-2 py-1.5 rounded-md cursor-pointer",
                                                    "hover:bg-interactive-hover/50"
                                                )}
                                                onClick={() => handleProviderAndModelChange('', '')}
                                            >
                                                <RiCloseLine className="h-3.5 w-3.5 text-muted-foreground" />
                                                <span className="text-muted-foreground">{placeholder || 'Not selected'}</span>
                                                {!providerId && !modelId && (
                                                    <RiCheckLine className="h-4 w-4 text-primary ml-auto" />
                                                )}
                                            </div>

                                            <DropdownMenuSeparator />

                                            {!hasResults && searchQuery && (
                                                <div className="px-2 py-4 text-center typography-meta text-muted-foreground">
                                                    No models found
                                                </div>
                                            )}

                                            {/* Latest Section — most recently released model per family */}
                                            {filteredLatest.length > 0 && (
                                                <>
                                                    <DropdownMenuLabel style={{ backgroundColor: 'var(--surface-elevated)' }} className="typography-micro font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-2 -mx-1 px-3 py-1.5 sticky top-0 z-10 border-b border-border/30">
                                                        <RiSparkling2Fill className="h-4 w-4 text-primary" />
                                                        Latest
                                                    </DropdownMenuLabel>
                                                    {filteredLatest.map(({ family, entry, model }) => {
                                                        const idx = currentFlatIndex++;
                                                        return renderLatestRow(family, entry, model, idx, selectedIndex === idx);
                                                    })}
                                                </>
                                            )}

                                            {/* Favorites Section */}
                                            {filteredFavorites.length > 0 && (
                                                <>
                                                    {filteredLatest.length > 0 && <DropdownMenuSeparator />}
                                                    <DropdownMenuLabel style={{ backgroundColor: 'var(--surface-elevated)' }} className="typography-micro font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-2 -mx-1 px-3 py-1.5 sticky top-0 z-10 border-b border-border/30">
                                                        <RiStarFill className="h-4 w-4 text-primary" />
                                                        Favorites
                                                    </DropdownMenuLabel>
                                                    {filteredFavorites.map(({ model, providerID, modelID }) => {
                                                        const idx = currentFlatIndex++;
                                                        return renderModelRow(model, providerID, modelID, 'fav', idx, selectedIndex === idx);
                                                    })}
                                                </>
                                            )}

                                            {/* Recents Section */}
                                            {filteredRecents.length > 0 && (
                                                <>
                                                    {filteredFavorites.length > 0 && <DropdownMenuSeparator />}
                                                    <DropdownMenuLabel style={{ backgroundColor: 'var(--surface-elevated)' }} className="typography-micro font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-2 -mx-1 px-3 py-1.5 sticky top-0 z-10 border-b border-border/30">
                                                        <RiTimeLine className="h-4 w-4" />
                                                        Recent
                                                    </DropdownMenuLabel>
                                                    {filteredRecents.map(({ model, providerID, modelID }) => {
                                                        const idx = currentFlatIndex++;
                                                        return renderModelRow(model, providerID, modelID, 'recent', idx, selectedIndex === idx);
                                                    })}
                                                </>
                                            )}

                                            {/* Separator before providers */}
                                            {(filteredFavorites.length > 0 || filteredRecents.length > 0) && filteredProviders.length > 0 && (
                                                <DropdownMenuSeparator />
                                            )}

                                            {/* All Providers - Flat List */}
                                            {filteredProviders.map((provider, index) => (
                                                <React.Fragment key={provider.id}>
                                                    {index > 0 && <DropdownMenuSeparator />}
                                                    <DropdownMenuLabel style={{ backgroundColor: 'var(--surface-elevated)' }} className="typography-micro font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-2 -mx-1 px-3 py-1.5 sticky top-0 z-10 border-b border-border/30">
                                                        <ProviderLogo
                                                            providerId={provider.id}
                                                            className="h-4 w-4 flex-shrink-0"
                                                        />
                                                        {provider.name}
                                                    </DropdownMenuLabel>
                                                    {(provider.models as ProviderModel[]).map((model: ProviderModel) => {
                                                        const idx = currentFlatIndex++;
                                                        return renderModelRow(model, provider.id as string, model.id as string, 'provider', idx, selectedIndex === idx);
                                                    })}
                                                </React.Fragment>
                                            ))}
                                        </div>
                                    </ScrollableOverlay>

                                    {/* Keyboard hints footer */}
                                    <div className="px-3 pt-1 pb-1.5 border-t border-border/40 typography-micro text-muted-foreground">
                                        ↑↓ navigate • Enter select • Esc close
                                    </div>
                                </>
                            );
                        })()}
                    </DropdownMenuContent>
                </DropdownMenu>
            )}
            {renderMobileModelPanel()}
        </>
    );
};
