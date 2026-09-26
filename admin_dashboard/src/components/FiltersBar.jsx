export default function FiltersBar({
  children,
  onSubmit,
  onRefresh,
  submitLabel = "Apply Filters",
  refreshLabel = "Refresh",
}) {
  function handleSubmit(event) {
    event.preventDefault();
    if (onSubmit) {
      onSubmit(event);
    }
  }

  return (
    <form className="filter-bar" onSubmit={handleSubmit}>
      {children}
      <div className="filter-actions">
        <button type="submit">{submitLabel}</button>
        <button type="button" className="ghost-btn" onClick={onRefresh}>
          {refreshLabel}
        </button>
      </div>
    </form>
  );
}
