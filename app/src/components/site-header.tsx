import Link from "next/link";

export function SiteHeader({ backHref }: { backHref?: string }) {
  return (
    <header className="site-header">
      <div className="site-header__inner">
        {backHref ? (
          <Link className="header-back" href={backHref} aria-label="Go back">
            <span aria-hidden="true">←</span>
            <span>Back</span>
          </Link>
        ) : (
          <Link className="wordmark" href="/" aria-label="Cove home">
            Cove
          </Link>
        )}
        {backHref ? (
          <Link className="wordmark wordmark--center" href="/">
            Cove
          </Link>
        ) : null}
        <span className="header-note">Dinner, handled.</span>
      </div>
    </header>
  );
}
