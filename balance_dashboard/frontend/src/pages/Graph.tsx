import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  ReactFlow,
  ReactFlowProvider,
  MiniMap,
  Controls,
  Background,
  BackgroundVariant,
  useNodesState,
  useEdgesState,
  useReactFlow,
  type Node,
  type Edge,
  type NodeMouseHandler,
  type OnInit,
  MarkerType,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import Dagre from '@dagrejs/dagre'

import { useGraph } from '../hooks/useApi'
import { CustomNode } from '../components/Graph/CustomNode'
import { GraphControls, NODE_TYPES } from '../components/Graph/GraphControls'
import type { NodeTypeKey } from '../components/Graph/GraphControls'
import type { GraphNode, GraphEdge } from '../types'

// ---------------------------------------------------------------------------
// Dagre layout
// ---------------------------------------------------------------------------

function getLayoutedElements(
  nodes: Node[],
  edges: Edge[],
): { nodes: Node[]; edges: Edge[] } {
  const g = new Dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}))
  g.setGraph({ rankdir: 'TB', nodesep: 60, ranksep: 90 })

  nodes.forEach(node => g.setNode(node.id, { width: 200, height: 70 }))
  edges.forEach(edge => g.setEdge(edge.source, edge.target))

  Dagre.layout(g)

  return {
    nodes: nodes.map(node => {
      const pos = g.node(node.id)
      return { ...node, position: { x: pos.x - 100, y: pos.y - 35 } }
    }),
    edges,
  }
}

// ---------------------------------------------------------------------------
// Convert API GraphNode/GraphEdge to React Flow Node/Edge
// ---------------------------------------------------------------------------

function toFlowNode(n: GraphNode): Node {
  return {
    id: n.id,
    type: 'custom',
    position: { x: 0, y: 0 }, // Dagre will overwrite this
    data: {
      label: n.label,
      nodeType: n.type,
      ...n.data,
    },
  }
}

function toFlowEdge(e: GraphEdge): Edge {
  return {
    id: e.id,
    source: e.source,
    target: e.target,
    label: e.label || undefined,
    markerEnd: { type: MarkerType.ArrowClosed, color: '#4b5563' },
    style: { stroke: '#4b5563', strokeWidth: 1.5 },
    labelStyle: { fill: '#9ca3af', fontSize: 9 },
    labelBgStyle: { fill: '#151621', fillOpacity: 0.9 },
    labelBgPadding: [4, 3],
  }
}

// ---------------------------------------------------------------------------
// Node types registration (must be stable — defined outside component)
// ---------------------------------------------------------------------------

const NODE_TYPES_MAP = { custom: CustomNode }

// ---------------------------------------------------------------------------
// Inner graph component — needs ReactFlowProvider context
// ---------------------------------------------------------------------------

interface GraphInnerProps {
  apiNodes: GraphNode[]
  apiEdges: GraphEdge[]
}

function GraphInner({ apiNodes, apiEdges }: GraphInnerProps) {
  const { fitView } = useReactFlow()
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([])
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([])
  const [visibleTypes, setVisibleTypes] = useState<Set<NodeTypeKey>>(
    new Set(NODE_TYPES),
  )
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null)
  const initialLayoutDone = useRef(false)

  // -------------------------------------------------------------------------
  // Build filtered + layouted nodes/edges whenever source data or filters change
  // -------------------------------------------------------------------------

  const { filteredFlowNodes, filteredFlowEdges } = useMemo(() => {
    const visibleIds = new Set(
      apiNodes
        .filter(n => visibleTypes.has(n.type as NodeTypeKey))
        .map(n => n.id),
    )

    const filteredFlowNodes = apiNodes
      .filter(n => visibleIds.has(n.id))
      .map(toFlowNode)

    const filteredFlowEdges = apiEdges
      .filter(e => visibleIds.has(e.source) && visibleIds.has(e.target))
      .map(toFlowEdge)

    return { filteredFlowNodes, filteredFlowEdges }
  }, [apiNodes, apiEdges, visibleTypes])

  // Re-run dagre layout and push to React Flow state
  useEffect(() => {
    if (filteredFlowNodes.length === 0) {
      setNodes([])
      setEdges([])
      return
    }

    const { nodes: layoutedNodes, edges: layoutedEdges } = getLayoutedElements(
      filteredFlowNodes,
      filteredFlowEdges,
    )

    setNodes(layoutedNodes)
    setEdges(layoutedEdges)

    // Fit view after first layout; subsequent filter changes keep current viewport
    if (!initialLayoutDone.current) {
      initialLayoutDone.current = true
      // Wait one tick for nodes to render before fitting
      requestAnimationFrame(() => {
        fitView({ padding: 0.1, duration: 400 })
      })
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filteredFlowNodes, filteredFlowEdges])

  // -------------------------------------------------------------------------
  // Highlight logic — connected neighbours when a node is selected
  // -------------------------------------------------------------------------

  const connectedIds = useMemo(() => {
    if (!selectedNodeId) return null
    const connected = new Set<string>([selectedNodeId])
    filteredFlowEdges.forEach(e => {
      if (e.source === selectedNodeId) connected.add(e.target)
      if (e.target === selectedNodeId) connected.add(e.source)
    })
    return connected
  }, [selectedNodeId, filteredFlowEdges])

  const connectedEdgeIds = useMemo(() => {
    if (!selectedNodeId) return null
    const ids = new Set<string>()
    filteredFlowEdges.forEach(e => {
      if (e.source === selectedNodeId || e.target === selectedNodeId) {
        ids.add(e.id)
      }
    })
    return ids
  }, [selectedNodeId, filteredFlowEdges])

  // Apply highlight/dim styling to nodes and edges
  const displayNodes = useMemo(() => {
    if (!connectedIds) return nodes
    return nodes.map(n => ({
      ...n,
      data: {
        ...n.data,
        highlighted: connectedIds.has(n.id),
        dimmed: !connectedIds.has(n.id),
      },
    }))
  }, [nodes, connectedIds])

  const displayEdges = useMemo(() => {
    if (!connectedEdgeIds) return edges
    return edges.map(e => ({
      ...e,
      style: connectedEdgeIds.has(e.id)
        ? { stroke: '#a78bfa', strokeWidth: 2.5 }
        : { stroke: '#1c1d2e', strokeWidth: 1, opacity: 0.3 },
      animated: connectedEdgeIds.has(e.id),
    }))
  }, [edges, connectedEdgeIds])

  // -------------------------------------------------------------------------
  // Interactions
  // -------------------------------------------------------------------------

  const handleNodeClick: NodeMouseHandler = useCallback((_evt, node) => {
    setSelectedNodeId(prev => (prev === node.id ? null : node.id))
  }, [])

  const handlePaneClick = useCallback(() => {
    setSelectedNodeId(null)
  }, [])

  const handleResetView = useCallback(() => {
    fitView({ padding: 0.1, duration: 400 })
  }, [fitView])

  // -------------------------------------------------------------------------
  // Filter panel handlers
  // -------------------------------------------------------------------------

  const handleToggleType = useCallback((type: NodeTypeKey) => {
    setVisibleTypes(prev => {
      const next = new Set(prev)
      if (next.has(type)) {
        next.delete(type)
      } else {
        next.add(type)
      }
      return next
    })
  }, [])

  const handleToggleAll = useCallback((checked: boolean) => {
    setVisibleTypes(checked ? new Set(NODE_TYPES) : new Set())
  }, [])

  // -------------------------------------------------------------------------
  // Selected node label (for controls panel display)
  // -------------------------------------------------------------------------

  const selectedNodeLabel = useMemo(() => {
    if (!selectedNodeId) return null
    const n = nodes.find(n => n.id === selectedNodeId)
    return (n?.data?.label as string) ?? selectedNodeId
  }, [selectedNodeId, nodes])

  // -------------------------------------------------------------------------
  // React Flow init — fit view once layout is ready
  // -------------------------------------------------------------------------

  const onInit: OnInit = useCallback(
    instance => {
      instance.fitView({ padding: 0.1 })
    },
    [],
  )

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* Header area with gradient */}
      <div className="gradient-header px-4 py-3">
        <h1 className="text-gray-100 text-lg font-semibold tracking-wide">
          Dependency Graph
        </h1>
        <p className="text-gray-500 text-xs mt-0.5">
          Visualize relationships between cards, stats, relics, and more
        </p>
      </div>

      <div className="flex flex-1 overflow-hidden gap-3 px-3 pb-3">
      {/* Filter panel */}
      <GraphControls
        visibleTypes={visibleTypes}
        onToggleType={handleToggleType}
        onToggleAll={handleToggleAll}
        onResetView={handleResetView}
        nodeCount={nodes.length}
        edgeCount={edges.length}
        selectedNodeLabel={selectedNodeLabel}
        onClearSelection={() => setSelectedNodeId(null)}
      />

      {/* Graph canvas */}
      <div className="flex-1 rounded-xl overflow-hidden border border-purple-500/10 shadow-lg shadow-black/20">
        <ReactFlow
          nodes={displayNodes}
          edges={displayEdges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          nodeTypes={NODE_TYPES_MAP}
          onNodeClick={handleNodeClick}
          onPaneClick={handlePaneClick}
          onInit={onInit}
          fitView
          colorMode="dark"
          minZoom={0.05}
          maxZoom={2}
          defaultEdgeOptions={{
            markerEnd: { type: MarkerType.ArrowClosed, color: '#6b7280' },
          }}
          proOptions={{ hideAttribution: true }}
        >
          <Background
            variant={BackgroundVariant.Dots}
            gap={20}
            size={1}
            color="#242538"
          />
          <MiniMap
            nodeColor={n => {
              const type = (n.data?.nodeType as string) ?? ''
              const MAP: Record<string, string> = {
                card: '#1d4ed8',
                stat: '#b91c1c',
                relic: '#15803d',
                equipment: '#7e22ce',
                gem: '#c2410c',
                skill: '#0e7490',
                enemy: '#374151',
                tag: '#a16207',
              }
              return MAP[type] ?? '#4b5563'
            }}
            maskColor="rgba(0,0,0,0.65)"
            style={{ background: '#0f1019', border: '1px solid rgba(139, 92, 246, 0.15)', borderRadius: 8 }}
          />
          <Controls
            style={{ background: '#151621', border: '1px solid rgba(139, 92, 246, 0.15)', borderRadius: 8 }}
          />
        </ReactFlow>
      </div>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Outer Graph page — handles data fetching and loading/error states
// ---------------------------------------------------------------------------

export default function Graph() {
  const { data, loading, error, refetch } = useGraph()

  if (loading) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="flex flex-col items-center gap-3 text-gray-400">
          <svg
            className="w-8 h-8 animate-spin text-purple-400"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            aria-hidden
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
            />
          </svg>
          <span className="text-sm">Loading dependency graph...</span>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="flex flex-col items-center gap-4 max-w-md text-center">
          <div className="w-12 h-12 rounded-full bg-red-900/40 flex items-center justify-center">
            <svg
              className="w-6 h-6 text-red-400"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"
              />
            </svg>
          </div>
          <div>
            <h2 className="text-gray-100 font-semibold mb-1">
              Failed to load graph
            </h2>
            <p className="text-gray-400 text-sm">{error}</p>
          </div>
          <button
            onClick={refetch}
            className="rounded bg-purple-700 hover:bg-purple-600 transition-colors px-4 py-2 text-sm font-medium text-white"
          >
            Retry
          </button>
        </div>
      </div>
    )
  }

  if (!data || (data.nodes.length === 0 && data.edges.length === 0)) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <p className="text-gray-500 text-sm">No graph data available.</p>
      </div>
    )
  }

  return (
    <ReactFlowProvider>
      <GraphInner apiNodes={data.nodes} apiEdges={data.edges} />
    </ReactFlowProvider>
  )
}
