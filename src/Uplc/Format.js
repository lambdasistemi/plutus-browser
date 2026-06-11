export const formatUplc = (indentWidth) => (source) => {
  const tokens = tokenize(source);
  const lines = [];
  let current = "";
  let depth = 0;
  const step = normalizedIndentWidth(indentWidth);

  const flush = () => {
    const text = current.trimEnd();
    if (text.length > 0) lines.push(text);
    current = "";
  };

  for (const token of tokens) {
    if (token === ")" || token === "]") {
      if (current.trim().length > 0 && current.trim() !== indent(depth, step)) {
        flush();
      }
      depth = Math.max(0, depth - 1);
      current = indent(depth, step) + token;
      flush();
      continue;
    }

    if (token === "(" || token === "[") {
      if (current.trim().length === 0) {
        current = indent(depth, step) + token;
      } else if ((current + " " + token).length <= 82) {
        current += " " + token;
      } else {
        flush();
        current = indent(depth, step) + token;
      }
      depth += 1;
      continue;
    }

    if (current.trim().length === 0) {
      current = indent(depth, step) + token;
    } else if ((current + " " + token).length <= 82) {
      current += " " + token;
    } else {
      flush();
      current = indent(depth, step) + token;
    }
  }

  flush();
  return lines.join("\n");
};

function tokenize(source) {
  const tokens = [];
  let i = 0;

  while (i < source.length) {
    const ch = source[i];
    if (/\s/.test(ch)) {
      i += 1;
      continue;
    }

    if (ch === "(" || ch === ")" || ch === "[" || ch === "]") {
      tokens.push(ch);
      i += 1;
      continue;
    }

    if (ch === '"') {
      let j = i + 1;
      while (j < source.length) {
        if (source[j] === "\\" && j + 1 < source.length) {
          j += 2;
        } else if (source[j] === '"') {
          j += 1;
          break;
        } else {
          j += 1;
        }
      }
      tokens.push(source.slice(i, j));
      i = j;
      continue;
    }

    let j = i;
    while (j < source.length && !/\s|[()[\]]/.test(source[j])) {
      j += 1;
    }
    tokens.push(source.slice(i, j));
    i = j;
  }

  return tokens;
}

function normalizedIndentWidth(indentWidth) {
  return [2, 4, 8].includes(indentWidth) ? indentWidth : 2;
}

function indent(depth, indentWidth) {
  return " ".repeat(Math.max(0, depth) * indentWidth);
}
