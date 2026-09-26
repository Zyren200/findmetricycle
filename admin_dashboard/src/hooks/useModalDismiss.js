import { useEffect } from "react";

// Every dialog in the dashboard is a `.modal-overlay.open` wrapping a
// `.modal` with a `.modal-close` (×) button. This adds the two standard
// ways out that none of them had: Esc, and clicking the dimmed backdrop.
// It works by pressing that dialog's own × button, so each dialog keeps its
// own close logic (e.g. a disabled × while it's busy still can't close it).
function topmostOverlay() {
  const overlays = document.querySelectorAll(".modal-overlay.open");
  return overlays.length ? overlays[overlays.length - 1] : null;
}

function closeOverlay(overlay) {
  const closeButton = overlay?.querySelector(".modal-close");
  if (closeButton && !closeButton.disabled) closeButton.click();
}

export function useModalDismiss() {
  useEffect(() => {
    function onKeyDown(event) {
      if (event.key !== "Escape") return;
      const overlay = topmostOverlay();
      if (!overlay) return;
      event.preventDefault();
      closeOverlay(overlay);
    }

    // mousedown + mouseup both on the backdrop, so a text selection dragged
    // out of the dialog doesn't close it by accident.
    let pressedOnBackdrop = null;
    function onMouseDown(event) {
      pressedOnBackdrop = event.target.classList?.contains("modal-overlay") ? event.target : null;
    }
    function onMouseUp(event) {
      if (pressedOnBackdrop && event.target === pressedOnBackdrop) {
        closeOverlay(pressedOnBackdrop);
      }
      pressedOnBackdrop = null;
    }

    document.addEventListener("keydown", onKeyDown);
    document.addEventListener("mousedown", onMouseDown);
    document.addEventListener("mouseup", onMouseUp);
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.removeEventListener("mousedown", onMouseDown);
      document.removeEventListener("mouseup", onMouseUp);
    };
  }, []);
}
