export default function PageHero({ eyebrow, title, description, actions }) {
  return (
    <section className="panel page-hero">
      <div className="page-hero-copy">
        {eyebrow ? <p className="page-hero-eyebrow">{eyebrow}</p> : null}
        <h2>{title}</h2>
        {description ? <p className="muted">{description}</p> : null}
      </div>
      {actions ? <div className="page-hero-actions">{actions}</div> : null}
    </section>
  );
}
