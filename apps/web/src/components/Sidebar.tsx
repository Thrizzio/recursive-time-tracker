import { useEffect } from "react";
import { NavLink, useNavigate } from "react-router-dom";

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

/**
 * Minimal collapsible navigation sidebar.
 * Rendered as a fixed overlay so it never disrupts the page layout.
 */
export function Sidebar({ isOpen, onClose }: SidebarProps) {
  const navigate = useNavigate();

  // Close sidebar on Escape key
  useEffect(() => {
    if (!isOpen) return;
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", handleKey);
    return () => document.removeEventListener("keydown", handleKey);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  function handleNavClick(to: string) {
    onClose();
    navigate(to);
  }

  const navLinkClass = ({ isActive }: { isActive: boolean }) =>
    `block w-full text-left px-4 py-2.5 rounded-lg text-sm font-medium transition-colors ${
      isActive
        ? "bg-zinc-800 text-cyan-400"
        : "text-zinc-300 hover:bg-zinc-800/60 hover:text-zinc-50"
    }`;

  return (
    <>
      {/* Backdrop — click to close */}
      <div
        className="fixed inset-0 z-40 bg-zinc-950/60 backdrop-blur-sm"
        onClick={onClose}
        aria-hidden
      />

      {/* Sidebar panel */}
      <nav
        className="fixed left-0 top-0 z-50 flex h-full w-56 flex-col border-r border-zinc-800 bg-zinc-900 shadow-2xl"
        aria-label="Main navigation"
      >
        {/* Brand + close button */}
        <div className="flex items-center justify-between px-4 py-5 border-b border-zinc-800">
          <span className="text-xs font-semibold uppercase tracking-widest text-cyan-400">
            Chronolog
          </span>
          <button
            onClick={onClose}
            className="rounded-md p-1 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800 transition-colors"
            aria-label="Close navigation"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="3" y1="3" x2="13" y2="13" />
              <line x1="13" y1="3" x2="3" y2="13" />
            </svg>
          </button>
        </div>

        {/* Primary nav links */}
        <div className="flex-1 space-y-1 px-3 py-4">
          <NavLink to="/dashboard" className={navLinkClass} onClick={() => onClose()}>
            Dashboard
          </NavLink>
          <NavLink to="/activities" className={navLinkClass} onClick={() => onClose()}>
            Activities
          </NavLink>
        </div>

        {/* Secondary nav — Settings at bottom */}
        <div className="border-t border-zinc-800 px-3 py-4">
          <button
            className="block w-full text-left px-4 py-2.5 rounded-lg text-sm font-medium text-zinc-400 hover:bg-zinc-800/60 hover:text-zinc-200 transition-colors"
            onClick={() => handleNavClick("/settings")}
          >
            Settings
          </button>
        </div>
      </nav>
    </>
  );
}

/**
 * Hamburger/menu button that toggles the sidebar open.
 */
export function MenuButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="rounded-md p-1.5 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800 transition-colors"
      aria-label="Open navigation"
    >
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
        <line x1="2" y1="5" x2="16" y2="5" />
        <line x1="2" y1="9" x2="16" y2="9" />
        <line x1="2" y1="13" x2="16" y2="13" />
      </svg>
    </button>
  );
}
