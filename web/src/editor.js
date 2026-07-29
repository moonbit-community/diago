import {
  defaultKeymap,
  history,
  historyKeymap,
  indentWithTab,
} from "@codemirror/commands";
import { bracketMatching, indentUnit } from "@codemirror/language";
import { EditorState, StateEffect, StateField } from "@codemirror/state";
import {
  Decoration,
  EditorView,
  drawSelection,
  dropCursor,
  highlightActiveLine,
  highlightActiveLineGutter,
  highlightSpecialChars,
  keymap,
  lineNumbers,
  placeholder,
} from "@codemirror/view";

const TOKEN_CLASSES = Object.freeze({
  comment: "tok-comment",
  string: "tok-string",
  number: "tok-number",
  boolean: "tok-boolean",
  keyword: "tok-keyword",
  identifier: "tok-identifier",
  operator: "tok-operator",
  punctuation: "tok-punctuation",
});

const setHighlighter = StateEffect.define();

function buildDecorations(doc, highlighter) {
  if (highlighter === null) {
    return Decoration.none;
  }
  try {
    const result = highlighter(doc.toString());
    if (!result.ok) {
      return Decoration.none;
    }
    return Decoration.set(
      result.tokens.map((token) =>
        Decoration.mark({ class: TOKEN_CLASSES[token.kind] }).range(
          token.from,
          token.to,
        ),
      ),
      true,
    );
  } catch (error) {
    console.error("Diago syntax highlighting failed:", error);
    return Decoration.none;
  }
}

const syntaxTokens = StateField.define({
  create() {
    return { highlighter: null, decorations: Decoration.none };
  },
  update(value, transaction) {
    let highlighter = value.highlighter;
    let refresh = transaction.docChanged;
    for (const effect of transaction.effects) {
      if (effect.is(setHighlighter)) {
        highlighter = effect.value;
        refresh = true;
      }
    }
    return {
      highlighter,
      decorations: refresh
        ? buildDecorations(transaction.state.doc, highlighter)
        : value.decorations,
    };
  },
  provide: (field) =>
    EditorView.decorations.from(field, (value) => value.decorations),
});

const diagoTheme = EditorView.theme(
  {
    "&": {
      height: "100%",
      minHeight: "0",
      backgroundColor: "#0f0f23",
      color: "#e0e0e0",
      fontSize: "14px",
    },
    "&.cm-focused": {
      outline: "none",
    },
    ".cm-scroller": {
      overflow: "auto",
      fontFamily: "'SF Mono', 'Fira Code', 'Consolas', monospace",
      lineHeight: "1.6",
    },
    ".cm-content": {
      padding: "1rem 0",
      caretColor: "#f8f8f2",
    },
    ".cm-line": {
      padding: "0 1rem",
    },
    ".cm-gutters": {
      backgroundColor: "#0b0b1d",
      color: "#555b75",
      border: "none",
      paddingLeft: "0.25rem",
    },
    ".cm-activeLine": {
      backgroundColor: "#171731",
    },
    ".cm-activeLineGutter": {
      backgroundColor: "#171731",
      color: "#a9b1d6",
    },
    ".cm-selectionBackground, &.cm-focused .cm-selectionBackground, ::selection": {
      backgroundColor: "#33467c !important",
    },
    ".cm-cursor": {
      borderLeftColor: "#f8f8f2",
    },
    ".cm-placeholder": {
      color: "#555b75",
    },
    ".tok-comment": {
      color: "#6a9955",
      fontStyle: "italic",
    },
    ".tok-string": {
      color: "#ce9178",
    },
    ".tok-number": {
      color: "#b5cea8",
    },
    ".tok-boolean": {
      color: "#569cd6",
    },
    ".tok-keyword": {
      color: "#c586c0",
      fontWeight: "600",
    },
    ".tok-identifier": {
      color: "#9cdcfe",
    },
    ".tok-operator": {
      color: "#dcdcaa",
      fontWeight: "600",
    },
    ".tok-punctuation": {
      color: "#d4d4d4",
    },
  },
  { dark: true },
);

export function createSourceEditor({ parent, onChange, onBlur }) {
  const state = EditorState.create({
    doc: "",
    extensions: [
      lineNumbers(),
      highlightActiveLineGutter(),
      highlightSpecialChars(),
      history(),
      drawSelection(),
      dropCursor(),
      bracketMatching(),
      highlightActiveLine(),
      EditorView.lineWrapping,
      indentUnit.of("  "),
      keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
      placeholder("# Enter Diago diagram code here"),
      EditorView.contentAttributes.of({
        "aria-label": "Diago source editor",
        spellcheck: "false",
      }),
      syntaxTokens,
      diagoTheme,
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          onChange();
        }
      }),
      EditorView.domEventHandlers({
        blur() {
          onBlur();
        },
      }),
    ],
  });
  const view = new EditorView({ state, parent });

  return Object.freeze({
    getValue() {
      return view.state.doc.toString();
    },
    setValue(value) {
      const current = view.state.doc.toString();
      if (value === current) {
        return;
      }
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: value },
      });
    },
    setHighlighter(highlighter) {
      view.dispatch({ effects: setHighlighter.of(highlighter) });
    },
    destroy() {
      view.destroy();
    },
  });
}
