import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize, resolve, sep } from "node:path";

const port = Number(process.argv[2] || "4173");
const root = resolve(process.argv[3] || "dist");

const contentTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".wasm", "application/wasm"],
]);

function fileForUrl(url) {
  const parsed = new URL(url, `http://127.0.0.1:${port}`);
  const pathname = decodeURIComponent(parsed.pathname);
  const relative = normalize(pathname === "/" ? "index.html" : pathname.slice(1));
  const candidate = resolve(join(root, relative));
  if (candidate !== root && !candidate.startsWith(`${root}${sep}`)) {
    return undefined;
  }
  return candidate;
}

createServer((request, response) => {
  const file = fileForUrl(request.url || "/");
  if (!file) {
    response.writeHead(403).end("Forbidden");
    return;
  }

  try {
    const info = statSync(file);
    if (!info.isFile()) {
      response.writeHead(404).end("Not found");
      return;
    }
    response.writeHead(200, {
      "content-length": info.size,
      "content-type":
        contentTypes.get(extname(file)) || "application/octet-stream",
    });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end("Not found");
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`serving ${root} on http://127.0.0.1:${port}/`);
});
