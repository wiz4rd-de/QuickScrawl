import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import Underline from "@tiptap/extension-underline";
import TextStyle from "@tiptap/extension-text-style";
import Color from "@tiptap/extension-color";
import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";

// ── State ──────────────────────────────────────────────────────────────

let fontSize = 18;
let alwaysOnTop = false;
let saveTimeout: number | null = null;

// ── Editor setup ───────────────────────────────────────────────────────

const editor = new Editor({
  element: document.querySelector("#editor")!,
  extensions: [
    StarterKit.configure({ heading: false, codeBlock: false, blockquote: false }),
    Underline,
    TextStyle,
    Color,
  ],
  autofocus: true,
  editorProps: {
    handlePaste(_view, event) {
      // Smart paste: strip all formatting except bold
      const html = event.clipboardData?.getData("text/html");
      if (!html) return false; // let Tiptap handle plain text

      const doc = new DOMParser().parseFromString(html, "text/html");
      stripExceptBold(doc.body);
      const cleaned = doc.body.innerHTML;

      editor.chain().focus().insertContent(cleaned).run();
      return true;
    },
  },
  onUpdate() {
    scheduleSave();
  },
});

// ── Smart paste helper ─────────────────────────────────────────────────

function stripExceptBold(node: Node) {
  if (node.nodeType === Node.ELEMENT_NODE) {
    const el = node as HTMLElement;
    // Remove all inline styles except font-weight bold
    const isBold =
      el.style.fontWeight === "bold" ||
      parseInt(el.style.fontWeight) >= 700;
    el.removeAttribute("style");
    el.removeAttribute("class");
    el.removeAttribute("color");

    // Remove non-bold formatting tags, keep <b>/<strong>
    const tag = el.tagName.toLowerCase();
    const keepTags = new Set([
      "b", "strong", "p", "div", "br", "span", "body",
    ]);

    if (!keepTags.has(tag)) {
      // Replace element with its children
      const parent = el.parentNode;
      if (parent) {
        while (el.firstChild) parent.insertBefore(el.firstChild, el);
        parent.removeChild(el);
        return;
      }
    }

    // If span had bold style, convert to <strong>
    if (tag === "span" && isBold) {
      const strong = document.createElement("strong");
      while (el.firstChild) strong.appendChild(el.firstChild);
      el.parentNode?.replaceChild(strong, el);
      for (let i = 0; i < strong.childNodes.length; i++) {
        stripExceptBold(strong.childNodes[i]);
      }
      return;
    }
  }

  // Recurse into children (iterate backwards since we may modify the list)
  const children = Array.from(node.childNodes);
  for (const child of children) {
    stripExceptBold(child);
  }
}

// ── Persistence ────────────────────────────────────────────────────────

function scheduleSave() {
  if (saveTimeout) clearTimeout(saveTimeout);
  saveTimeout = window.setTimeout(() => {
    invoke("save_note", { content: editor.getHTML() });
  }, 1500);
}

function saveNow() {
  if (saveTimeout) clearTimeout(saveTimeout);
  invoke("save_note", { content: editor.getHTML() });
}

async function loadNote() {
  const content = await invoke<string | null>("load_note");
  if (content) {
    editor.commands.setContent(content);
  }
}

// Save on window close and blur
getCurrentWindow().onCloseRequested(() => {
  saveNow();
});
window.addEventListener("blur", saveNow);

// Load saved content
loadNote();

// ── Font size zoom ─────────────────────────────────────────────────────

function updateFontSize() {
  document.documentElement.style.setProperty("--font-size", `${fontSize}px`);
  updateFontSizeDisplay();
}

function increaseFontSize() {
  fontSize = Math.min(fontSize + 2, 72);
  updateFontSize();
}

function decreaseFontSize() {
  fontSize = Math.max(fontSize - 2, 10);
  updateFontSize();
}

function resetFontSize() {
  fontSize = 18;
  updateFontSize();
}

document.addEventListener("keydown", (e) => {
  const mod = e.metaKey || e.ctrlKey;
  if (!mod) return;

  if (e.key === "=" || e.key === "+") {
    e.preventDefault();
    increaseFontSize();
  } else if (e.key === "-") {
    e.preventDefault();
    decreaseFontSize();
  } else if (e.key === "0") {
    e.preventDefault();
    resetFontSize();
  }
});

// ── Toolbar ────────────────────────────────────────────────────────────

const toolbar = document.querySelector("#toolbar")!;

const colors = [
  { name: "black", css: "#000000" },
  { name: "red", css: "#ff0000" },
  { name: "green", css: "#008000" },
  { name: "blue", css: "#0000ff" },
];

function createToolbar() {
  // Format buttons
  const boldBtn = makeFormatButton("B", "bold", () =>
    editor.chain().focus().toggleBold().run()
  );
  boldBtn.style.fontWeight = "bold";

  const underlineBtn = makeFormatButton("U", "underline", () =>
    editor.chain().focus().toggleUnderline().run()
  );
  underlineBtn.style.textDecoration = "underline";

  const strikeBtn = makeFormatButton("S", "strike", () =>
    editor.chain().focus().toggleStrike().run()
  );
  strikeBtn.style.textDecoration = "line-through";

  toolbar.appendChild(boldBtn);
  toolbar.appendChild(underlineBtn);
  toolbar.appendChild(strikeBtn);

  // Divider
  const div1 = document.createElement("div");
  div1.className = "toolbar-divider";
  toolbar.appendChild(div1);

  // Color buttons
  for (const color of colors) {
    const btn = document.createElement("button");
    btn.className = "color-btn";
    btn.dataset.color = color.css;
    btn.style.backgroundColor = color.css;
    btn.addEventListener("click", () => {
      editor.chain().focus().setColor(color.css).run();
      updateToolbarState();
    });
    toolbar.appendChild(btn);
  }

  // Spacer
  const spacer = document.createElement("div");
  spacer.className = "toolbar-spacer";
  toolbar.appendChild(spacer);

  // Font size display
  const sizeDisplay = document.createElement("span");
  sizeDisplay.id = "font-size-display";
  sizeDisplay.textContent = `${fontSize}px`;
  toolbar.appendChild(sizeDisplay);

  // Always-on-top pin button
  const pinBtn = document.createElement("button");
  pinBtn.id = "pin-btn";
  pinBtn.textContent = "\u{1F4CC}";
  pinBtn.title = "Always on top";
  pinBtn.addEventListener("click", () => {
    invoke<boolean>("toggle_always_on_top")
      .then((isOnTop) => {
        alwaysOnTop = isOnTop;
        pinBtn.classList.toggle("active", alwaysOnTop);
      })
      .catch((err) => {
        console.error("toggle_always_on_top failed:", err);
      });
  });
  toolbar.appendChild(pinBtn);
}

function makeFormatButton(
  label: string,
  markName: string,
  action: () => void
): HTMLButtonElement {
  const btn = document.createElement("button");
  btn.textContent = label;
  btn.dataset.mark = markName;
  btn.addEventListener("click", action);
  return btn;
}

function updateToolbarState() {
  // Format buttons
  toolbar.querySelectorAll<HTMLButtonElement>("button[data-mark]").forEach((btn) => {
    const mark = btn.dataset.mark!;
    btn.classList.toggle("active", editor.isActive(mark));
  });

  // Color buttons
  const currentColor =
    (editor.getAttributes("textStyle").color as string) || "#000000";
  toolbar.querySelectorAll<HTMLButtonElement>(".color-btn").forEach((btn) => {
    btn.classList.toggle(
      "active",
      btn.dataset.color?.toLowerCase() === currentColor.toLowerCase()
    );
  });
}

function updateFontSizeDisplay() {
  const el = document.getElementById("font-size-display");
  if (el) el.textContent = `${fontSize}px`;
}

// Listen to editor selection/transaction changes to update toolbar
editor.on("selectionUpdate", updateToolbarState);
editor.on("transaction", updateToolbarState);

// Build toolbar
createToolbar();
