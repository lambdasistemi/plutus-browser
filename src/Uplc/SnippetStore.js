import git from "isomorphic-git";

const DIR = "/repo";
const AUTHOR = {
  name: "Browser",
  email: "browser@example.invalid",
};

export const deleteAndCommitImpl = (repo) => (filepath) => (message) => () =>
  deleteAndCommit(repo, filepath, message);

export const renameAndCommitImpl = (repo) => (oldPath) => (newPath) => (message) =>
  () => renameAndCommit(repo, oldPath, newPath, message);

async function deleteAndCommit(repo, filepath, message) {
  if (!(await exists(repo.pfs, fullPath(filepath)))) {
    throw new Error(`Snippet does not exist: ${filepath}`);
  }

  await repo.pfs.unlink(fullPath(filepath));
  await git.remove({ fs: repo.fs, dir: repo.dir, filepath });
  return commitIfChanged(repo, [filepath], message);
}

async function renameAndCommit(repo, oldPath, newPath, message) {
  if (oldPath === newPath) {
    await flush(repo);
    return { oid: await currentHead(repo), committed: false };
  }
  if (!(await exists(repo.pfs, fullPath(oldPath)))) {
    throw new Error(`Snippet does not exist: ${oldPath}`);
  }
  if (await exists(repo.pfs, fullPath(newPath))) {
    throw new Error(`Snippet already exists: ${newPath}`);
  }

  const content = await repo.pfs.readFile(fullPath(oldPath), { encoding: "utf8" });
  await mkdirp(repo.pfs, parentPath(fullPath(newPath)));
  await repo.pfs.writeFile(fullPath(newPath), content, { encoding: "utf8" });
  await git.add({ fs: repo.fs, dir: repo.dir, filepath: newPath });
  await repo.pfs.unlink(fullPath(oldPath));
  await git.remove({ fs: repo.fs, dir: repo.dir, filepath: oldPath });
  return commitIfChanged(repo, [oldPath, newPath], message);
}

async function commitIfChanged(repo, filepaths, message) {
  const matrix = await git.statusMatrix({
    fs: repo.fs,
    dir: repo.dir,
    filepaths,
  });

  const changed = matrix.some((row) => row[1] !== row[3]);
  if (!changed) {
    await flush(repo);
    return { oid: await currentHead(repo), committed: false };
  }

  const now = new Date();
  const oid = await git.commit({
    fs: repo.fs,
    dir: repo.dir,
    message,
    author: {
      ...AUTHOR,
      timestamp: Math.floor(now.getTime() / 1000),
      timezoneOffset: now.getTimezoneOffset(),
    },
  });
  await flush(repo);
  return { oid, committed: true };
}

async function currentHead(repo) {
  try {
    return await git.resolveRef({ fs: repo.fs, dir: repo.dir, ref: "HEAD" });
  } catch (_err) {
    return "";
  }
}

async function mkdirp(pfs, path) {
  const parts = path.split("/").filter(Boolean);
  let cursor = "";
  for (const part of parts) {
    cursor += `/${part}`;
    try {
      await pfs.mkdir(cursor);
    } catch (err) {
      if (err?.code !== "EEXIST") {
        throw err;
      }
    }
  }
}

async function exists(pfs, path) {
  try {
    await pfs.stat(path);
    return true;
  } catch (_err) {
    return false;
  }
}

async function flush(repo) {
  if (typeof repo.pfs.flush === "function") {
    await repo.pfs.flush();
  }
}

function fullPath(filepath) {
  return `${DIR}/${filepath}`;
}

function parentPath(path) {
  const idx = path.lastIndexOf("/");
  return idx <= 0 ? "/" : path.slice(0, idx);
}
