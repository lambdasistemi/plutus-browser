export const setTimeout = (milliseconds) => (effect) => () =>
  globalThis.setTimeout(() => effect(), milliseconds);

export const clearTimeout = (timeoutId) => () =>
  globalThis.clearTimeout(timeoutId);
