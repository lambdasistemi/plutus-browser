export const fetchTextImpl = (url) => () =>
  fetch(url).then((response) => {
    if (!response.ok) {
      throw new Error(`Fetch failed with HTTP ${response.status}`);
    }
    return response.text();
  });

export const readFirstFileTextImpl = (event) => () => {
  const file = event?.target?.files?.[0];
  if (!file) {
    return Promise.reject(new Error("No file selected"));
  }
  return file.text();
};
