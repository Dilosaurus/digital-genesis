import { useState, useMemo } from 'react'
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  flexRender,
  type ColumnDef,
  type SortingState,
} from '@tanstack/react-table'

interface DataTableProps<TData> {
  data: TData[]
  columns: ColumnDef<TData, unknown>[]
  pageSize?: number
}

// ---------------------------------------------------------------------------
// SVG Icons
// ---------------------------------------------------------------------------

function SearchIcon() {
  return (
    <svg
      className="w-4 h-4 text-gray-500"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
      />
    </svg>
  )
}

function ChevronUpIcon({ className }: { className?: string }) {
  return (
    <svg className={className ?? 'w-3.5 h-3.5'} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
    </svg>
  )
}

function ChevronDownIcon({ className }: { className?: string }) {
  return (
    <svg className={className ?? 'w-3.5 h-3.5'} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
    </svg>
  )
}

function ChevronUpDownIcon({ className }: { className?: string }) {
  return (
    <svg className={className ?? 'w-3.5 h-3.5'} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 11l5-5 5 5M7 13l5 5 5-5" />
    </svg>
  )
}

function EmptyIcon() {
  return (
    <svg className="w-12 h-12 text-gray-600 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  )
}

// ---------------------------------------------------------------------------
// DataTable
// ---------------------------------------------------------------------------

export function DataTable<TData>({
  data,
  columns,
  pageSize = 25,
}: DataTableProps<TData>) {
  const [sorting, setSorting] = useState<SortingState>([])
  const [globalFilter, setGlobalFilter] = useState('')

  const table = useReactTable({
    data,
    columns,
    state: {
      sorting,
      globalFilter,
    },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    initialState: {
      pagination: {
        pageSize,
      },
    },
  })

  const totalRows = table.getFilteredRowModel().rows.length
  const pageIndex = table.getState().pagination.pageIndex
  const rowsPerPage = table.getState().pagination.pageSize
  const firstRow = totalRows === 0 ? 0 : pageIndex * rowsPerPage + 1
  const lastRow = Math.min((pageIndex + 1) * rowsPerPage, totalRows)

  const pageCount = table.getPageCount()

  // Generate page buttons: show at most 7 page buttons with ellipsis
  const pageButtons = useMemo(() => {
    if (pageCount <= 7) {
      return Array.from({ length: pageCount }, (_, i) => i)
    }
    const current = pageIndex
    const pages: (number | 'ellipsis')[] = []
    pages.push(0)
    if (current > 3) pages.push('ellipsis')
    for (let i = Math.max(1, current - 1); i <= Math.min(pageCount - 2, current + 1); i++) {
      pages.push(i)
    }
    if (current < pageCount - 4) pages.push('ellipsis')
    pages.push(pageCount - 1)
    return pages
  }, [pageCount, pageIndex])

  return (
    <div className="flex flex-col gap-4">
      {/* Search + row count */}
      <div className="flex items-center gap-3">
        <div className="relative">
          <div className="absolute inset-y-0 left-3 flex items-center pointer-events-none">
            <SearchIcon />
          </div>
          <input
            type="text"
            value={globalFilter}
            onChange={e => setGlobalFilter(e.target.value)}
            placeholder="Search..."
            className="pl-10 pr-4 py-2 text-sm rounded-full bg-[var(--bg-elevated)] border border-gray-700/50 text-gray-100 placeholder-gray-500 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/30 w-80 transition-colors"
          />
        </div>
        <span className="badge bg-gray-800/80 text-gray-400 border border-gray-700/50">
          {totalRows} {totalRows === 1 ? 'row' : 'rows'}
        </span>
      </div>

      {/* Table wrapper */}
      <div className="overflow-x-auto rounded-lg border border-gray-800/60">
        <table className="w-full text-sm border-collapse">
          <thead className="sticky top-0 z-10">
            {table.getHeaderGroups().map(headerGroup => (
              <tr key={headerGroup.id} className="bg-[var(--bg-surface)]">
                {headerGroup.headers.map(header => {
                  const canSort = header.column.getCanSort()
                  const sorted = header.column.getIsSorted()
                  return (
                    <th
                      key={header.id}
                      className={[
                        'px-3 py-2.5 text-left text-xs font-semibold uppercase tracking-wide whitespace-nowrap select-none',
                        'border-b border-purple-500/10',
                        canSort ? 'cursor-pointer hover:text-gray-200' : '',
                        sorted ? 'text-purple-400' : 'text-gray-400',
                      ].join(' ')}
                      onClick={canSort ? header.column.getToggleSortingHandler() : undefined}
                    >
                      <span className="inline-flex items-center gap-1">
                        {flexRender(header.column.columnDef.header, header.getContext())}
                        {canSort && (
                          <span className={sorted ? 'text-purple-400' : 'text-gray-600'}>
                            {sorted === 'asc' ? (
                              <ChevronUpIcon />
                            ) : sorted === 'desc' ? (
                              <ChevronDownIcon />
                            ) : (
                              <ChevronUpDownIcon />
                            )}
                          </span>
                        )}
                      </span>
                    </th>
                  )
                })}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.length === 0 ? (
              <tr>
                <td
                  colSpan={columns.length}
                  className="px-3 py-16 text-center"
                >
                  <div className="flex flex-col items-center justify-center">
                    <EmptyIcon />
                    <p className="text-gray-400 text-sm font-medium">No results found</p>
                    <p className="text-gray-600 text-xs mt-1">Try adjusting your search query</p>
                  </div>
                </td>
              </tr>
            ) : (
              table.getRowModel().rows.map(row => (
                <tr
                  key={row.id}
                  className="border-b border-gray-800/50 border-l-2 border-l-transparent hover:border-l-purple-500/50 hover:bg-[var(--bg-hover)] transition-colors duration-150"
                >
                  {row.getVisibleCells().map(cell => (
                    <td
                      key={cell.id}
                      className="px-3 py-2 text-gray-200 whitespace-nowrap"
                    >
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {pageCount > 1 && (
        <div className="flex items-center justify-between gap-4 text-xs text-gray-400">
          <span>
            {firstRow}–{lastRow} of {totalRows}
          </span>
          <div className="flex items-center gap-1">
            <button
              onClick={() => table.previousPage()}
              disabled={!table.getCanPreviousPage()}
              className="px-3 py-1.5 rounded-full text-gray-300 hover:enabled:bg-[var(--bg-elevated)] hover:enabled:text-white disabled:opacity-30 transition-colors duration-150"
            >
              Prev
            </button>
            {pageButtons.map((page, idx) =>
              page === 'ellipsis' ? (
                <span key={`ellipsis-${idx}`} className="px-1 text-gray-600">
                  ...
                </span>
              ) : (
                <button
                  key={page}
                  onClick={() => table.setPageIndex(page)}
                  className={[
                    'w-8 h-8 rounded-full text-xs font-medium transition-all duration-150',
                    page === pageIndex
                      ? 'gradient-purple text-white glow-purple'
                      : 'text-gray-400 hover:bg-[var(--bg-elevated)] hover:text-gray-200',
                  ].join(' ')}
                >
                  {page + 1}
                </button>
              )
            )}
            <button
              onClick={() => table.nextPage()}
              disabled={!table.getCanNextPage()}
              className="px-3 py-1.5 rounded-full text-gray-300 hover:enabled:bg-[var(--bg-elevated)] hover:enabled:text-white disabled:opacity-30 transition-colors duration-150"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
